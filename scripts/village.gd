class_name Villages
extends Node2D

## Owns all villages: founding, growth, and drawing.
##
## A village is founded when at least FOUND_PEOPLE people stand close
## together (within FOUND_RADIUS tiles). It grows houses as its population
## grows, and its name is drawn above it on the map.
##
## VillageData is a small inner class — just the data for one village.
## (GDScript allows one named class per file, so the data lives inside
## the manager instead of in its own file.)

class VillageData:
	var name: String = ""
	var tile: Vector2i = Vector2i.ZERO
	var founded_day: int = 1

	func _init(p_name: String, p_tile: Vector2i, p_day: int) -> void:
		name = p_name
		tile = p_tile
		founded_day = p_day

const NAMES := [
	"Wilwick", "Kelholt", "Bramley", "Oakhaven", "Millford",
	"Thornbury", "Emberfell", "Stonebridge", "Fairfield", "Dunmore",
	"Ravenwood", "Goldfield", "Hillcrest", "Brookfield", "Ashford",
	"Windermere", "Copperton", "Elmswood", "Fox Hollow", "Marlowe",
]

const FOUND_PEOPLE := 6    # people within FOUND_RADIUS tiles to found a village
const FOUND_RADIUS := 4    # in tiles
const MIN_VILLAGE_GAP := 8  # tiles between village centres
const POP_PER_HOUSE := 3
const MAX_HOUSES := 12

var villages: Array[VillageData] = []
var world: GodSimWorld = null
var agents: Agents = null

var _scan_counter := 0

func clear_all() -> void:
	villages.clear()
	queue_redraw()

func count() -> int:
	return villages.size()

## One simulation tick: look for new villages, then redraw.
func tick(current_day: int) -> void:
	# Founding scans people, so only do it every 8th tick — villages
	# don't need to appear instantly.
	_scan_counter += 1
	if _scan_counter % 8 == 0:
		_try_found(current_day)
	queue_redraw()

func _try_found(current_day: int) -> void:
	if agents == null or world == null:
		return
	# Use each person as a candidate centre, but stop at the first village
	# founded this tick so founding stays gradual.
	for a in agents.agents:
		if a.kind != SimAgent.Kind.PERSON:
			continue
		var tile := world.world_to_tile(a.pos)
		if agents.people_near(tile, FOUND_RADIUS) < FOUND_PEOPLE:
			continue
		if _near_existing_village(tile):
			continue
		var village_name := _next_name()
		if village_name == "":
			return
		villages.append(VillageData.new(village_name, tile, current_day))
		return

func _near_existing_village(tile: Vector2i) -> bool:
	for v in villages:
		# Manhattan distance keeps villages from clumping together.
		if abs(v.tile.x - tile.x) + abs(v.tile.y - tile.y) < MIN_VILLAGE_GAP:
			return true
	return false

func _next_name() -> String:
	var used := {}
	for v in villages:
		used[v.name] = true
	for n in NAMES:
		if not used.has(n):
			return n
	# All names used — fall back to numbered villages.
	return "Village %d" % (villages.size() + 1)

func population_of(v: VillageData) -> int:
	if agents == null:
		return 0
	return agents.people_near(v.tile, 5)

func house_count(v: VillageData) -> int:
	return clampi(population_of(v) / POP_PER_HOUSE, 1, MAX_HOUSES)

func _draw() -> void:
	if world == null:
		return
	var font: Font = ThemeDB.fallback_font
	for v in villages:
		var center := world.tile_to_world(v.tile.x, v.tile.y)
		var houses := house_count(v)
		for i in houses:
			# Golden angle (~137.5°) spreads houses around the centre
			# without them lining up in a row.
			var angle := float(i) * 2.39996
			var radius := 16.0 + float(i % 3) * 11.0
			var hp := center + Vector2(cos(angle), sin(angle)) * radius
			_draw_house(hp)
		if font != null:
			# Centre the name above the village, with a dark shadow so
			# it stays readable on any terrain.
			var size := font.get_string_size(v.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			var text_pos := center + Vector2(-size.x * 0.5, -26)
			draw_string(font, text_pos + Vector2(1, 1), v.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.75))
			draw_string(font, text_pos, v.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func _draw_house(pos: Vector2) -> void:
	var body := Rect2(pos - Vector2(5, 2), Vector2(10, 8))
	draw_rect(body, Color("#8a5a2b"))
	var roof := PackedVector2Array([
		pos + Vector2(-7, -2),
		pos + Vector2(0, -9),
		pos + Vector2(7, -2),
	])
	draw_colored_polygon(roof, Color("#c0392b"))
