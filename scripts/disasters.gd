class_name Disasters
extends Node

## Phase 9 — disasters. The world can hurt itself, and the god can
## hurt it too. Three kinds:
##   Plague — spreads between people standing close, kills the weak,
##     then burns out when the sick have died or recovered immune.
##   Drought — for a season no food grows and the lakes shrink.
##   Wildfire — walks through the forest, leaving scorched land.
## Random disasters arrive every 15–30 days, with a 1-day warning in
## the History first, so the player is not blindsided. The player can
## also trigger one with the Disaster button (10-day cooldown) — it
## unleashes a random disaster where they tap.
## This node is the scheduler and the starter: the plague itself lives
## in agents.gd (sick people, spread, drain), the drought and the fire
## live in world.gd (no growth, shrinking lakes, burning tiles).

enum Kind { PLAGUE, DROUGHT, WILDFIRE }

const DISASTER_MIN_GAP := 15  # days between random disasters (soonest)
const DISASTER_MAX_GAP := 30  # days between random disasters (latest)
const WARNING_DAYS := 1       # the warning comes a day before it hits
const TRIGGER_COOLDOWN_TICKS := 1200  # 10 days on the Disaster button

var world: GodSimWorld = null
var agents: Agents = null
var villages: Villages = null
var event_log: EventLog = null

var current_day: int = 1
var next_disaster_day: int = 20  # first random disaster, day 15–30
var pending: Dictionary = {}  # {} = none; else {kind, start_day, tile}
var trigger_cooldown: int = 0  # ticks left on the Disaster button

# What was active last tick, so the end of a disaster gets its log line.
var _was_sick := 0
var _was_burning := false
var _was_drought := false

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	next_disaster_day = current_day + _rng.randi_range(DISASTER_MIN_GAP, DISASTER_MAX_GAP)

func trigger_cooldown_remaining() -> int:
	return trigger_cooldown

## One tick of disaster time — Main calls this every tick with the day.
## Warnings go out a day before a disaster hits; endings get logged
## when the sick are gone, the fire is out, or the drought has passed.
func tick(day: int) -> void:
	current_day = day
	if trigger_cooldown > 0:
		trigger_cooldown -= 1
	if not pending.is_empty():
		if day >= int(pending.get("start_day", day)):
			_start_pending()
			pending = {}
	elif day >= next_disaster_day:
		_warn_random()
	# Endings: log when a disaster that was running has finished. The
	# drought check uses the day passed in, not world.current_day —
	# world.tick (which sets current_day) runs after this, so the
	# world's day is one tick stale here.
	var sick_now := agents.count_sick() if agents != null else 0
	var burning_now := not world.burning.is_empty() if world != null else false
	var drought_now := day < world.drought_until_day if world != null else false
	if _was_sick > 0 and sick_now == 0:
		event_log.add(day, "The plague has burned out — the survivors are immune")
	if _was_burning and not burning_now:
		event_log.add(day, "The wildfire has burned out, leaving scorched land")
	if _was_drought and not drought_now:
		event_log.add(day, "The drought has ended — the land breathes again")
	_was_sick = sick_now
	_was_burning = burning_now
	_was_drought = drought_now

## The player's Disaster button: unleash a random disaster where they
## tap. Returns the kind started (0/1/2), or -1 while it recharges. A
## wildfire needs forest to catch — when there is none near the tap,
## it falls back to a plague or a drought instead, so the button never
## spends its cooldown on nothing.
func trigger_random(tile: Vector2i, day: int) -> int:
	if trigger_cooldown > 0:
		return -1
	var kind := _rng.randi_range(0, 2)
	if kind == Kind.WILDFIRE and _nearest_forest_tile(tile).x < 0:
		kind = Kind.PLAGUE if _rng.randf() < 0.5 else Kind.DROUGHT
	match kind:
		Kind.PLAGUE:
			start_plague_at(tile, day)
		Kind.DROUGHT:
			start_drought(day)
		Kind.WILDFIRE:
			start_wildfire_at(tile)
	trigger_cooldown = TRIGGER_COOLDOWN_TICKS
	return kind

