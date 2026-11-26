class_name Villages
extends Node2D

## Owns all villages: founding, growth, territories, and drawing.
##
## A village is founded when at least FOUND_PEOPLE people stand close
## together (within FOUND_RADIUS tiles). A group that forms close to an
## existing village joins it instead of founding a new one right next
## door, so villages stay well spaced and their territories stay apart.
## Every village owns a territory — a circle around its centre whose
## radius grows with its population and stops at the halfway point to
## its nearest neighbour, so two territories meet at their border but
## never overlap. Every person belongs to exactly one village (or to
## none, as a nomad). Citizens stay near home and wander inside their
## own border; a nomad who comes within a few tiles of a village's
## border joins that village, and children are born into their
## parent's village.
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
const FOUND_JOIN_MARGIN := 4  # tiles beyond a village's territory where a group still joins it instead of founding
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

## Emitted when a group joins an existing village instead of founding.
## Main logs it so the player can see the village growing.
signal people_joined(village_name: String, count: int)

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
		# A group standing close to an existing village joins it instead
		# of founding a new one right next door — this is what keeps
		# villages well spaced and their territories apart.
		if _try_join_nearby_village(tile):
			return
		if _near_existing_village(tile):
			continue
		# Founding needs a real group to found it: people_near counts
		# citizens too, so a knot of another village's people far from
		# home could otherwise found a village with no founders at all
		# ("Kelholt · 0"). Only unassigned people can be founders.
		var center := world.tile_to_world(tile.x, tile.y)
		var founders_near := 0
		for p in agents.agents:
			if p.kind == SimAgent.Kind.PERSON and p.village < 0 and p.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
				founders_near += 1
		if founders_near < FOUND_PEOPLE:
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
		for founder in agents.agents:
			if founder.kind == SimAgent.Kind.PERSON and founder.village < 0 and founder.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
				founder.village = new_index
		return

## If the group at this tile stands close to an existing village, they
## join it instead of founding: every unassigned person within
## FOUND_RADIUS of the tile becomes a citizen of the nearest village
## whose territory plus FOUND_JOIN_MARGIN reaches them. Returns true
## when a join happened (one action per scan, same as founding).
## The range uses the village's POPULATION radius, not its capped
## territory: when neighbours crowd in, the cap shrinks the border,
## and a group just outside that shrunken border would found a new
## village right next door — the exact thing this rule exists to
## prevent. The population radius is the village's real sphere of
## influence.
## This also covers a group standing inside a territory — founding
## runs before claiming on the same tick, so without this check a
## group inside a village's own land could found a second village
## there.
func _try_join_nearby_village(tile: Vector2i) -> bool:
	var best: VillageData = null
	var best_d := INF
	for v in villages:
		var d := Vector2(tile - v.tile).length()
		if d < best_d:
			best_d = d
			best = v
	if best == null:
		return false
	if best_d > influence_radius_tiles(best):
		return false
	var center := world.tile_to_world(tile.x, tile.y)
	var idx := villages.find(best)
	var joined := 0
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village < 0 and a.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
			a.village = idx
			joined += 1
	if joined > 0:
		people_joined.emit(best.name, joined)
		return true
	return false

## Claim nomads: any person without a village who comes within a
## village's sphere of influence joins the nearest such village —
## inside its territory, or just outside it within the join margin.
## This is what sweeps up stragglers: when a group joins a village,
## the dense core joins at once and anyone who drifted a few tiles out
## follows as soon as they wander near the border. (Assigned citizens
## keep their village even if they wander into another territory —
## they belong where they were claimed or born.)
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
			if d <= float(influence_radius_tiles(v) * GodSimWorld.TILE) and d < best_d:
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

## The territory radius from population alone, before the neighbour
## cap — the village's natural size, used for its sphere of
## influence (see _try_join_nearby_village).
func _population_radius_tiles(v: VillageData) -> int:
	return clampi(4 + population_of(v) / 3, MIN_TERRITORY, MAX_TERRITORY)

## A village's territory grows with its citizens: 4 tiles plus one per
## 3 citizens, between 5 and 10 tiles — but it never overlaps a
## neighbour's territory. The border between two villages sits at the
## halfway point: each village's radius is capped at half the distance
## to its nearest neighbour (rounded down, so the two radii together
## can never exceed the distance between the villages). A lone village
## with no neighbours just uses its population radius. The 2-tile floor
## is safe: villages always found at least ~5.7 tiles apart, so half
## that distance is never below 2.
func territory_radius_tiles(v: VillageData) -> int:
	var r := _population_radius_tiles(v)
	var gap := _nearest_neighbour_gap_tiles(v)
	if gap < INF:
		r = mini(r, int(gap * 0.5))
	return maxi(r, 2)

## Distance in tiles to the closest other village (INF when alone).
func _nearest_neighbour_gap_tiles(v: VillageData) -> float:
	var best := INF
	for other in villages:
		if other == v:
			continue
		var d := Vector2(v.tile - other.tile).length()
		if d < best:
			best = d
	return best

## A village's sphere of influence: its population territory plus the
## join margin. Nomads inside this range join the village (see
## _assign_people); groups inside it join instead of founding (see
## _try_join_nearby_village). Uses the population radius, not the
## capped territory, so a crowded village's pull doesn't shrink with
## its border — the cap is about drawing borders, not about who
## belongs where.
func influence_radius_tiles(v: VillageData) -> int:
	return _population_radius_tiles(v) + FOUND_JOIN_MARGIN

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
