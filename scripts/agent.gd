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
const JOB_NAMES := ["Farmer", "Woodcutter", "Builder"]
const JOB_COLORS := [Color("#27ae60"), Color("#8b5a2b"), Color("#7f8c8d")]
var job: int = JOB_NONE
var job_timer: float = 0.0

var village: int = -1  # index into Villages.villages; -1 = no village yet (a nomad)

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
## survive a war or a plague. hero_name is their first name; hero_trait
## is one of the four traits below; hero_deed is why they became a
## hero ("blessed by the god", "founder of Wilwick").
const HERO_TRAIT_STRONG := 0
const HERO_TRAIT_WISE := 1
const HERO_TRAIT_SWIFT := 2
const HERO_TRAIT_HARDY := 3
const HERO_TRAIT_NAMES := ["Strong", "Wise", "Swift", "Hardy"]
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
var hero: bool = false
var hero_name: String = ""
var hero_trait: int = -1
var hero_deed: String = ""
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
	return s

## "Mara the Swift" — the name the log and the player use for a hero.
func hero_title() -> String:
	if not hero or hero_trait < 0 or hero_trait >= HERO_TRAIT_NAMES.size():
		return ""
	return "%s the %s" % [hero_name, HERO_TRAIT_NAMES[hero_trait]]
