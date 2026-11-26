class_name Agents
extends Node2D

## Owns every living agent: movement, reproduction, and drawing.
## The world (GodSimWorld) answers "is this tile walkable?" — agents prefer
## grass and forest and never walk on water or mountains.

const MAX_PEOPLE := 260
const MAX_SHEEP := 140
const BREED_TIME := 60.0  # ticks of cooldown after breeding (15s at 1x)
# Per tick, per agent standing next to a mate. Tuned down from 0.003 in
# Phase 3: now that people die (starvation, old age), births must be
# slow enough that the population finds a balance instead of exploding
# past the food limit and jamming at the cap. (The hunger gate below
# does the rest: only the well-fed breed, so a village that outgrows
# its food stops growing until its food catches up.)
const BREED_CHANCE := 0.001

## Hunger (Phase 2, people only). Hunger rises every tick; at 100 the
## person is starving and health drains. A berry restores 50 hunger,
## so a person eats about one berry a day. Death starts after ~2 days
## with no food (1 day to max hunger + 1 day of draining health).
const HUNGER_MAX := 100.0
const HUNGER_PER_TICK := 100.0 / 120.0  # full → starving in 1 day
const HUNGER_SEEK := 50.0  # start looking for food at half hunger
const BERRY_HUNGER := 50.0  # hunger restored by one berry
const HEALTH_MAX := 100.0
const STARVE_DRAIN_PER_TICK := 100.0 / 120.0  # health 100 → 0 in 1 day of starving
const HEALTH_REGEN_PER_TICK := 2.0  # health recovered per tick while fed
const FORAGE_RANGE := 20  # tiles; how far a hungry person will walk for food
const FORAGE_MARGIN := 4  # tiles past their territory a citizen may forage

var agents: Array[SimAgent] = []
var world: GodSimWorld = null
var villages: Villages = null  # set by Main; used to keep citizens near home

## Emitted when a child is born. village_name is "" for a nomad birth;
## Main stamps the day and lets the EventLog aggregate births.
signal child_born(village_name: String)

## Emitted when a person dies of starvation. village_name is "" for a
## nomad; Main logs it (aggregated per village per day, like births).
signal starved(village_name: String)

## Emitted when a person dies of old age. village_name is "" for a
## nomad; Main logs it (aggregated per village per day).
signal old_age_died(village_name: String)

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

## One simulation tick: hunger and health, movement, then maybe breed.
## dt is the tick length in seconds (used for movement).
func tick(dt: float) -> void:
	var i := 0
	while i < agents.size():
		var a := agents[i]
		a.age += 1.0
		a.breed_cooldown = maxf(0.0, a.breed_cooldown - 1.0)
		if a.kind == SimAgent.Kind.PERSON:
			if _update_hunger(a):
				# Starved to death — removed from the list, so don't
				# advance i; the next agent slid into this slot.
				continue
			if _update_aging(a):
				# Died of old age — same removal, same rule.
				continue
			_try_eat(a)
		_move_agent(a, dt)
		if a.kind == SimAgent.Kind.PERSON and a.job >= 0 and not a.is_child():
			_do_job(a)
		i += 1
	_try_breed()
	queue_redraw()

## A citizen's work. Farmers tend the forest in the inner half of their
## territory (one berry per 30 ticks — 4 a day, twice a tile's natural
## regrowth, which is what makes a farmer worth more than the land
## alone); woodcutters clear the forest at the outer edge (one tile per
## day), so the forest edge near the village recedes while the tended
## core stays fed. Builders need no per-tick work — each one raises the
## house count (see Villages.house_count). A worker with nothing to do
## (no forest in their half) just waits — they keep the job.
func _do_job(a: SimAgent) -> void:
	a.job_timer -= 1.0
	if a.job_timer > 0.0:
		return
	if a.village < 0 or villages == null or a.village >= villages.villages.size():
		return
	var v: Villages.VillageData = villages.villages[a.village]
	var radius := villages.territory_radius_px(v)
	if a.job == SimAgent.JOB_FARMER:
		a.job_timer = 15.0
		# Phase 6: the farmer harvests food into the village store —
		# one unit per 15 ticks (8 a day) — but only where there's
		# forest to farm in the inner half of the territory. The berries
		# on the map are natural regrowth now, foraged when the store is
		# empty. (Phase 5's tend — adding a berry to the map — is
		# replaced by this: the farmer's output is the stockpile, and
		# the stockpile number in the village label is the visible food.)
		if _has_forest_in_inner_half(v, radius * 0.5):
			v.food += 1.0
	elif a.job == SimAgent.JOB_WOODCUTTER:
		a.job_timer = 120.0
		var t := _furthest_forest_tile(v, radius * 0.5, radius + 2.0 * GodSimWorld.TILE)
		if t.x >= 0:
			world.set_terrain(t.x, t.y, GodSimWorld.Terrain.GRASS)
			# Phase 6: felling a tile yields timber for the store.
			v.wood += Villages.WOOD_PER_TILE

