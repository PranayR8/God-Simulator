class_name SimAgent
extends RefCounted

## One living creature: a person or a sheep.
##
## Agents are plain data (RefCounted, not nodes). Agents (agents.gd) owns
## the list, moves them, and draws them. That keeps hundreds of agents
## cheap — a Node2D per creature would be much slower.

enum Kind { PERSON, SHEEP }

const PERSON_SPEED := 26.0  # pixels per second
const SHEEP_SPEED := 18.0
const PERSON_COLOR := Color("#ffd9a0")
const SHEEP_COLOR := Color("#f2f2f2")

## Shirt and hair palettes so every person reads as an individual.
const SHIRT_COLORS := [
	Color("#c0392b"), Color("#2980b9"), Color("#27ae60"),
	Color("#8e44ad"), Color("#e67e22"), Color("#16a085"),
]
const HAIR_COLORS := [
	Color("#2c2118"), Color("#111111"), Color("#6e4b2a"),
	Color("#b0b0b0"), Color("#d9a066"), Color("#7a3b12"),
]

var kind: int = Kind.PERSON
var pos: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var has_target: bool = false
var breed_cooldown: float = 0.0  # ticks until this agent may breed again
var age: float = 0.0  # age in ticks (120 ticks = 1 day); drives the life stages below
## Hunger & health (Phase 2, people only — sheep don't go hungry).
## hunger 0 = full, 100 = starving; it rises every tick and eating a
## berry lowers it. While starving, health drains; at 0 the person dies.
var hunger: float = 0.0
var health: float = 100.0

## Life stages (Phase 3, people only). Age is in ticks; a day is 120
## ticks, so a child is under 12 days, an elder is 50 days or older,
## and a randomized lifespan of 60–90 days decides when old age kills.
const CHILD_TICKS := 1440.0        # 12 days
const ELDER_TICKS := 6000.0        # 50 days
const MIN_LIFESPAN_TICKS := 7200.0   # 60 days
const MAX_LIFESPAN_TICKS := 10800.0  # 90 days
const ELDER_SPEED_FACTOR := 0.6   # elders walk slower

## The age (in ticks) at which old age kills this person, randomized
## at birth. Sheep don't age — it stays 0 for them.
var lifespan: float = 0.0
var shirt_color: Color = Color("#2980b9")
var hair_color: Color = Color("#2c2118")
## Jobs (Phase 5). A citizen's job: JOB_NONE = no job yet (children,
## nomads, and anyone hired before jobs existed). Jobs are assigned by
## the village (village.gd) and the work is done in agents.gd.
## job_timer counts ticks until the next unit of work.
const JOB_NONE := -1
const JOB_FARMER := 0
const JOB_WOODCUTTER := 1
const JOB_BUILDER := 2
const JOB_MINER := 3
const JOB_NAMES := ["Farmer", "Woodcutter", "Builder", "Miner"]
const JOB_COLORS := [Color("#27ae60"), Color("#8b5a2b"), Color("#7f8c8d"), Color("#5d6d7e")]
var job: int = JOB_NONE
var job_timer: float = 0.0

## Phase 16 — gear. A person's armour, weapon and tool, each in the
## material of the era they came of age in (Stone, Bronze, Iron,
## Steel). Gear is set once, when a person becomes an adult, and kept
## for life — so a village in the Iron Age holds a mix: elders with
## stone gear from the Stone Age, the middle-aged with bronze, the
## young with iron. Children carry no gear. The tiers are indexes
## into GEAR_NAMES and the multiplier tables below.
const GEAR_NONE := 0
const GEAR_STONE := 1
const GEAR_BRONZE := 2
const GEAR_IRON := 3
const GEAR_STEEL := 4
const GEAR_NAMES := ["", "Stone", "Bronze", "Iron", "Steel"]
## The gear an era equips its new adults with (indexed by era).
## Classical keeps iron — the classical world was an iron world;
## marble is for its buildings, not its blades.
const ERA_GEAR := [GEAR_STONE, GEAR_BRONZE, GEAR_IRON, GEAR_IRON, GEAR_STEEL]
## A weapon's edge in war (multiplies a fighter's strength).
const GEAR_WEAPON_MULT := [1.0, 1.0, 1.15, 1.3, 1.5]
## Armour's protection in war (the share of deaths it prevents).
const GEAR_ARMOR_PROTECT := [0.0, 0.0, 0.1, 0.2, 0.3]
## A tool's edge at work (multiplies a worker's output).
const GEAR_TOOL_MULT := [1.0, 1.0, 1.1, 1.25, 1.5]
var weapon_tier: int = GEAR_NONE
var armor_tier: int = GEAR_NONE
var tool_tier: int = GEAR_NONE

