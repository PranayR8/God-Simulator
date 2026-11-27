class_name Villages
extends Node2D

## Owns all villages: founding, growth, territories, and drawing.
##
## A village is founded when at least FOUND_PEOPLE people stand close
## together (within FOUND_RADIUS tiles). A group that forms close to an
## existing village joins it instead of founding a new one right next
## door, so villages stay well spaced and their territories stay apart.
## Every village owns a territory — a claimed set of square tiles
## around its centre, WorldBox-style: the border is blocky, and the
## shape is whatever the village needed. The territory grows tile by
## tile as the village grows, and each new tile is claimed for a
## reason — a hungry village reaches for the forest, a village with
## miners reaches for the mountains, a village with room to grow
## takes the open grass. Two territories never overlap: a tile
## belongs to one village, and a village can only claim tiles its
## neighbours haven't. Every person belongs to exactly one village
## (or to none, as a nomad). Citizens live near home but are free to
## wander out and explore the world beyond the border — they always
## drift back. A nomad who comes within a few tiles of a village's
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
	## The stage last written to the log (-1 = not yet adopted, e.g.
	## right after a save is loaded — the first stage check adopts the
	## current stage silently so a load never logs a fake promotion).
	var stage: int = -1
	## Phase 6 — stockpiles. food is the village store: farmers add to
	## it, citizens eat from it first (before foraging berries). wood is
	## the timber store: woodcutters add 2 per felled tile, and each
	## extra house a builder raises costs HOUSE_WOOD_COST. Both start
	## empty — a new village has to produce before it can store.
	var food: float = 0.0
	var wood: float = 0.0
	## Phase 15 — the mined stockpiles. Miners haul these from the
	## mountains: stone (common), iron, marble, steel (rarest). The
	## eras advance on what the villages have stockpiled (stone ->
	## Bronze, iron -> Iron, marble -> Classical, steel -> Medieval),
	## and the label shows the ones a village actually has.
	var stone: float = 0.0
	var iron: float = 0.0
	var marble: float = 0.0
	var steel: float = 0.0
	## Builder-bonus houses actually constructed (each cost wood). The
	## base houses (one per 3 citizens) are free — they're the village's
	## basic dwellings — so a village with builders but no wood still
	## has its basic houses; it just doesn't get the extra ones.
	var extra_houses_built: int = 0
	## Phase 8 — blessing. blessed_until_day is the first day the
	## blessing has worn off (0 = never blessed). While the current day
	## is before it, the village is blessed: its people breed twice as
	## often and its farmers bring in one extra unit of food per cycle.
	var blessed_until_day: int = 0
	## Phase 17 — kingdoms. The kingdom this village belongs to
	## (-1 = independent). A Town founds a kingdom or joins a nearby
	## one; the kingdom's king (the capital's oldest hero) boosts every
	## village in it.
	var kingdom: int = -1
	## Phase 19 — the territory: the set of square tiles this village
	## has claimed (Dictionary: Vector2i -> true). The border is the
	## outline of these tiles, and the shape is whatever the village
	## needed — forest when hungry, mountains when mining, grass when
	## growing. A tile belongs to one village; claiming only ever adds
	## tiles adjacent to ones already claimed.
	var tiles: Dictionary = {}
	## The first day this village may join a kingdom again (0 = no
	## cooldown). A village that rebels is barred from rejoining for
	## 30 days, so a secession is not undone the next morning — it
	## founds its own kingdom instead.
	var join_cooldown_until_day: int = 0
	## Phase 10 — war. last_war_day is the day the village's last war
	## ended (0 = never at war). A village cannot raid again until
	## WAR_COOLDOWN_DAYS have passed since then, so a war is an event,
	## not a permanent state — the villages get time to recover, and a
	## village that just fought does not immediately start another.
	var last_war_day: int = 0

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
const START_TERRITORY_HALF := 2  # a new village claims a 5x5 square of tiles (water skipped)
const GROW_TILES_PER_SCAN := 2  # tiles a village may claim per 8th-tick scan while below its cap

## Phase 6 — the stockpile economy. A builder-bonus house costs this
## much wood; a woodcutter gets this much wood per felled tile. One
## food feeds one person once (restores 50 hunger, the same as a berry).
const HOUSE_WOOD_COST := 2.0
const WOOD_PER_TILE := 2.0