## Is there any forest to farm in the inner half of the territory?
## A farmer only produces food where there's land to farm — a village
## on open grass has no farmers at all (see _assign_jobs), and a
## village whose inner forest is gone stops producing until the land
## recovers. Woodcutters only clear the outer ring, so they don't eat
## the farmers' land. Picking a forest tile directly (instead of a
## random tile and hoping it's forest) is what makes farmers actually
## feed a village — on open land with only a few forest tiles, a random
## pick almost never lands on one.
func _has_forest_in_inner_half(v: Villages.VillageData, max_r: float) -> bool:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var r_tiles := int(ceil(max_r / GodSimWorld.TILE))
	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var t := Vector2i(v.tile.x + dx, v.tile.y + dy)
			if not world.in_bounds(t.x, t.y):
				continue
			if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
				continue
			if world.tile_to_world(t.x, t.y).distance_to(center) > max_r:
				continue
			return true
	return false

## The forest tile furthest from the village centre inside the annulus
## [min_r, max_r] — the forest edge, which is what a woodcutter clears.
## Returns (-1,-1) when there is no forest in the ring.
func _furthest_forest_tile(v: Villages.VillageData, min_r: float, max_r: float) -> Vector2i:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var best := Vector2i(-1, -1)
	var best_d := -1.0
	var r_tiles := int(ceil(max_r / GodSimWorld.TILE))
	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var t := Vector2i(v.tile.x + dx, v.tile.y + dy)
			if not world.in_bounds(t.x, t.y):
				continue
			if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
				continue
			var d := world.tile_to_world(t.x, t.y).distance_to(center)
			if d < min_r or d > max_r:
				continue
			if d > best_d:
				best_d = d
				best = t
	return best

## Hunger rises every tick; at max hunger, health drains. Returns true
## if the person starved to death (and removes them from the list).
func _update_hunger(a: SimAgent) -> bool:
	a.hunger = minf(HUNGER_MAX, a.hunger + HUNGER_PER_TICK)
	if a.hunger >= HUNGER_MAX:
		a.health -= STARVE_DRAIN_PER_TICK
		if a.health <= 0.0:
			var home_name := ""
			if a.village >= 0 and villages != null and a.village < villages.villages.size():
				home_name = villages.villages[a.village].name
			agents.erase(a)
			starved.emit(home_name)
			return true
	else:
		# Fed: slowly recover any health lost to an earlier hunger spell.
		a.health = minf(HEALTH_MAX, a.health + HEALTH_REGEN_PER_TICK)
	return false

## Old age: when a person's age reaches their randomized lifespan,
## they die. Returns true if they died (and removes them from the list).
func _update_aging(a: SimAgent) -> bool:
	if a.age < a.lifespan:
		return false
	var home_name := ""
	if a.village >= 0 and villages != null and a.village < villages.villages.size():
		home_name = villages.villages[a.village].name
	agents.erase(a)
	old_age_died.emit(home_name)
	return true

