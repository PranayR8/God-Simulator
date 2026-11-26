class_name Agents
extends Node2D

## Owns every living agent: movement, reproduction, and drawing.
## The world (GodSimWorld) answers "is this tile walkable?" — agents prefer
## grass and forest and never walk on water or mountains.

const MAX_PEOPLE := 260
const MAX_SHEEP := 140
const BREED_TIME := 60.0  # ticks of cooldown after breeding (15s at 1x)
const BREED_CHANCE := 0.003  # per tick, per agent standing next to a mate

var agents: Array[SimAgent] = []
var world: GodSimWorld = null
var villages: Villages = null  # set by Main; used to keep citizens near home

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func count_people() -> int:
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON:
			n += 1
	return n

func count_animals() -> int:
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.SHEEP:
			n += 1
	return n

func clear_all() -> void:
	agents.clear()
	queue_redraw()

func spawn(kind: int, tile: Vector2i) -> void:
	if not world.is_walkable(tile.x, tile.y):
		return
	agents.append(SimAgent.new(kind, world.tile_to_world(tile.x, tile.y)))
	queue_redraw()

func spawn_scattered(kind: int, count: int) -> void:
	for i in count:
		var tile := random_walkable_tile()
		if tile.x >= 0:
			spawn(kind, tile)

func random_walkable_tile() -> Vector2i:
	for attempt in 60:
		var x := _rng.randi_range(0, GodSimWorld.WIDTH - 1)
		var y := _rng.randi_range(0, GodSimWorld.HEIGHT - 1)
		if world.is_walkable(x, y):
			return Vector2i(x, y)
	return Vector2i(-1, -1)

## One simulation tick: move everyone, then maybe breed.
## dt is the tick length in seconds (used for movement).
func tick(dt: float) -> void:
	var i := 0
	while i < agents.size():
		var a := agents[i]
		a.age += 1.0
		a.breed_cooldown = maxf(0.0, a.breed_cooldown - 1.0)
		_move_agent(a, dt)
		i += 1
	_try_breed()
	queue_redraw()

func _move_agent(a: SimAgent, dt: float) -> void:
	if not a.has_target or a.pos.distance_to(a.target) < 4.0:
		a.target = _pick_target(a)
		a.has_target = true
	var dir := (a.target - a.pos).normalized()
	a.pos += dir * a.speed() * dt
	# Stay inside the map.
	a.pos.x = clampf(a.pos.x, 4.0, GodSimWorld.WIDTH * GodSimWorld.TILE - 4.0)
	a.pos.y = clampf(a.pos.y, 4.0, GodSimWorld.HEIGHT * GodSimWorld.TILE - 4.0)

## Pick a nearby walkable tile to walk to. People like grass and forest;
## sheep only really like grass. Water and mountains are never picked.
## Citizens stay near home: a person assigned to a village only picks
## targets inside their own territory, and if they have wandered outside
## it, they head back toward the village centre instead.
func _pick_target(a: SimAgent) -> Vector2:
	var tile := world.world_to_tile(a.pos)
	var has_home := false
	var home_center := Vector2.ZERO
	var home_radius := 0.0
	if a.kind == SimAgent.Kind.PERSON and villages != null and a.village >= 0 and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		has_home = true
		home_center = world.tile_to_world(v.tile.x, v.tile.y)
		home_radius = villages.territory_radius_px(v)
		if a.pos.distance_to(home_center) > home_radius:
			# Outside the border: walk home. A jittered point near the
			# centre keeps citizens from all marching to one spot.
			var back := home_center + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
			var back_tile := world.world_to_tile(back)
			if world.in_bounds(back_tile.x, back_tile.y):
				var bt := world.get_terrain(back_tile.x, back_tile.y)
				if bt != GodSimWorld.Terrain.WATER and bt != GodSimWorld.Terrain.MOUNTAIN:
					return back
			return home_center
	for attempt in 8:
		var nx := tile.x + _rng.randi_range(-4, 4)
		var ny := tile.y + _rng.randi_range(-4, 4)
		if not world.in_bounds(nx, ny):
			continue
		var t := world.get_terrain(nx, ny)
		if t == GodSimWorld.Terrain.WATER or t == GodSimWorld.Terrain.MOUNTAIN:
			continue
		if a.kind == SimAgent.Kind.SHEEP and t == GodSimWorld.Terrain.FOREST:
			continue
		var dest := world.tile_to_world(nx, ny)
		if has_home and dest.distance_to(home_center) > home_radius:
			continue
		return dest
	return a.pos