## Growth stages (Phase 4): a village's stage is its citizen count —
## Hamlet at 6, Village at 15, Town at 30, City at 60. Each stage
## grows the territory cap (in claimed tiles), lets more (and bigger)
## houses appear, and at Town the village gains a wall ring, at City a
## keep. The stage is always derived from the current population, so a
## village that loses people falls back down a stage just as it climbed
## up.
const STAGE_NAMES := ["Hamlet", "Village", "Town", "City"]
const STAGE_MIN_POP := [6, 15, 30, 60]
## Phase 19 — the territory cap, in claimed tiles per stage. Roughly
## the area the old circular territories held (a radius-7 circle is
## ~150 tiles, radius 16 is ~800), so a village has about as much land
## as before — it is just square now, and shaped by what it needed.
const STAGE_TERRITORY_TILES := [150, 300, 500, 800]
const STAGE_HOUSE_CAPS := [12, 16, 20, 24]
const STAGE_HOUSE_SCALES := [1.0, 1.15, 1.3, 1.45]

## Phase 15 — one house style per era [body, roof]. Stone: a small
## thatch hut. Bronze: larger warm timber. Iron: grey stone and slate.
## Classical: white marble with a terracotta roof and a column.
## Medieval: dark stone with a steep dark roof.
const ERA_HOUSE_BODY := [Color("#8a5a2b"), Color("#a67c52"), Color("#7d7468"), Color("#f4f6f7"), Color("#616a6b")]
const ERA_HOUSE_ROOF := [Color("#c0392b"), Color("#b87333"), Color("#5d6d7e"), Color("#e67e22"), Color("#2c3e50")]
## The keep's stone, per era (a City's tower follows the age too).
const ERA_KEEP := [Color("#6b7a8d"), Color("#8d6e63"), Color("#5d6d7e"), Color("#f4f6f7"), Color("#2c3e50")]

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
var kingdoms: Kingdoms = null  # set by Main; a kingdom colours its villages' borders
## Phase 15 — the current era (set by Main each tick from Goals).
## The houses redraw in the era's style, so a village's look shifts
## as the age advances.
var era: int = 0

## Emitted when a village is founded. Main stamps the day and logs it.
signal village_founded(village_name: String)

## Emitted when a group joins an existing village instead of founding.
## Main logs it so the player can see the village growing.
signal people_joined(village_name: String, count: int)

## Emitted when a village's stage changes (growth or decline).
## Main logs it ("Wilwick became a Town" / "Wilwick fell back to a
## Village") so a hamlet becoming a town reads as an achievement.
signal stage_changed(village_name: String, old_stage: int, new_stage: int)

## A citizen took up a job (job_name is one of SimAgent.JOB_NAMES).
signal job_taken(village_name: String, job_name: String)

var _scan_counter := 0

func clear_all() -> void:
	villages.clear()
	queue_redraw()

func count() -> int:
	return villages.size()

## One simulation tick: look for new villages and new citizens, then redraw.
var current_day: int = 1  # the day this tick is for; _draw uses it for the blessed border