## If this person is hungry: first eat from their village's food store
## (Phase 6 — the stockpile is the first resort), then forage a berry.
## A citizen with food in the store doesn't need to walk anywhere; a
## nomad, or a citizen whose store is empty, forages as before.
func _try_eat(a: SimAgent) -> void:
	if a.hunger < HUNGER_SEEK:
		return
	if a.kind == SimAgent.Kind.PERSON and a.village >= 0 and villages != null and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		if v.food >= 1.0:
			v.food -= 1.0
			a.hunger = maxf(0.0, a.hunger - BERRY_HUNGER)
			return
	var tile := world.world_to_tile(a.pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := Vector2i(tile.x + dx, tile.y + dy)
			if world.in_bounds(t.x, t.y) and world.eat_berry(t):
				a.hunger = maxf(0.0, a.hunger - BERRY_HUNGER)
				return

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
## The exception is hunger: a hungry person walks to the nearest food
## first (see _nearest_food_tile) — they may step a few tiles past
## their border to forage, but no further.
func _pick_target(a: SimAgent) -> Vector2:
	if a.kind == SimAgent.Kind.PERSON and a.hunger >= HUNGER_SEEK:
		var food := _nearest_food_tile(a)
		if food.x >= 0:
			return world.tile_to_world(food.x, food.y)
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

## Nearest forest tile with berries this person may walk to, searching
## outward ring by ring from where they stand (up to FORAGE_RANGE
## tiles). Citizens may only forage inside their territory plus a
## small margin past the border — a village with no forest nearby
## starves, which is the point: land matters. Nomads range freely.
## Returns Vector2i(-1, -1) when no reachable food exists.
func _nearest_food_tile(a: SimAgent) -> Vector2i:
	var from := world.world_to_tile(a.pos)
	var home_center := Vector2.ZERO
	var home_limit := INF
	if villages != null and a.village >= 0 and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		home_center = world.tile_to_world(v.tile.x, v.tile.y)
		home_limit = villages.territory_radius_px(v) + FORAGE_MARGIN * GodSimWorld.TILE
	for r in range(1, FORAGE_RANGE + 1):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var t := Vector2i(from.x + dx, from.y + dy)
				if _is_food_tile(t, home_center, home_limit):
					return t
		for dy in range(-r + 1, r):
			for dx in [-r, r]:
				var t := Vector2i(from.x + dx, from.y + dy)
				if _is_food_tile(t, home_center, home_limit):
					return t
	return Vector2i(-1, -1)

func _is_food_tile(t: Vector2i, home_center: Vector2, home_limit: float) -> bool:
	if not world.in_bounds(t.x, t.y):
		return false
	if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
		return false
	if world.berries_at(t) <= 0:
		return false
	if home_limit < INF:
		if world.tile_to_world(t.x, t.y).distance_to(home_center) > home_limit:
			return false
	return true

func _try_breed() -> void:	# A creature breeds when it stands next to another of its kind on good
	# land, its cooldown has expired, and the population cap allows it.
	# (We iterate a copy of the list because breeding appends to it.)
	var people := count_people()
	var sheep := count_animals()
	for a in agents.duplicate():
		if a.breed_cooldown > 0.0:
			continue
		if a.is_child():
			# Children are too young to have children of their own.
			continue
		if a.kind == SimAgent.Kind.PERSON and a.hunger >= HUNGER_SEEK:
			# Only the well-fed breed. A village that outgrows its food
			# stops growing until its food catches up — this is what
			# lets the population settle at what the land can feed
			# instead of exploding to the cap and starving.
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
				var home_name := ""
				if a.village >= 0 and villages != null and a.village < villages.villages.size():
					home_name = villages.villages[a.village].name
				child_born.emit(home_name)
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
## Age shows: children are drawn smaller, elders keep full size but
## with grey hair (and they walk slower — see SimAgent.speed()).
func _draw_person(a: SimAgent) -> void:
	var bob := sin(a.age * 0.9) * 1.0
	var p := a.pos + Vector2(0, bob)
	var skin := SimAgent.PERSON_COLOR
	var dark := Color("#5a4632")
	var sc := 0.62 if a.is_child() else 1.0
	var hair := Color("#b0b0b0") if a.is_elder() else a.hair_color
	# Legs.
	draw_line(p + Vector2(-2.5, 4) * sc, p + Vector2(-2.5, 9) * sc, dark, 2.0 * sc)
	draw_line(p + Vector2(2.5, 4) * sc, p + Vector2(2.5, 9) * sc, dark, 2.0 * sc)
	# Tunic: shoulders to hem.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-5, -2) * sc, p + Vector2(5, -2) * sc,
		p + Vector2(6.5, 5) * sc, p + Vector2(-6.5, 5) * sc,
	]), a.shirt_color)
	# Arms.
	draw_line(p + Vector2(-5, -1) * sc, p + Vector2(-7.5, 3) * sc, a.shirt_color, 2.0 * sc)
	draw_line(p + Vector2(5, -1) * sc, p + Vector2(7.5, 3) * sc, a.shirt_color, 2.0 * sc)
	# Head with a hair cap on top.
	draw_circle(p + Vector2(0, -6) * sc, 3.6 * sc, skin)
	draw_arc(p + Vector2(0, -6) * sc, 3.6 * sc, PI, TAU, 10, hair, 2.2 * sc)
	# A working citizen wears their job: a small dot above the head and
	# a trim stripe at the tunic hem, both in the job's color.
	if a.job >= 0:
		var jc: Color = SimAgent.JOB_COLORS[a.job]
		draw_circle(p + Vector2(0, -12) * sc, 2.5 * sc, jc)
		draw_line(p + Vector2(-6.5, 5) * sc, p + Vector2(6.5, 5) * sc, jc, 1.5 * sc)

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