## The gear's names, for the inspect panel. A tool is named by the
## job it serves (a hoe, an axe, a pick, a hammer); a weapon and
## armour by their material.
func weapon_name() -> String:
	if weapon_tier <= GEAR_NONE:
		return "No weapon"
	match weapon_tier:
		GEAR_STONE:
			return "Stone club"
		GEAR_BRONZE:
			return "Bronze sword"
		GEAR_IRON:
			return "Iron sword"
		_:
			return "Steel sword"

func armor_name() -> String:
	if armor_tier <= GEAR_NONE:
		return "No armour"
	if armor_tier == GEAR_STONE:
		return "Hide armour"
	return "%s armour" % GEAR_NAMES[armor_tier]

func tool_name() -> String:
	if tool_tier <= GEAR_NONE:
		return "No tool"
	var kind := "tool"
	match job:
		JOB_FARMER:
			kind = "hoe"
		JOB_WOODCUTTER:
			kind = "axe"
		JOB_BUILDER:
			kind = "hammer"
		JOB_MINER:
			kind = "pick"
	return "%s %s" % [GEAR_NAMES[tool_tier], kind]

var village: int = -1  # index into Villages.villages; -1 = no village yet (a nomad)

## Exploration (Phase 19). A villager is free to leave the village and
## explore the world beyond the border — they walk out, look around,
## and drift back home. While exploring they are still a citizen of
## their village; they just aren't at home right now. A hungry person
## never explores (they go looking for food instead), and a raider
## never explores (they march to war instead).
var exploring: bool = false

## Blessings (Phase 8). A blessed person is marked by the god: they walk
## faster, recover health faster, and live longer. The blessing is for
## life — it is set when the god blesses them and never wears off.
var blessed: bool = false

## Plague (Phase 9). sick is the ticks of sickness remaining (0 =
## healthy); while sick, the person drains health and cannot recover,
## and can pass it to anyone standing close. When the sickness runs
## out they recover and are immune for life — that is how a plague
## burns out instead of lingering forever.
var sick: float = 0.0
var immune: bool = false

## War (Phase 10). at_war is the index into Wars.wars for the war this
## person is marching in (-1 = at home, not at war); war_target is
## where they are marching to (the enemy village's centre). A raider
## walks to the enemy, fights there, and walks home when the war ends
## (or dies trying). While at war they do no job and do not breed —
## they are away from home.
var at_war: int = -1
var war_target: Vector2 = Vector2.ZERO

## Heroes (Phase 11). A hero is a named person who matters: they carry
## a trait that helps their village, wear a golden ring instead of the
## plain village ring, and their deeds go in the log. A hero is made
## when the god blesses them, when they found a village, or when they
## survive a war or a plague. hero_name is their first name; trait
## is one of the four traits below; hero_deed is why they became a
## hero ("blessed by the god", "founder of Wilwick").
const HERO_TRAIT_STRONG := 0
const HERO_TRAIT_WISE := 1
const HERO_TRAIT_SWIFT := 2
const HERO_TRAIT_HARDY := 3
const HERO_TRAIT_BRAVE := 4
const HERO_TRAIT_FERTILE := 5
const HERO_TRAIT_HEALTHY := 6
const HERO_TRAIT_NAMES := ["Strong", "Wise", "Swift", "Hardy", "Brave", "Fertile", "Healthy"]
## Acquired traits (Phase 18) — earned in a life, never inherited. A
## person can carry several: a Veteran who was crippled in the same
## war, a Plague Survivor who later starved and lived.
const ACQUIRED_VETERAN := 0
const ACQUIRED_CRIPPLED := 1
const ACQUIRED_PLAGUE_SURVIVOR := 2
const ACQUIRED_FAMINE_SURVIVOR := 3
const ACQUIRED_TRAIT_NAMES := ["Veteran", "Crippled", "Plague Survivor", "Famine Survivor"]
const HERO_NAMES := [
	"Mara", "Alden", "Bryn", "Cedric", "Delia", "Edmund", "Freya",
	"Gareth", "Hilda", "Ivor", "Jessa", "Kael", "Lyra", "Magnus",
	"Nia", "Orin", "Petra", "Quinn", "Rowan", "Sable", "Tomas",
	"Una", "Viktor", "Wren", "Yara", "Zeke", "Astrid", "Bram",
	"Cora", "Dain", "Elowen", "Finn", "Greta", "Hugo", "Isla",
	"Joren", "Kira", "Leif", "Mira", "Niko", "Odessa", "Perrin",
	"Rhea", "Silas", "Tessa", "Ulric", "Vera", "Willa", "Yorick",
	"Zola", "Ansel",
]
## What a trait does for the village its hero leads (the oldest hero
## leads — see Agents.leader_of). Strong: the village fights 25%
## harder in war. Wise: its farmers bring in 1 extra food per cycle.
## Swift: its people walk 25% faster and breed 25% sooner. Hardy: its
## people recover health twice as fast and take half the winter cold.
const HERO_STRONG_MULT := 1.25
const HERO_WISE_FARMER_BONUS := 1.0
const HERO_SWIFT_SPEED_MULT := 1.25
const HERO_SWIFT_BREED_MULT := 0.75
const HERO_HARDY_REGEN_MULT := 2.0
const HERO_HARDY_COLD_MULT := 0.5
const HERO_BRAVE_MULT := 1.15       # a Brave leader's village fights 15% harder
const HERO_FERTILE_BREED_MULT := 0.75  # a Fertile leader's village breeds 25% sooner
const HERO_HEALTHY_REGEN_MULT := 2.0  # a Healthy leader's village recovers 2x as fast
const ACQUIRED_VETERAN_WAR_MULT := 1.2  # a Veteran fights 20% harder
const ACQUIRED_CRIPPLED_SPEED_MULT := 0.5  # a Crippled person walks half as fast
const ACQUIRED_CRIPPLED_WAR_MULT := 0.5  # ...and fights at half strength
const ACQUIRED_FAMINE_HUNGER_MULT := 0.75  # a Famine Survivor's hunger rises 25% slower
var hero: bool = false
var hero_name: String = ""
var hero_deed: String = ""
## Traits, families & lineage (Phase 12). Every person carries a trait
## (one of the four below), a family surname, and a generation. A
## hero's trait is just their personal trait — the bloodline decides
## what kind of hero they become, not a fresh random roll. A spawned
## person starts a family of generation 1 with a random surname; a
## child inherits a mix of their parents (see Agents._try_breed). When
## a person becomes a hero they found a house named after their first
## name, so their surname becomes their hero name and their generation
## resets to 1 — "House of Mara" starts with Mara.
const SURNAMES := [
	"Ashford", "Stone", "River", "Hollow", "Field", "Wood", "Brook",
	"Hill", "Marsh", "Thorn", "Vale", "Frost", "Ember", "Rowan",
	"Sable", "Wren", "Hale", "Briar", "Fen", "Locke",
]
var innate_trait: int = -1
var surname: String = ""
var generation: int = 1
## Phase 18 — acquired traits, earned in a life (never inherited).
## was_starving remembers a brush with starvation: hunger reached 90
## and the person lived to eat again, so they come back a Famine
## Survivor.
var acquired_traits: Array[int] = []
var was_starving: bool = false
const BLESS_SPEED_MULT := 1.5    # blessed people walk half again as fast
const BLESS_REGEN_MULT := 3.0    # blessed people recover health 3x as fast
const BLESS_LIFESPAN_MULT := 1.5 # blessed people live half again as long