func tick(p_day: int) -> void:
	current_day = p_day
	# Founding and claiming scan people, so only do them every 8th tick —
	# villages don't need to appear instantly.
	_scan_counter += 1
	if _scan_counter % 8 == 0:
		_try_found(current_day)
		_assign_people()
		_check_stages()
		_assign_jobs()
		_build_houses()
		for v in villages:
			grow_territory(v)
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
		claim_starting_territory(villages[new_index])
		village_founded.emit(village_name)
		# The people standing here are the founders — they belong to the
		# new village from the moment it exists. The first of them is
		# the village's first citizen, and a founder becomes a hero
		# (Phase 11): they are the one the village remembers.
		var first_founder: SimAgent = null
		for founder in agents.agents:
			if founder.kind == SimAgent.Kind.PERSON and founder.village < 0 and founder.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
				founder.village = new_index
				if first_founder == null:
					first_founder = founder
		if first_founder != null:
			agents.make_hero(first_founder, "founder of " + village_name)
		# Adopt the founding stage silently — the founding log line
		# already covers it, and a fresh village shouldn't also log
		# "became a Hamlet" (or a Village, if a big cluster founded it).
		villages[new_index].stage = stage_of(villages[new_index])
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
## The distance is measured to the CLOSEST member of the group, not to
## the candidate tile: a group is a spread-out handful of people, and
## the candidate is whichever one the scan happened to pick — if the
## nearest member is within the village's reach, the group is touching
## the village and joins. Measuring to one arbitrary member made the
## join flaky (a person who wandered a tile or two further out could
## veto the whole group's join).
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
	var center := world.tile_to_world(tile.x, tile.y)
	var idx := villages.find(best)
	# The group: unassigned people within FOUND_RADIUS of the candidate.
	var group: Array = []
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village < 0 and a.pos.distance_to(center) <= FOUND_RADIUS * GodSimWorld.TILE:
			group.append(a)
	if group.is_empty():
		return false
	# Closest member to the village decides whether the group is near:
	# if any member stands on the village's land, or within the join
	# margin of its border, the group is touching the village and joins.
	var touching := false
	for a in group:
		if near_territory(best, world.world_to_tile(a.pos), FOUND_JOIN_MARGIN):
			touching = true
			break
	if not touching:
		return false
	var joined := 0
	for a in group:
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
		var at := world.world_to_tile(a.pos)
		for i in villages.size():
			var v := villages[i]
			if not near_territory(v, at, FOUND_JOIN_MARGIN):
				continue
			var d := a.pos.distance_to(world.tile_to_world(v.tile.x, v.tile.y))
			if d < best_d:
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

## The adult citizens of a village (children do not fight). Wars use
## this: the raiding party is half the attacker's adults, and the
## defenders are half the defender's adults (before the wall bonus).
func adults_of(v: VillageData) -> int:
	if agents == null:
		return 0
	var idx := villages.find(v)
	if idx < 0:
		return 0
	var n := 0
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == idx and not a.is_child():
			n += 1
	return n

## Watch every village's stage: a village that grows past a threshold
## is promoted (and logged), one that loses people falls back (and is
## logged too). A village whose stage was never adopted — freshly
## loaded from a save, where the citizens are still being re-claimed —
## adopts its current stage silently, so a load never logs a fake
## promotion. Runs on the same 8th-tick scan as founding and claiming.
func _check_stages() -> void:
	if agents == null:
		return
	for v in villages:
		var s := stage_of(v)
		if v.stage < 0:
			v.stage = s
			continue
		if s != v.stage:
			var old := v.stage
			v.stage = s
			stage_changed.emit(v.name, old, s)

## The stage index (0 Hamlet .. 3 City) for a citizen count.
func stage_index_for(pop: int) -> int:
	if pop >= STAGE_MIN_POP[3]:
		return 3
	if pop >= STAGE_MIN_POP[2]:
		return 2
	if pop >= STAGE_MIN_POP[1]:
		return 1
	return 0

## The stage of a village right now, from its current population.
func stage_of(v: VillageData) -> int:
	return stage_index_for(population_of(v))

func stage_name(v: VillageData) -> String:
	return STAGE_NAMES[stage_of(v)]

## The map label: name, stage, citizens, and the two stockpiles —
## "Wilwick · Town · 33 · F12 · W8". F is food, W is wood.
func label_text(v: VillageData) -> String:
	var text := "%s · %s · %d · F%d · W%d" % [v.name, stage_name(v), population_of(v), int(v.food), int(v.wood)]
	if v.stone >= 1.0:
		text += " · S%d" % int(v.stone)
	if v.iron >= 1.0:
		text += " · I%d" % int(v.iron)
	if v.marble >= 1.0:
		text += " · M%d" % int(v.marble)
	if v.steel >= 1.0:
		text += " · St%d" % int(v.steel)
	# Phase 17 — a member that is not the capital shows its kingdom
	# (the capital's name); the capital's crown says it already.
	if kingdoms != null and v.kingdom >= 0 and v.kingdom < kingdoms.kingdoms.size():
		var k: Kingdoms.KingdomData = kingdoms.kingdoms[v.kingdom]
		if k.capital != villages.find(v):
			text += " · %s" % kingdoms.kingdoms[v.kingdom].name.trim_prefix("Kingdom of ")
	return text