func _try_breed() -> void:
	# A creature breeds when it stands next to another of its kind on good
	# land, its cooldown has expired, and the population cap allows it.
	# (We iterate a copy of the list because breeding appends to it.)
	var people := count_people()
	var sheep := count_animals()
	for a in agents.duplicate():
		if a.breed_cooldown > 0.0:
			continue
		var cap := MAX_PEOPLE if a.kind == SimAgent.Kind.PERSON else MAX_SHEEP
		var total := people if a.kind == SimAgent.Kind.PERSON else sheep
		if total >= cap:
			continue
		var tile := world.world_to_tile(a.pos)
		var t := world.get_terrain(tile.x, tile.y)
		if t != GodSimWorld.Terrain.GRASS and t != GodSimWorld.Terrain.FOREST:
			continue
		if _has_neighbour(a, 30.0) and _rng.randf() < BREED_CHANCE:
			var child := SimAgent.new(
				a.kind,
				a.pos + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
			)
			if a.kind == SimAgent.Kind.PERSON:
				# Children are born into their parent's village.
				child.village = a.village
			agents.append(child)
			a.breed_cooldown = BREED_TIME
			if a.kind == SimAgent.Kind.PERSON:
				people += 1
			else:
				sheep += 1

func _has_neighbour(a: SimAgent, radius: float) -> bool:
	for other in agents:
		if other != a and other.kind == a.kind and other.pos.distance_to(a.pos) < radius:
			return true
	return false

## Remove every agent within radius_px of a point. Returns how many died.
func kill_in_radius(center: Vector2, radius_px: float) -> int:
	var dead := 0
	var i := agents.size() - 1
	while i >= 0:
		if agents[i].pos.distance_to(center) <= radius_px:
			agents.remove_at(i)
			dead += 1
		i -= 1
	if dead > 0:
		queue_redraw()
	return dead

## How many people stand within radius_tiles of a tile (used by villages).
func people_near(tile: Vector2i, radius_tiles: int) -> int:
	var center := world.tile_to_world(tile.x, tile.y)
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON and a.pos.distance_to(center) <= radius_tiles * GodSimWorld.TILE:
			n += 1
	return n

func _draw() -> void:
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON:
			_draw_person(a)
		else:
			_draw_sheep(a)

## A person, about one tile tall: legs, a coloured tunic, arms, a head
## with a hair cap. A small bob while walking keeps them feeling alive.
func _draw_person(a: SimAgent) -> void:
	var bob := sin(a.age * 0.9) * 1.0
	var p := a.pos + Vector2(0, bob)
	var skin := SimAgent.PERSON_COLOR
	var dark := Color("#5a4632")
	# Legs.
	draw_line(p + Vector2(-2.5, 4), p + Vector2(-2.5, 9), dark, 2.0)
	draw_line(p + Vector2(2.5, 4), p + Vector2(2.5, 9), dark, 2.0)
	# Tunic: shoulders to hem.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-5, -2), p + Vector2(5, -2),
		p + Vector2(6.5, 5), p + Vector2(-6.5, 5),
	]), a.shirt_color)
	# Arms.
	draw_line(p + Vector2(-5, -1), p + Vector2(-7.5, 3), a.shirt_color, 2.0)
	draw_line(p + Vector2(5, -1), p + Vector2(7.5, 3), a.shirt_color, 2.0)
	# Head with a hair cap on top.
	draw_circle(p + Vector2(0, -6), 3.6, skin)
	draw_arc(p + Vector2(0, -6), 3.6, PI, TAU, 10, a.hair_color, 2.2)

## A sheep: fluffy white body, four dark legs, a dark head at the front
## (facing whichever way it is walking), a wool tuft and an ear.
func _draw_sheep(a: SimAgent) -> void:
	var facing := 1.0
	if a.target.x < a.pos.x:
		facing = -1.0
	var bob := sin(a.age * 0.9 + 1.7) * 0.5
	var p := a.pos + Vector2(0, bob)
	var wool := SimAgent.SHEEP_COLOR
	var dark := Color("#3a3a3a")
	var outline := Color("#c8c8c8")
	# Legs.
	draw_line(p + Vector2(-6, 2), p + Vector2(-6, 7), dark, 1.5)
	draw_line(p + Vector2(-2, 3), p + Vector2(-2, 7), dark, 1.5)
	draw_line(p + Vector2(2, 3), p + Vector2(2, 7), dark, 1.5)
	draw_line(p + Vector2(6, 2), p + Vector2(6, 7), dark, 1.5)
	# Fluffy body: overlapping wool circles.
	draw_circle(p + Vector2(-5, -1), 4.5, wool)
	draw_circle(p + Vector2(5, -1), 4.5, wool)
	draw_circle(p + Vector2(0, -2), 5.5, wool)
	draw_circle(p + Vector2(0, -4), 4.0, wool)
	draw_arc(p + Vector2(0, -2), 5.5, 0, TAU, 16, outline, 1.0)
	# Head at the front, with a wool tuft and an ear.
	var head := p + Vector2(facing * 9.5, -3)
	draw_circle(head, 3.0, dark)
	draw_circle(head + Vector2(0, -3.5), 1.6, wool)
	draw_line(head + Vector2(-facing * 1.5, -2), head + Vector2(-facing * 4, -4.5), dark, 1.5)
