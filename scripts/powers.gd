class_name Powers
extends Node2D

## God powers: Rain, Lightning, Meteor. Each one edits the world grid
## (via GodSimWorld) and the agents, and adds a short-lived visual effect
## that fades away on its own. Effects are drawn here in _draw().

enum Power { RAIN, LIGHTNING, METEOR }

const RAIN_RADIUS := 4       # tiles
const LIGHTNING_RADIUS := 2  # tiles (kill + scorch)
const METEOR_RADIUS := 3     # tiles (crater)

var world: GodSimWorld = null
var agents: Agents = null

# Transient visuals. Each entry is a Dictionary:
# { "kind": Power, "pos": Vector2, "ttl": float, "max": float,
#   "points": PackedVector2Array }  ("points" only for lightning)
var _effects: Array = []

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Apply a power at a tile. Returns how many creatures died (0 for
## rain) — Main logs the event with that number.
func apply_power(power: int, tile: Vector2i) -> int:
	var killed := 0
	match power:
		Power.RAIN:
			_apply_rain(tile)
		Power.LIGHTNING:
			killed = _apply_lightning(tile)
		Power.METEOR:
			killed = _apply_meteor(tile)
	queue_redraw()
	world.queue_redraw()
	agents.queue_redraw()
	return killed

## Rain waters the land: scorched ground becomes grass again, and grass
## sometimes grows into forest.
func _apply_rain(center: Vector2i) -> void:
	for dy in range(-RAIN_RADIUS, RAIN_RADIUS + 1):
		for dx in range(-RAIN_RADIUS, RAIN_RADIUS + 1):
			if dx * dx + dy * dy > RAIN_RADIUS * RAIN_RADIUS:
				continue
			var x := center.x + dx
			var y := center.y + dy
			if not world.in_bounds(x, y):
				continue
			var t := world.get_terrain(x, y)
			if t == GodSimWorld.Terrain.SCORCHED:
				world.set_terrain(x, y, GodSimWorld.Terrain.GRASS)
			elif t == GodSimWorld.Terrain.GRASS and _rng.randf() < 0.35:
				world.set_terrain(x, y, GodSimWorld.Terrain.FOREST)
	_effects.append({
		"kind": Power.RAIN,
		"pos": world.tile_to_world(center.x, center.y),
		"ttl": 0.9, "max": 0.9,
	})

## Lightning kills creatures in a small radius and scorches forest.
## Returns how many creatures died.
func _apply_lightning(center: Vector2i) -> int:
	var pos := world.tile_to_world(center.x, center.y)
	var killed := agents.kill_in_radius(pos, LIGHTNING_RADIUS * GodSimWorld.TILE)
	for dy in range(-LIGHTNING_RADIUS, LIGHTNING_RADIUS + 1):
		for dx in range(-LIGHTNING_RADIUS, LIGHTNING_RADIUS + 1):
			if dx * dx + dy * dy > LIGHTNING_RADIUS * LIGHTNING_RADIUS:
				continue
			var x := center.x + dx
			var y := center.y + dy
			if world.in_bounds(x, y) and world.get_terrain(x, y) == GodSimWorld.Terrain.FOREST:
				world.set_terrain(x, y, GodSimWorld.Terrain.SCORCHED)
	# Jagged bolt: random points from the sky down to the strike point.
	var pts := PackedVector2Array()
	var top := pos + Vector2(0, -90)
	var steps := 6
	for i in steps + 1:
		var f := float(i) / steps
		pts.append(top.lerp(pos, f) + Vector2(_rng.randf_range(-8, 8) * (1.0 - f), 0))
	_effects.append({
		"kind": Power.LIGHTNING, "pos": pos, "ttl": 0.35, "max": 0.35, "points": pts,
	})
	return killed

## Meteor: a crater of scorched rock, everything in the radius dies.
## Returns how many creatures died.
func _apply_meteor(center: Vector2i) -> int:
	var pos := world.tile_to_world(center.x, center.y)
	var killed := agents.kill_in_radius(pos, METEOR_RADIUS * GodSimWorld.TILE)
	for dy in range(-METEOR_RADIUS, METEOR_RADIUS + 1):
		for dx in range(-METEOR_RADIUS, METEOR_RADIUS + 1):
			if dx * dx + dy * dy > METEOR_RADIUS * METEOR_RADIUS:
				continue
			var x := center.x + dx
			var y := center.y + dy
			if world.in_bounds(x, y):
				world.set_terrain(x, y, GodSimWorld.Terrain.SCORCHED)
	_effects.append({
		"kind": Power.METEOR, "pos": pos, "ttl": 0.8, "max": 0.8,
	})
	return killed

func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var i := _effects.size() - 1
	while i >= 0:
		_effects[i]["ttl"] = float(_effects[i]["ttl"]) - delta
		if float(_effects[i]["ttl"]) <= 0.0:
			_effects.remove_at(i)
		i -= 1
	queue_redraw()

func _draw() -> void:
	for e in _effects:
		# f goes 1.0 -> 0.0 as the effect fades out.
		var f := float(e["ttl"]) / float(e["max"])
		var pos: Vector2 = e["pos"]
		match int(e["kind"]):
			Power.RAIN:
				draw_circle(pos, 60.0 * (1.0 - f) + 10.0, Color(0.3, 0.6, 1.0, 0.35 * f))
			Power.LIGHTNING:
				var pts: PackedVector2Array = e["points"]
				for j in pts.size() - 1:
					draw_line(pts[j], pts[j + 1], Color(1.0, 0.9, 0.3, f), 3.0)
			Power.METEOR:
				draw_circle(pos, 90.0 * (1.0 - f) + 12.0, Color(1.0, 0.55, 0.2, 0.5 * f))
				draw_circle(pos, 30.0, Color(1.0, 0.8, 0.3, 0.8 * f))
