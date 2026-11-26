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

const TERRAIN_COLORS := {
	Terrain.GRASS: Color("#7ec850"),
	Terrain.WATER: Color("#3f8fd2"),
	Terrain.FOREST: Color("#3f9e4d"),
	Terrain.MOUNTAIN: Color("#8d8d94"),
	Terrain.SCORCHED: Color("#5a4a3a"),
}

var seed_value: int = 12345
var terrain: Array[int] = []

var _rng := RandomNumberGenerator.new()

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
			elif t == Terrain.MOUNTAIN:
				_draw_peak(x, y)
			elif t == Terrain.WATER and tile_hash(x, y) < 12:
				# A few faint wave marks so water doesn't look flat.
				draw_line(
					rect.position + Vector2(4, TILE * 0.5),
					rect.position + Vector2(TILE - 4, TILE * 0.5),
					Color(1, 1, 1, 0.25), 1.5
				)

func _draw_tree(x: int, y: int) -> void:
	var h := tile_hash(x, y)
	var cx := (x + 0.35 + 0.3 * float(h % 10) / 10.0) * TILE
	var cy := (y + 0.35 + 0.3 * float((h / 10) % 10) / 10.0) * TILE
	draw_circle(Vector2(cx, cy), 6.0, Color("#2c7a38"))
	draw_circle(Vector2(cx - 2, cy - 2), 3.0, Color("#57b368"))

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
