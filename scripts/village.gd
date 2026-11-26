class_name Villages
extends Node2D

## Owns all villages: founding, growth, territories, and drawing.
##
## A village is founded when at least FOUND_PEOPLE people stand close
## together (within FOUND_RADIUS tiles). Every village owns a territory
## — a circle around its centre whose radius grows with its population —
## and every person belongs to exactly one village (or to none, as a
## nomad). Citizens stay near home and wander inside their own border;
## a nomad who walks into a territory joins that village, and children
## are born into their parent's village.
##
## VillageData is a small inner class — just the data for one village.
## (GDScript allows one named class per file, so the data lives inside
## the manager instead of in its own file.)

class VillageData:
	var name: String = ""
	var tile: Vector2i = Vector2i.ZERO
	var founded_day: int = 1
	var color: Color = Color.WHITE

	func _init(p_name: String, p_tile: Vector2i, p_day: int, p_color: Color) -> void:
		name = p_name
		tile = p_tile
		founded_day = p_day
		color = p_color

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
const MIN_TERRITORY := 5   # territory radius in tiles, even for a young village
const MAX_TERRITORY := 10  # territory radius in tiles, even for a huge village

## One colour per village, cycled in founding order — the same colour
## draws the territory border and the ring under each citizen, so you
## can see at a glance who belongs where.
const VILLAGE_COLORS := [
	Color("#e74c3c"), Color("#3498db"), Color("#f39c12"), Color("#9b59b6"),
	Color("#1abc9c"), Color("#e67e22"), Color("#fd79a8"), Color("#00cec9"),
]

var villages: Array[VillageData] = []
var world: GodSimWorld = null
var agents: Agents = null

## Emitted when a village is founded. Main stamps the day and logs it.
signal village_founded(village_name: String)

var _scan_counter := 0

func clear_all() -> void:
	villages.clear()
	queue_redraw()

func count() -> int:
	return villages.size()

## One simulation tick: look for new villages and new citizens, then redraw.
func tick(current_day: int) -> void:
	# Founding and claiming scan people, so only do them every 8th tick —
	# villages don't need to appear instantly.
	_scan_counter += 1
	if _scan_counter % 8 == 0:
		_try_found(current_day)
		_assign_people()
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
		var new_index := villages.size()
		var color: Color = VILLAGE_COLORS[new_index % VILLAGE_COLORS.size()]
		villages.append(VillageData.new(village_name, tile, current_day, color))
		village_founded.emit(village_name)
		# The people standing here are the founders — they belong to the
		# new village from the moment it exists.
		var center := world.tile_to_world(tile.x, tile.y)
		for founder in agents.agents:
			if founder.kind == SimAgent.Kind.PERSON and founder.village < 0 and founder.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
				founder.village = new_index
		return

## Claim nomads: any person without a village who stands inside a
## territory joins the nearest village whose border contains them.
## (Assigned citizens keep their village even if they wander into
## another territory — they belong where they were claimed or born.)
func _assign_people() -> void:
	if agents == null or world == null:
		return
	for a in agents.agents:
		if a.kind != SimAgent.Kind.PERSON or a.village >= 0:
			continue
		var best := -1
		var best_d := INF
		for i in villages.size():
			var v := villages[i]
			var d := a.pos.distance_to(world.tile_to_world(v.tile.x, v.tile.y))
			if d <= territory_radius_px(v) and d < best_d:
				best = i
				best_d = d
		if best >= 0:
			a.village = best

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

## Citizens of a village: the people assigned to it, not just whoever
## happens to be standing nearby.
func population_of(v: VillageData) -> int:
	if agents == null:
		return 0
	var idx := villages.find(v)
	if idx < 0:
		return 0
	var n := 0
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == idx:
			n += 1
	return n

## A village's territory grows with its citizens: 4 tiles plus one per
## 3 citizens, between 5 and 10 tiles.
func territory_radius_tiles(v: VillageData) -> int:
	return clampi(4 + population_of(v) / 3, MIN_TERRITORY, MAX_TERRITORY)

func territory_radius_px(v: VillageData) -> float:
	return float(territory_radius_tiles(v) * GodSimWorld.TILE)

func house_count(v: VillageData) -> int:
	return clampi(population_of(v) / POP_PER_HOUSE, 1, MAX_HOUSES)

func _draw() -> void:
	if world == null:
		return
	var font: Font = ThemeDB.fallback_font
	for v in villages:
		var center := world.tile_to_world(v.tile.x, v.tile.y)
		var radius := territory_radius_px(v)
		# Territory: a faint tint of the village colour, with a border
		# circle so the edge of the land is visible.
		draw_circle(center, radius, Color(v.color, 0.06))
		draw_arc(center, radius, 0, TAU, 64, Color(v.color, 0.65), 2.0)
		var houses := house_count(v)
		for i in houses:
			# Golden angle (~137.5°) spreads houses around the centre
			# without them lining up in a row.
			var angle := float(i) * 2.39996
			var hradius := 16.0 + float(i % 3) * 11.0
			var hp := center + Vector2(cos(angle), sin(angle)) * hradius
			_draw_house(hp)
		if font != null:
			# Centre the name above the village, with the citizen count
			# and a dark shadow so it stays readable on any terrain.
			var label := "%s · %d" % [v.name, population_of(v)]
			var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			var text_pos := center + Vector2(-size.x * 0.5, -26)
			draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.75))
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	# A ring in the village colour under each citizen, at their feet —
	# that is how you can see who belongs to which village.
	if agents != null:
		for a in agents.agents:
			if a.kind == SimAgent.Kind.PERSON and a.village >= 0 and a.village < villages.size():
				var vc: Color = villages[a.village].color
				draw_arc(a.pos + Vector2(0, 8), 7.0, 0, TAU, 20, Color(vc, 0.85), 1.5)

func _draw_house(pos: Vector2) -> void:
	var body := Rect2(pos - Vector2(5, 2), Vector2(10, 8))
	draw_rect(body, Color("#8a5a2b"))
	var roof := PackedVector2Array([
		pos + Vector2(-7, -2),
		pos + Vector2(0, -9),
		pos + Vector2(7, -2),
	])
	draw_colored_polygon(roof, Color("#c0392b"))