## Is this village currently blessed (Phase 8)? The blessing lasts a
## season — 15 days from the day it was given.
func is_blessed(v: VillageData, day: int) -> bool:
	return day < v.blessed_until_day

## Which village's territory contains this tile, or -1 if the tile
## belongs to no village. A tile belongs to one village — the claimed
## set is the source of truth, so there is no nearest-centre guessing.
## Bless Village (Phase 8) targets through this — the god taps a
## village's land.
func village_at_tile(tile: Vector2i) -> int:
	return _tile_owner(tile)

## Phase 19 — the territory, as claimed square tiles.
##
## Is this tile inside the village's territory (claimed by it)?
func is_in_territory(v: VillageData, tile: Vector2i) -> bool:
	return v.tiles.has(tile)

## Is this tile inside the territory, or within `margin` tiles of it
## (Chebyshev distance — a square ring around the border)? This is the
## village's sphere of influence: a nomad inside it joins the village
## (see _assign_people), a group inside it joins instead of founding
## (see _try_join_nearby_village), and a citizen may forage inside it.
## It is checked by looking for a claimed tile in the (2m+1)^2 window
## around the tile, so it is cheap and exact for a blocky border.
func near_territory(v: VillageData, tile: Vector2i, margin: int) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			if v.tiles.has(Vector2i(tile.x + dx, tile.y + dy)):
				return true
	return false

## How many tiles the village has claimed.
func territory_tile_count(v: VillageData) -> int:
	return v.tiles.size()

## The territory cap, in claimed tiles, from the village's stage —
## 150 as a Hamlet, 300 as a Village, 500 as a Town, 800 as a City.
## A village that loses people falls back a stage and stops growing
## (it keeps the land it already has).
func territory_cap_tiles(v: VillageData) -> int:
	return STAGE_TERRITORY_TILES[stage_of(v)]

## How far the territory reaches from the centre, in pixels — the
## furthest claimed tile. Used where a single "how big is this
## village" number is needed (a war party has arrived, a house's
## reach, the label's clearance). The border itself is the tile
## outline, not this circle.
func territory_extent_px(v: VillageData) -> float:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var best := 0.0
	for t in v.tiles.keys():
		var d := world.tile_to_world(t.x, t.y).distance_to(center)
		if d > best:
			best = d
	return best

## Claim the starting territory: a square around the centre, half
## width START_TERRITORY_HALF (5x5). Water is never claimed — a
## village founded on a shore just has a smaller, shore-shaped start.
## Called once, when the village is founded.
func claim_starting_territory(v: VillageData) -> void:
	for dy in range(-START_TERRITORY_HALF, START_TERRITORY_HALF + 1):
		for dx in range(-START_TERRITORY_HALF, START_TERRITORY_HALF + 1):
			var t := Vector2i(v.tile.x + dx, v.tile.y + dy)
			if not world.in_bounds(t.x, t.y):
				continue
			if world.get_terrain(t.x, t.y) == GodSimWorld.Terrain.WATER:
				continue
			v.tiles[t] = true

## Grow the territory: claim up to GROW_TILES_PER_SCAN new tiles, if
## the village is below its stage cap. Each new tile is claimed for a
## reason, so the shape is what the village needed — a hungry village
## reaches for the forest, a village with miners reaches for the
## mountains, a village with room to grow takes the open grass, and
## every claim favours a tile hugged by land it already owns, so the
## border stays compact instead of sprawling into a thin line. A tile
## is only ever claimed if it touches the territory (4-neighbourhood),
## is inside the map, is not water, and no other village owns it.
func grow_territory(v: VillageData) -> void:
	if world == null:
		return
	var cap := territory_cap_tiles(v)
	for _i in GROW_TILES_PER_SCAN:
		if v.tiles.size() >= cap:
			return
		var best := Vector2i(-1, -1)
		var best_score := -1.0
		var seen := {}
		for t in v.tiles.keys():
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c: Vector2i = t + dir
				if seen.has(c):
					continue
				seen[c] = true
				if v.tiles.has(c):
					continue
				if not world.in_bounds(c.x, c.y):
					continue
				if world.get_terrain(c.x, c.y) == GodSimWorld.Terrain.WATER:
					continue
				if _tile_owner(c) >= 0:
					continue
				var sc := _score_claim_tile(v, c)
				if sc > best_score:
					best_score = sc
					best = c
		if best.x < 0:
			return
		v.tiles[best] = true

