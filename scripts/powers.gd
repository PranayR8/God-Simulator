class_name Powers
extends Node2D

## God powers: Rain, Lightning, Meteor, and (Phase 8) the blessings —
## Bless Person, Bless Village, Fertile Rain. Each one edits the world
## grid (via GodSimWorld) and the agents, and adds a short-lived visual
## effect that fades away on its own. Effects are drawn here in _draw().
## The blessings have cooldowns (in ticks; 120 ticks = 1 day), so the
## player chooses where to spend their favour instead of blessing
## everything at once.

enum Power { RAIN, LIGHTNING, METEOR, BLESS_PERSON, BLESS_VILLAGE, FERTILE_RAIN }

const RAIN_RADIUS := 4       # tiles
const LIGHTNING_RADIUS := 2  # tiles (kill + scorch)
const METEOR_RADIUS := 3     # tiles (crater)

## Bless Person: tap a person within 2 tiles. They walk faster, recover
## health faster, and live longer — for life.
const BLESS_PERSON_RADIUS := 2   # tiles (how close the tap must be)
const BLESS_PERSON_COOLDOWN := 120  # 1 day
## Bless Village: tap a village's land. Fertility and growth for a
## season — its people breed twice as often, its farmers bring in one
## extra unit of food per cycle.
const BLESS_VILLAGE_DAYS := 15     # one season
const BLESS_VILLAGE_COOLDOWN := 600  # 5 days
## Fertile Rain: like rain, but grows food — every forest tile in the
## radius gains berries (up to the max).
const FERTILE_RAIN_RADIUS := 4  # tiles
const FERTILE_RAIN_BERRIES := 2  # berries added to each forest tile
const FERTILE_RAIN_COOLDOWN := 120  # 1 day

var world: GodSimWorld = null
var agents: Agents = null
var villages: Villages = null

## Cooldowns, power -> remaining ticks (0/absent = ready).
var cooldowns: Dictionary = {}

## Ticks left before this power can be used again (0 = ready).
func cooldown_remaining(power: int) -> int:
	return int(cooldowns.get(power, 0))

## One tick of cooldown time passing — Main calls this every tick.
func tick_cooldowns() -> void:
	for p in cooldowns.keys():
		var left := int(cooldowns[p]) - 1
		if left <= 0:
			cooldowns.erase(p)
		else:
			cooldowns[p] = left

func _start_cooldown(power: int, ticks: int) -> void:
	cooldowns[power] = ticks

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
		Power.FERTILE_RAIN:
			_apply_fertile_rain(tile)
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

## Bless Person (Phase 8). Returns 1 when someone was blessed, 0 when
## there is nobody near the tap, -1 when the blessing is recharging.
## A blessed person is marked for life: faster, stronger (health
## recovers 3x as fast), longer-lived (lifespan x1.5).
func bless_person_at(tile: Vector2i) -> int:
	if cooldown_remaining(Power.BLESS_PERSON) > 0:
		return -1
	var pos := world.tile_to_world(tile.x, tile.y)
	var a := agents.nearest_person(pos, BLESS_PERSON_RADIUS * GodSimWorld.TILE)
	if a == null:
		return 0
	a.blessed = true
	a.lifespan *= SimAgent.BLESS_LIFESPAN_MULT
	_start_cooldown(Power.BLESS_PERSON, BLESS_PERSON_COOLDOWN)
	_effects.append({
		"kind": Power.BLESS_PERSON, "pos": a.pos,
		"ttl": 0.9, "max": 0.9,
	})
	queue_redraw()
	agents.queue_redraw()
	return 1

## Bless Village (Phase 8). Returns 1 when a village was blessed, 0
## when the tap is on no village's land, -1 when recharging. The
## blessing lasts a season (15 days): births double, farmers bring in
## one extra unit of food per cycle.
func bless_village_at(tile: Vector2i, day: int) -> int:
	if cooldown_remaining(Power.BLESS_VILLAGE) > 0:
		return -1
	var idx := villages.village_at_tile(tile)
	if idx < 0:
		return 0
	var v: Villages.VillageData = villages.villages[idx]
	v.blessed_until_day = day + BLESS_VILLAGE_DAYS
	_start_cooldown(Power.BLESS_VILLAGE, BLESS_VILLAGE_COOLDOWN)
	_effects.append({
		"kind": Power.BLESS_VILLAGE,
		"pos": world.tile_to_world(v.tile.x, v.tile.y),
		"ttl": 1.2, "max": 1.2,
	})
	queue_redraw()
	villages.queue_redraw()
	return 1

## Fertile Rain (Phase 8). Like rain, but it grows food: every forest
## tile in the radius gains berries, up to the max. Returns 1, or -1
## when recharging.
func _apply_fertile_rain(center: Vector2i) -> int:
	if cooldown_remaining(Power.FERTILE_RAIN) > 0:
		return -1
	for dy in range(-FERTILE_RAIN_RADIUS, FERTILE_RAIN_RADIUS + 1):
		for dx in range(-FERTILE_RAIN_RADIUS, FERTILE_RAIN_RADIUS + 1):
			if dx * dx + dy * dy > FERTILE_RAIN_RADIUS * FERTILE_RAIN_RADIUS:
				continue
			var x := center.x + dx
			var y := center.y + dy
			if not world.in_bounds(x, y):
				continue
			if world.get_terrain(x, y) != GodSimWorld.Terrain.FOREST:
				continue
			var t := Vector2i(x, y)
			var n: int = world.berries.get(t, 0)
			world.berries[t] = mini(n + FERTILE_RAIN_BERRIES, GodSimWorld.BERRY_MAX)
	_start_cooldown(Power.FERTILE_RAIN, FERTILE_RAIN_COOLDOWN)
	_effects.append({
		"kind": Power.FERTILE_RAIN,
		"pos": world.tile_to_world(center.x, center.y),
		"ttl": 0.9, "max": 0.9,
	})
	world.queue_redraw()
	return 1

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
			Power.BLESS_PERSON:
				# A golden burst that fades, leaving the person's own
				# golden aura (drawn in agents.gd) behind.
				draw_circle(pos, 40.0 * (1.0 - f) + 8.0, Color(1.0, 0.85, 0.2, 0.5 * f))
				draw_circle(pos, 12.0, Color(1.0, 0.95, 0.5, 0.9 * f))
			Power.BLESS_VILLAGE:
				# A gold ring that expands out to the territory edge.
				draw_arc(pos, 140.0 * (1.0 - f) + 12.0, 0, TAU, 48, Color(1.0, 0.85, 0.2, 0.7 * f), 3.0)
			Power.FERTILE_RAIN:
				# Green-gold rain: food growing, not water falling.
				draw_circle(pos, 60.0 * (1.0 - f) + 10.0, Color(0.4, 0.9, 0.3, 0.35 * f))
				draw_circle(pos, 30.0 * (1.0 - f) + 6.0, Color(1.0, 0.85, 0.2, 0.5 * f))
