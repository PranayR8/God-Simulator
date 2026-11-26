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
var age: float = 0.0  # age in ticks (unused in v1, kept for v2 ideas)
var shirt_color: Color = Color("#2980b9")
var hair_color: Color = Color("#2c2118")

func _init(p_kind: int, p_pos: Vector2) -> void:
	kind = p_kind
	pos = p_pos
	if kind == Kind.PERSON:
		shirt_color = SHIRT_COLORS[randi() % SHIRT_COLORS.size()]
		hair_color = HAIR_COLORS[randi() % HAIR_COLORS.size()]

func speed() -> float:
	return PERSON_SPEED if kind == Kind.PERSON else SHEEP_SPEED