## Which village owns this tile, or -1 (no village claims it). The
## tile set is the single source of truth — a tile belongs to one
## village, so territories can never overlap.
func _tile_owner(tile: Vector2i) -> int:
	for i in villages.size():
		if villages[i].tiles.has(tile):
			return i
	return -1

## How much this village wants a tile, when it grows. Forest is food
## and timber, so a hungry village (less than ~2 days of food in the
## store) or a village short on wood reaches for it hard; mountains
## are the mine, so a village with miners reaches for them; grass is
## just room to grow. Every candidate also gains a point per claimed
## neighbour, so the border fills in its gaps instead of reaching out
## in a thin arm.
func _score_claim_tile(v: VillageData, tile: Vector2i) -> float:
	var terrain := world.get_terrain(tile.x, tile.y)
	var sc := 0.0
	match terrain:
		GodSimWorld.Terrain.FOREST:
			sc = 4.0
		GodSimWorld.Terrain.MOUNTAIN:
			sc = 6.0
		_:
			sc = 2.0
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if v.tiles.has(tile + dir):
			sc += 1.0
	var pop := population_of(v)
	if terrain == GodSimWorld.Terrain.FOREST:
		if v.food < float(pop) * 2.0:
			sc += 8.0
		if v.wood < HOUSE_WOOD_COST * 2.0:
			sc += 6.0
	if terrain == GodSimWorld.Terrain.MOUNTAIN and _miners_of(v) > 0:
		sc += 4.0
	return sc

## Miners among this village's citizens.
func _miners_of(v: VillageData) -> int:
	if agents == null:
		return 0
	var idx := villages.find(v)
	if idx < 0:
		return 0
	var n := 0
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == idx and a.job == SimAgent.JOB_MINER:
			n += 1
	return n

## How far the territory reaches in one direction, in pixels — the
## last claimed tile along a ray from the centre. Houses are placed
## inside this reach, so they never stand outside the border.
func _extent_in_direction(v: VillageData, angle: float) -> float:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var dir := Vector2(cos(angle), sin(angle))
	var step := float(GodSimWorld.TILE) * 0.5
	var best := 0.0
	var d := step
	while d < 40.0 * GodSimWorld.TILE:
		var t := world.world_to_tile(center + dir * d)
		if not v.tiles.has(t):
			break
		best = d
		d += step
	return best

func house_count(v: VillageData) -> int:
	# The houses actually standing: the base dwellings (one per 3
	# citizens, free — Phase 4) plus the builder-bonus houses that have
	# been constructed (each cost wood — Phase 6), capped by the stage.
	# A village with builders but no wood has only its base houses.
	var base := clampi(population_of(v) / POP_PER_HOUSE, 1, STAGE_HOUSE_CAPS[stage_of(v)])
	return mini(base + v.extra_houses_built, STAGE_HOUSE_CAPS[stage_of(v)])

## Builders among this village's citizens.
func builders_of(v: VillageData) -> int:
	if agents == null:
		return 0
	var idx := villages.find(v)
	if idx < 0:
		return 0
	var n := 0
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == idx and a.job == SimAgent.JOB_BUILDER:
			n += 1
	return n

## Forest tiles inside this village's territory — the claimed tiles
## that are forest. The land its jobs work with; used to pick the job
## mix. (A village that claimed forest when it was hungry has food to
## farm; one that never needed it has none.)
func _forest_tiles_in_territory(v: VillageData) -> int:
	if world == null:
		return 0
	var n := 0
	for t in v.tiles.keys():
		if world.get_terrain(t.x, t.y) == GodSimWorld.Terrain.FOREST:
			n += 1
	return n

## Mountains inside the territory (for the miner share of jobs) — the
## claimed tiles that are mountains.
func _mountain_tiles_in_territory(v: VillageData) -> int:
	if world == null:
		return 0
	var n := 0
	for t in v.tiles.keys():
		if world.get_terrain(t.x, t.y) == GodSimWorld.Terrain.MOUNTAIN:
			n += 1
	return n

