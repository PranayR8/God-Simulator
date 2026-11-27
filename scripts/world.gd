class_name GodSimWorld
extends Node2D

## The grid world: terrain data, procedural generation, and drawing.
##
## Terrain is stored as one flat int array (row-major: index = y * WIDTH + x).
## Drawing happens in _draw() with plain rects and shapes — no TileSet
## needed, which keeps the project simple and reliable on every platform.

const WIDTH := 64
const HEIGHT := 48
const TILE := 24.0

# Terrain type ids. SCORCHED is what lightning and meteors leave behind.
enum Terrain { GRASS, WATER, FOREST, MOUNTAIN, SCORCHED }

## Phase 15 — mountain resources. Each mountain tile holds one of four
## resources, tiered by rarity: stone (common), iron, marble, steel
## (rarest). The resource is a pure function of the tile and the
## world's seed, so it needs no storage and survives a save/load — a
## mountain keeps its resource until a miner takes it (the tile
## becomes grass). Miners haul the resource to their village, and the
## eras advance on what the villages have stockpiled (stone -> Bronze,
## iron -> Iron, marble -> Classical, steel -> Medieval).
const RES_STONE := 0
const RES_IRON := 1
const RES_MARBLE := 2
const RES_STEEL := 3
const RES_NAMES := ["Stone", "Iron", "Marble", "Steel"]

func mountain_resource_at(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
	var roll: int = abs(h) % 100
	if roll < 60:
		return RES_STONE
	if roll < 85:
		return RES_IRON
	if roll < 95:
		return RES_MARBLE
	return RES_STEEL

const TERRAIN_COLORS := {
	Terrain.GRASS: Color("#7ec850"),
	Terrain.WATER: Color("#3f8fd2"),
	Terrain.FOREST: Color("#3f9e4d"),
	Terrain.MOUNTAIN: Color("#8d8d94"),
	Terrain.SCORCHED: Color("#5a4a3a"),
}

var seed_value: int = 12345
var terrain: Array[int] = []

## Berries: the food on forest tiles (Phase 2). One entry per forest
## tile that has any berries, mapping tile -> berry count (0..BERRY_MAX).
## A tile with no entry has no berries. Berries regrow over time and
## are eaten by hungry people standing nearby.
var berries: Dictionary = {}

const BERRY_MAX := 5            # berries on a forest tile when fully grown
const BERRY_REGROW_TICKS := 60  # ticks for one berry to regrow per forest tile (Autumn's normal rate)

## Seasons (Phase 7): a year is 4 seasons of 15 days (60 days).
## Spring = births and food growth up; Summer = food growth peak;
## Autumn = harvest, stockpiles fill; Winter = no food growth, and the
## cold drains the health of anyone without shelter or food. Day 1 is
## the first day of Spring. A static so Main, Agents and the World can
## all ask for the season on a given day.
const SEASON_DAYS := 15
const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_SPRING := 0
const SEASON_SUMMER := 1
const SEASON_AUTUMN := 2
const SEASON_WINTER := 3

static func season_index_for_day(day: int) -> int:
	return ((day - 1) / SEASON_DAYS) % 4

static func season_name_for_day(day: int) -> String:
	return SEASON_NAMES[season_index_for_day(day)]

## The season right now (set by tick; day 1 is Spring).
var season: int = SEASON_SPRING
var current_day: int = 1  # set by tick(); the drought and the fire are dated by day

## Drought (Phase 9). drought_until_day is the first day the drought
## has ended (0 = no drought). While it runs, no food grows — berries
## do not regrow and farmers produce nothing — and the lakes shrink a
## little every day (water tiles at the edge turn to grass).
const DROUGHT_DAYS := 15  # one season
var drought_until_day: int = 0
var _drought_counter := 0  # ticks since the last lake tile shrank

## Wildfire (Phase 9). burning maps a tile to the ticks of fire left
## on it (a tile burns for a day, then is left scorched). Each tick a
## burning tile can ignite each adjacent forest tile, so a fire walks
## through a forest and ends when it runs out of fuel.
const FIRE_BURN_TICKS := 120  # 1 day of fire per tile
const FIRE_SPREAD_CHANCE := 0.02  # per tick, per adjacent forest tile
var burning: Dictionary = {}

func is_drought() -> bool:
	return current_day < drought_until_day

func start_drought(day: int) -> void:
	drought_until_day = day + DROUGHT_DAYS
	queue_redraw()

## Start a fire on a forest tile. Returns false when the tile is not
## forest (or is already burning) — the fire needs fuel to catch.
func ignite(tile: Vector2i) -> bool:
	if not in_bounds(tile.x, tile.y):
		return false
	if get_terrain(tile.x, tile.y) != Terrain.FOREST:
		return false
	if burning.has(tile):
		return false
	burning[tile] = FIRE_BURN_TICKS
	queue_redraw()
	return true

## Put a fire out (rain does this) — the tile is left as grass.
func extinguish(tile: Vector2i) -> void:
	if burning.has(tile):
		burning.erase(tile)
		set_terrain(tile.x, tile.y, Terrain.GRASS)
		queue_redraw()

var _rng := RandomNumberGenerator.new()
var _regrow_counter := 0

func _ready() -> void:
	terrain.resize(WIDTH * HEIGHT)
	terrain.fill(Terrain.GRASS)


# --- helpers ---------------------------------------------------------------

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func index(x: int, y: int) -> int:
	return y * WIDTH + x

func get_terrain(x: int, y: int) -> int:
	if not in_bounds(x, y):
		# Outside the map counts as water: unwalkable, unpaintable.
		return Terrain.WATER
	return terrain[index(x, y)]

func set_terrain(x: int, y: int, value: int) -> void:
	if in_bounds(x, y):
		terrain[index(x, y)] = value
		# Berries live on forest tiles: a new forest starts lush, and a
		# tile that stops being forest loses its berries.
		var t := Vector2i(x, y)
		if value == Terrain.FOREST:
			if not berries.has(t):
				berries[t] = BERRY_MAX
		else:
			berries.erase(t)

func tile_to_world(tx: int, ty: int) -> Vector2:
	return Vector2((tx + 0.5) * TILE, (ty + 0.5) * TILE)

func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE), int(pos.y / TILE))