func _init(p_kind: int, p_pos: Vector2) -> void:
	kind = p_kind
	pos = p_pos
	if kind == Kind.PERSON:
		shirt_color = SHIRT_COLORS[randi() % SHIRT_COLORS.size()]
		hair_color = HAIR_COLORS[randi() % HAIR_COLORS.size()]
		lifespan = randf_range(MIN_LIFESPAN_TICKS, MAX_LIFESPAN_TICKS)
		innate_trait = randi() % HERO_TRAIT_NAMES.size()
		surname = SURNAMES[randi() % SURNAMES.size()]
		generation = 1

func is_child() -> bool:
	return kind == Kind.PERSON and age < CHILD_TICKS

func is_elder() -> bool:
	return kind == Kind.PERSON and age >= ELDER_TICKS

func speed() -> float:
	var s := 0.0
	if kind == Kind.SHEEP:
		s = SHEEP_SPEED
	elif is_elder():
		s = PERSON_SPEED * ELDER_SPEED_FACTOR
	else:
		s = PERSON_SPEED
	if blessed:
		s *= BLESS_SPEED_MULT
	# Phase 18 — a Crippled person walks half as fast, for life.
	if has_acquired(ACQUIRED_CRIPPLED):
		s *= ACQUIRED_CRIPPLED_SPEED_MULT
	return s

## Does this person carry an acquired trait?
func has_acquired(trait_id: int) -> bool:
	return acquired_traits.has(trait_id)

## Earn an acquired trait (no duplicates). Returns true when it is new.
func add_acquired(trait_id: int) -> bool:
	if acquired_traits.has(trait_id):
		return false
	acquired_traits.append(trait_id)
	return true

## The acquired traits as a readable list ("Veteran, Crippled").
func acquired_trait_names() -> String:
	var names: Array[String] = []
	for t in acquired_traits:
		if t >= 0 and t < ACQUIRED_TRAIT_NAMES.size():
			names.append(ACQUIRED_TRAIT_NAMES[t])
	return ", ".join(names)

## "Mara the Swift" — the name the log and the player use for a hero.
## The trait is the person's own (inherited), not a fresh roll.
func hero_title() -> String:
	if not hero or innate_trait < 0 or innate_trait >= HERO_TRAIT_NAMES.size():
		return ""
	return "%s the %s" % [hero_name, HERO_TRAIT_NAMES[innate_trait]]