## Give every adult citizen a job, based on what's nearby. Runs on the
## same 8th-tick scan as founding and claiming. A villager picks the job
## their village needs most: the target mix follows the forest inside
## the territory — a village in the woods gets farmers to tend the food
## and woodcutters to clear the edge, a village on open grass gets only
## builders (there is nothing to farm or fell). Children don't work; a
## child who grows up is hired at the next scan. A job is for life: when
## a worker dies, the next unassigned adult fills the gap. Each hire is
## logged (aggregated per job, village and day).
func _assign_jobs() -> void:
	if agents == null or world == null:
		return
	for vi in villages.size():
		var v := villages[vi]
		var forest := _forest_tiles_in_territory(v)
		var mountains := _mountain_tiles_in_territory(v)
		# Phase 15 — the miner share follows the mountains in the
		# territory: a village ringed by peaks hires miners, one on
		# open ground hires none. The four targets always sum to 1.
		var targets := [0.4, 0.3, 0.3, 0.0]
		if mountains >= 4:
			targets = [0.35, 0.25, 0.2, 0.2]
		elif mountains > 0:
			targets = [0.4, 0.3, 0.25, 0.05]
		if forest < 8:
			targets = [0.4, 0.2, 0.4, 0.0]
			if mountains >= 4:
				targets = [0.35, 0.2, 0.25, 0.2]
		if forest == 0:
			targets = [0.0, 0.0, 1.0, 0.0]
			if mountains >= 4:
				targets = [0.0, 0.0, 0.7, 0.3]
		var counts := [0, 0, 0, 0]
		var adults := 0
		for a in agents.agents:
			if a.kind == SimAgent.Kind.PERSON and a.village == vi and not a.is_child():
				adults += 1
				if a.job >= 0:
					counts[a.job] += 1
		for a in agents.agents:
			if a.kind != SimAgent.Kind.PERSON or a.village != vi or a.is_child() or a.job >= 0:
				continue
			# The most under-represented job, against its target share
			# of the adult workforce.
			var best := -1
			var best_deficit := -INF
			for j in 4:
				var deficit := float(targets[j]) * float(adults) - float(counts[j])
				if deficit > best_deficit:
					best_deficit = deficit
					best = j
			if best < 0:
				best = SimAgent.JOB_BUILDER
			a.job = best
			a.job_timer = 0.0
			counts[best] += 1
			job_taken.emit(v.name, SimAgent.JOB_NAMES[best])

## Build the extra houses the builders want, one per scan, as long as
## the store has wood. Runs on the same 8th-tick scan as hiring. The
## base houses are free; only the builder-bonus houses (one per
## builder, up to the stage cap) cost wood — so a village with builders
## but no woodcutters stays at its base house count until timber comes
## in, and a village that spends its wood on houses has less for the
## next one. Houses appear gradually, one at a time, which is visible
## on the map.
func _build_houses() -> void:
	for v in villages:
		var cap: int = STAGE_HOUSE_CAPS[stage_of(v)]
		var base := clampi(population_of(v) / POP_PER_HOUSE, 1, cap)
		var desired_extra := mini(builders_of(v), cap - base)
		if v.extra_houses_built < desired_extra and v.wood >= HOUSE_WOOD_COST:
			v.wood -= HOUSE_WOOD_COST
			v.extra_houses_built += 1

## Where the houses stand. The built-up area spreads as the village
## grows: a golden-angle spiral out to a built-up radius that grows
## with the population (24 + 2.6 per citizen) and is capped at 65% of
## A small gold crown, drawn above a kingdom's capital.
func _draw_crown(pos: Vector2) -> void:
	var gold := Color(1.0, 0.85, 0.2)
	var crown := PackedVector2Array([
		pos + Vector2(-7, 4), pos + Vector2(-7, -3), pos + Vector2(-3.5, 1),
		pos + Vector2(0, -5), pos + Vector2(3.5, 1), pos + Vector2(7, -3),
		pos + Vector2(7, 4),
	])
	draw_colored_polygon(crown, gold)
	draw_line(pos + Vector2(-7, 4), pos + Vector2(7, 4), Color(0.6, 0.45, 0.0), 1.5)