func is_walkable(x: int, y: int) -> bool:
	var t := get_terrain(x, y)
	return t == Terrain.GRASS or t == Terrain.FOREST

## Deterministic pseudo-random number for a tile (0..99). Used for
## decorations so trees and wave marks don't jump around between frames.
func tile_hash(x: int, y: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
	return abs(h) % 100


# --- berries (food) ---------------------------------------------------------

## Berries on a tile (0 when there is no forest or no berries left).
func berries_at(tile: Vector2i) -> int:
	return int(berries.get(tile, 0))

## Eat one berry from a tile. Returns true when there was one to eat.
func eat_berry(tile: Vector2i) -> bool:
	var n := berries_at(tile)
	if n <= 0:
		return false
	if n == 1:
		berries.erase(tile)
	else:
		berries[tile] = n - 1
	queue_redraw()
	return true

## A farmer tending a forest tile: add one berry, up to BERRY_MAX.
## Returns false when the tile isn't forest or is already full.
func add_berry(tile: Vector2i) -> bool:
	if not in_bounds(tile.x, tile.y):
		return false
	if get_terrain(tile.x, tile.y) != Terrain.FOREST:
		return false
	var n := berries_at(tile)
	if n >= BERRY_MAX:
		return false
	berries[tile] = n + 1
	queue_redraw()
	return true

## One simulation tick: berries regrow, the drought bites, the fire
## spreads. The interval follows the season (Phase 7): Spring grows
## fast (45), Summer is the peak (30), Autumn is normal (60), and
## Winter grows nothing at all. A drought (Phase 9) also grows nothing
## — and shrinks the lakes a tile at a time. The day is passed in by
## Main (it owns the day count).
func tick(p_season: int, p_day: int) -> void:
	current_day = p_day
	if p_season != season:
		season = p_season
		queue_redraw()  # the map tint changes with the season
	_tick_fire()
	if is_drought():
		_tick_drought()
		return  # Drought: nothing grows.
	var interval := _regrow_interval(season)
	if interval <= 0:
		return  # Winter: nothing grows.
	_regrow_counter += 1
	if _regrow_counter < interval:
		return
	_regrow_counter = 0
	for y in HEIGHT:
		for x in WIDTH:
			if terrain[index(x, y)] == Terrain.FOREST:
				var t := Vector2i(x, y)
				var n := berries_at(t)
				if n < BERRY_MAX:
					berries[t] = n + 1
	queue_redraw()

## Drought (Phase 9): every 30 ticks one water tile at the edge of a
## lake dries up and turns to grass — about 4 a day, 60 over the
## season, so the lakes visibly shrink without a small one vanishing
## overnight. The loss lasts (rain does not refill a lake).
func _tick_drought() -> void:
	_drought_counter += 1
	if _drought_counter < 30:
		return
	_drought_counter = 0
	for tries in 40:
		var x := _rng.randi_range(1, WIDTH - 2)
		var y := _rng.randi_range(1, HEIGHT - 2)
		if get_terrain(x, y) != Terrain.WATER:
			continue
		if not _has_land_neighbour(x, y):
			continue
		set_terrain(x, y, Terrain.GRASS)
		queue_redraw()
		return

func _has_land_neighbour(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if get_terrain(x + d.x, y + d.y) != Terrain.WATER:
			return true
	return false

## Wildfire (Phase 9): each burning tile counts down, and while it burns
## it can ignite each adjacent forest tile. When a tile's fire runs out
## it is left scorched. The fire ends when it runs out of forest to
## catch — or when rain puts it out.
func _tick_fire() -> void:
	if burning.is_empty():
		return
	var tiles: Array = burning.keys()
	for t in tiles:
		var tile: Vector2i = t
		var left: int = int(burning[tile]) - 1
		if left <= 0:
			burning.erase(tile)
			set_terrain(tile.x, tile.y, Terrain.SCORCHED)
		else:
			burning[tile] = left
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(tile.x + d.x, tile.y + d.y)
				if in_bounds(n.x, n.y) and get_terrain(n.x, n.y) == Terrain.FOREST and not burning.has(n):
					if _rng.randf() < FIRE_SPREAD_CHANCE:
						burning[n] = FIRE_BURN_TICKS
	queue_redraw()

## Ticks between berry regrowths, by season. Winter returns 0 (never).
func _regrow_interval(p_season: int) -> int:
	if p_season == SEASON_SPRING:
		return 45
	if p_season == SEASON_SUMMER:
		return 30
	if p_season == SEASON_AUTUMN:
		return BERRY_REGROW_TICKS
	return 0

## Give every forest tile a full load of berries (used when loading an
## old save that stored no berry data).
func rebuild_berries() -> void:
	berries.clear()
	for y in HEIGHT:
		for x in WIDTH:
			if terrain[index(x, y)] == Terrain.FOREST:
				berries[Vector2i(x, y)] = BERRY_MAX
	queue_redraw()


# --- generation ------------------------------------------------------------

func generate_new(p_seed: int = -1) -> void:
	if p_seed < 0:
		p_seed = randi()
	seed_value = p_seed
	_rng.seed = seed_value
	terrain.fill(Terrain.GRASS)
	_scatter_blobs(Terrain.WATER, 5, 24, 60)
	_scatter_blobs(Terrain.FOREST, 9, 30, 80)
	_scatter_blobs(Terrain.MOUNTAIN, 4, 6, 14)
	queue_redraw()

## Random-walk blobs: pick a start tile, then wander around painting
## terrain as you go. That gives natural lakes, forests, and mountain
## ranges instead of perfect rectangles.
func _scatter_blobs(type: int, blob_count: int, min_size: int, max_size: int) -> void:
	for i in blob_count:
		var x := _rng.randi_range(2, WIDTH - 3)
		var y := _rng.randi_range(2, HEIGHT - 3)
		var size := _rng.randi_range(min_size, max_size)
		for s in size:
			set_terrain(x, y, type)
			# Random step: -1, 0 or +1 on each axis.
			x = clampi(x + _rng.randi_range(-1, 1), 1, WIDTH - 2)
			y = clampi(y + _rng.randi_range(-1, 1), 1, HEIGHT - 2)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var t: int = terrain[index(x, y)]
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(rect, TERRAIN_COLORS[t])
			if t == Terrain.FOREST:
				_draw_tree(x, y)
				_draw_berries(x, y)
			elif t == Terrain.MOUNTAIN:
				_draw_peak(x, y)
			elif t == Terrain.WATER and tile_hash(x, y) < 12:
				# A few faint wave marks so water doesn't look flat.
				draw_line(
					rect.position + Vector2(4, TILE * 0.5),
					rect.position + Vector2(TILE - 4, TILE * 0.5),
					Color(1, 1, 1, 0.25), 1.5
				)
	# Phase 7 — the map tints by season so you can tell it at a glance:
	# Spring is fresh and bright, Summer warm, Autumn golden, Winter
	# pale blue-white (snow). Drawn last in the World's own layer, so it
	# tints the land but the villages and people drawn on top of it stay
	# bright and readable.
	# Phase 9 — burning tiles: an orange flame with a yellow heart, so
	# a wildfire reads at a glance.
	for t in burning.keys():
		var tile: Vector2i = t
		var c := Vector2((tile.x + 0.5) * TILE, (tile.y + 0.5) * TILE)
		draw_circle(c, 12.0, Color(1.0, 0.5, 0.1, 0.75))
		draw_circle(c, 6.0, Color(1.0, 0.85, 0.2, 0.9))
	var tint := _season_tint(season)
	if tint.a > 0.0:
		draw_rect(Rect2(0, 0, WIDTH * TILE, HEIGHT * TILE), tint)
	# Phase 9 — a drought parches the map: a dry brown tint over the
	# season's own, so a drought looks different from any season. It
	# is as strong as Winter's tint — a drought should read at a
	# glance, not just in the log.
	if is_drought():
		draw_rect(Rect2(0, 0, WIDTH * TILE, HEIGHT * TILE), Color(0.7, 0.55, 0.25, 0.20))

## The season's tint over the whole map. Spring is barely there (the
## base grass green already reads as spring); Winter is the strongest,
## so the world visibly whitens.
func _season_tint(p_season: int) -> Color:
	if p_season == SEASON_SPRING:
		return Color(0.2, 0.8, 0.2, 0.05)
	if p_season == SEASON_SUMMER:
		return Color(1.0, 0.85, 0.3, 0.06)
	if p_season == SEASON_AUTUMN:
		return Color(0.9, 0.5, 0.1, 0.10)
	return Color(0.85, 0.9, 1.0, 0.22)

func _draw_tree(x: int, y: int) -> void:
	var h := tile_hash(x, y)
	var cx := (x + 0.35 + 0.3 * float(h % 10) / 10.0) * TILE
	var cy := (y + 0.35 + 0.3 * float((h / 10) % 10) / 10.0) * TILE
	draw_circle(Vector2(cx, cy), 6.0, Color("#2c7a38"))
	draw_circle(Vector2(cx - 2, cy - 2), 3.0, Color("#57b368"))

## Berries: small red dots on a forest tile, one per berry (up to
## BERRY_MAX). Fixed positions, so they don't jump around between
## frames — the count is what changes as they are eaten and regrow.
func _draw_berries(x: int, y: int) -> void:
	var n := berries_at(Vector2i(x, y))
	if n <= 0:
		return
	var centre := Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
	var spots := [
		Vector2(-7, -5), Vector2(7, -6), Vector2(-6, 6),
		Vector2(6, 6), Vector2(0, -8),
	]
	for i in mini(n, spots.size()):
		draw_circle(centre + spots[i], 2.2, Color("#d43d2a"))

func _draw_peak(x: int, y: int) -> void:
	var base := Vector2(x * TILE, (y + 1) * TILE)
	var top := Vector2((x + 0.5) * TILE, y * TILE + 4)
	var right := Vector2((x + 1) * TILE, (y + 1) * TILE)
	draw_colored_polygon(PackedVector2Array([base, top, right]), Color("#6f6f76"))
	# Snow cap.
	draw_colored_polygon(
		PackedVector2Array([top, top + Vector2(5, 6), top + Vector2(-5, 6)]),
		Color("#f4f6f8")
	)
