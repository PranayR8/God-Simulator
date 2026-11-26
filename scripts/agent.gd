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