## the territory, so houses stay inside the border (and the wall).
## A new Hamlet clusters near the centre; a City spreads its houses
## across its land instead of piling them all on one spot. The
## square-root spacing keeps the density even — houses fill the area
## instead of clumping at the centre or ringing the edge. Each house's
## reach is the territory's extent in its own direction, so a house
## never stands outside a border that grew toward the forest on one
## side and stayed short on the other.
func house_positions(v: VillageData) -> Array[Vector2]:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var houses := house_count(v)
	var out: Array[Vector2] = []
	for i in houses:
		var angle := float(i) * 2.39996
		var extent := _extent_in_direction(v, angle)
		var built_radius := minf(extent * 0.65, 24.0 + 2.6 * float(population_of(v)))
		built_radius = maxf(built_radius, 20.0)
		var frac := sqrt(float(i) / float(maxi(houses - 1, 1)))
		var hradius := 16.0 + (built_radius - 16.0) * frac
		out.append(center + Vector2(cos(angle), sin(angle)) * hradius)
	return out

## Draw the territory's border — the blocky outline of the claimed
## tiles, WorldBox-style: for every claimed tile, every edge that
## borders land this village does not own gets a line in the border
## colour. `width` is the line width. Used by _draw and by Wars (the
## red war border, wider than the village's own so it covers it).
func draw_territory_border(v: VillageData, border_color: Color, width: float) -> void:
	var half := float(GodSimWorld.TILE) * 0.5
	for t in v.tiles.keys():
		var c := world.tile_to_world(t.x, t.y)
		if not v.tiles.has(Vector2i(t.x, t.y - 1)):
			draw_line(c + Vector2(-half, -half), c + Vector2(half, -half), border_color, width)
		if not v.tiles.has(Vector2i(t.x, t.y + 1)):
			draw_line(c + Vector2(-half, half), c + Vector2(half, half), border_color, width)
		if not v.tiles.has(Vector2i(t.x - 1, t.y)):
			draw_line(c + Vector2(-half, -half), c + Vector2(-half, half), border_color, width)
		if not v.tiles.has(Vector2i(t.x + 1, t.y)):
			draw_line(c + Vector2(half, -half), c + Vector2(half, half), border_color, width)

## Draw the territory's faint tint — the village colour over its
## claimed tiles. Tiles are grouped by row and each run of adjacent
## tiles in a row is one rect, so a compact territory is a few dozen
## rects, not one per tile.
func draw_territory_tint(v: VillageData) -> void:
	var half := float(GodSimWorld.TILE) * 0.5
	var tint := Color(v.color, 0.06)
	var rows := {}
	for t in v.tiles.keys():
		if not rows.has(t.y):
			rows[t.y] = []
		rows[t.y].append(t.x)
	for y in rows.keys():
		var xs: Array = rows[y]
		xs.sort()
		var run_start: int = xs[0]
		var run_end: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x == run_end + 1:
				run_end = x
			else:
				var c0 := world.tile_to_world(run_start, y)
				draw_rect(Rect2(c0 + Vector2(-half, -half), Vector2(float(run_end - run_start + 1) * GodSimWorld.TILE, GodSimWorld.TILE)), tint)
				run_start = x
				run_end = x
		var c1 := world.tile_to_world(run_start, y)
		draw_rect(Rect2(c1 + Vector2(-half, -half), Vector2(float(run_end - run_start + 1) * GodSimWorld.TILE, GodSimWorld.TILE)), tint)