## Start a plague at a tile: infect everyone standing close to it.
## Returns how many were infected (0 when nobody is there).
func start_plague_at(tile: Vector2i, day: int) -> int:
	var pos := world.tile_to_world(tile.x, tile.y)
	var n := agents.infect_at(pos, 2.0 * GodSimWorld.TILE)
	var home := _village_name_at(tile)
	if home != "":
		event_log.add(day, "Plague has come to %s!" % home)
	else:
		event_log.add(day, "Plague has come to the wilds!")
	return n

## Start a drought (world-wide): no food grows for a season, and the
## lakes shrink a tile at a time.
func start_drought(day: int) -> void:
	world.start_drought(day)
	event_log.add(day, "A drought has come — the lakes shrink and the land dries")

## Start a wildfire at a tile: the nearest forest tile catches. Returns
## false when there is no forest there to burn.
func start_wildfire_at(tile: Vector2i) -> bool:
	var t := _nearest_forest_tile(tile)
	if t.x < 0:
		return false
	world.ignite(t)
	event_log.add(current_day, "A wildfire has started in the forest!")
	return true

## Schedule the next random disaster, with a 1-day warning first.
func _warn_random() -> void:
	var kind := _rng.randi_range(0, 2)
	var tile := Vector2i(-1, -1)
	match kind:
		Kind.PLAGUE:
			tile = _random_village_tile()
		Kind.WILDFIRE:
			tile = _random_forest_tile()
	pending = {"kind": kind, "start_day": current_day + WARNING_DAYS, "tile": tile}
	match kind:
		Kind.PLAGUE:
			var home := _village_name_at(tile)
			event_log.add(current_day, "The air grows foul in %s — plague is coming" % (home if home != "" else "the wilds"))
		Kind.DROUGHT:
			event_log.add(current_day, "The land grows dry — a drought is coming")
		Kind.WILDFIRE:
			event_log.add(current_day, "Smoke rises on the horizon — a wildfire is coming")
	_schedule_next()

func _start_pending() -> void:
	var kind: int = int(pending.get("kind", 0))
	var tile: Vector2i = pending.get("tile", Vector2i(-1, -1))
	match kind:
		Kind.PLAGUE:
			start_plague_at(tile, current_day)
		Kind.DROUGHT:
			start_drought(current_day)
		Kind.WILDFIRE:
			start_wildfire_at(tile)

func _schedule_next() -> void:
	next_disaster_day = current_day + _rng.randi_range(DISASTER_MIN_GAP, DISASTER_MAX_GAP)

## A random village's centre tile (for a plague warning/start), or
## (-1,-1) when there is no village yet.
func _random_village_tile() -> Vector2i:
	if villages == null or villages.villages.is_empty():
		return Vector2i(-1, -1)
	var v: Villages.VillageData = villages.villages[_rng.randi_range(0, villages.villages.size() - 1)]
	return v.tile

## A random forest tile (for a wildfire warning/start), or (-1,-1) when
## there is no forest.
func _random_forest_tile() -> Vector2i:
	for tries in 200:
		var x := _rng.randi_range(1, GodSimWorld.WIDTH - 2)
		var y := _rng.randi_range(1, GodSimWorld.HEIGHT - 2)
		if world.get_terrain(x, y) == GodSimWorld.Terrain.FOREST:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

## The nearest forest tile to a tap (for a player-triggered wildfire),
## searching outward to 8 tiles, or (-1,-1) when there is none.
func _nearest_forest_tile(tile: Vector2i) -> Vector2i:
	for r in range(0, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := Vector2i(tile.x + dx, tile.y + dy)
				if world.in_bounds(t.x, t.y) and world.get_terrain(t.x, t.y) == GodSimWorld.Terrain.FOREST:
					return t
	return Vector2i(-1, -1)

## The name of the village whose territory holds this tile, or "".
func _village_name_at(tile: Vector2i) -> String:
	if villages == null:
		return ""
	var idx := villages.village_at_tile(tile)
	if idx < 0:
		return ""
	return villages.villages[idx].name