func _draw() -> void:
	if world == null:
		return
	var font: Font = ThemeDB.fallback_font
	for v in villages:
		var center := world.tile_to_world(v.tile.x, v.tile.y)
		var stage := stage_of(v)
		# Territory: a faint tint of the village colour over its claimed
		# tiles, with a blocky border (WorldBox-style) so the edge of
		# the land is visible — and so you can see the shape the village
		# grew into. A blessed village (Phase 8) wears a gold border
		# instead, so you can see at a glance where the god's favour
		# rests. A kingdom's villages wear the kingdom colour.
		var border_color := v.color
		if kingdoms != null and v.kingdom >= 0 and v.kingdom < kingdoms.kingdoms.size():
			border_color = kingdoms.kingdoms[v.kingdom].color
		draw_territory_tint(v)
		# A wall at Town and above — the border drawn thick in stone
		# grey first, with the village colour on top, so the wall reads
		# as a wall and the colour still says whose it is.
		if stage >= 2:
			draw_territory_border(v, Color("#7d7468"), 4.0)
		if is_blessed(v, current_day):
			draw_territory_border(v, Color(1.0, 0.85, 0.2, 0.9), 3.0)
		else:
			draw_territory_border(v, Color(border_color, 0.65), 2.0)
		var houses := house_count(v)
		var house_scale: float = STAGE_HOUSE_SCALES[stage]
		for hp in house_positions(v):
			_draw_house(hp, house_scale)
		# A keep at City — a stone tower with battlements and the
		# village flag, drawn last so it stands at the centre.
		if stage >= 3:
			_draw_keep(center, v.color)
		# Phase 17 — the capital of a kingdom wears a gold crown
		# above its centre, so the seat of power is visible at a glance.
		if kingdoms != null and v.kingdom >= 0 and v.kingdom < kingdoms.kingdoms.size():
			if kingdoms.kingdoms[v.kingdom].capital == villages.find(v):
				_draw_crown(center + Vector2(0, -14))
		if font != null:
			# Centre the name above the village, with the stage and the
			# citizen count and a dark shadow so it stays readable on
			# any terrain.
			var label := label_text(v)
			var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			var text_pos := center + Vector2(-size.x * 0.5, -26)
			draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.75))
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	# A ring in the village colour under each citizen, at their feet —
	# that is how you can see who belongs to which village. A hero
	# (Phase 11) wears a golden ring instead — thicker and gold, so
	# the people who matter stand out from the crowd at a glance.
	if agents != null:
		for a in agents.agents:
			if a.kind == SimAgent.Kind.PERSON and a.village >= 0 and a.village < villages.size():
				if a.hero:
					draw_arc(a.pos + Vector2(0, 8), 8.0, 0, TAU, 20, Color(1.0, 0.85, 0.2, 1.0), 2.5)
				else:
					var vc: Color = villages[a.village].color
					draw_arc(a.pos + Vector2(0, 8), 7.0, 0, TAU, 20, Color(vc, 0.85), 1.5)

func _draw_house(pos: Vector2, house_scale: float) -> void:
	var e := clampi(era, 0, ERA_HOUSE_BODY.size() - 1)
	var body := Rect2(pos - Vector2(5, 2) * house_scale, Vector2(10, 8) * house_scale)
	draw_rect(body, ERA_HOUSE_BODY[e])
	# Medieval roofs are steeper (the apex reaches higher).
	var apex_y := -9.0 if e != 4 else -12.0
	var roof := PackedVector2Array([
		pos + Vector2(-7, -2) * house_scale,
		pos + Vector2(0, apex_y) * house_scale,
		pos + Vector2(7, -2) * house_scale,
	])
	draw_colored_polygon(roof, ERA_HOUSE_ROOF[e])
	# Classical houses carry a column on the front — the marble age
	# shows in the doorway.
	if e == 3:
		draw_rect(Rect2(pos + Vector2(-1, -2) * house_scale, Vector2(2, 8) * house_scale), Color("#d5dbdb"))

## The keep: a stone tower with battlements and the village flag.
## It sits at the centre of a City, above the houses.
func _draw_keep(center: Vector2, color: Color) -> void:
	var e := clampi(era, 0, ERA_KEEP.size() - 1)
	var stone: Color = ERA_KEEP[e]
	var body := Rect2(center + Vector2(-7, -6), Vector2(14, 20))
	draw_rect(body, stone)
	for i in 3:
		var mx := center.x - 7.0 + float(i) * 5.0
		draw_rect(Rect2(Vector2(mx, center.y - 10), Vector2(3, 4)), stone)
	var pole_top := center + Vector2(0, -10)
	draw_line(pole_top, pole_top + Vector2(0, -8), Color("#4a3f35"), 1.5)
	var flag := PackedVector2Array([
		pole_top + Vector2(0, -8),
		pole_top + Vector2(8, -6),
		pole_top + Vector2(0, -4),
	])
	draw_colored_polygon(flag, color)
