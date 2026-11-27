class_name SaveSystem
extends Node

## Saves the whole world to user://world.json and loads it back.
##
## user:// is Godot's per-user data folder — it works on every platform
## (on Android it's app storage, on Web it's the browser's IndexedDB).
## JSON keeps the save human-readable, which is handy while learning:
## you can open the file and see exactly what was saved.

const SAVE_PATH := "user://world.json"

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(world: GodSimWorld, agents: Agents, villages: Villages, event_log: EventLog, day: int, ticks: int, wars: Wars = null, goals: Goals = null, kingdoms: Kingdoms = null) -> bool:
	var data := {
		"version": 5,
		"seed": world.seed_value,
		"day": day,
		"ticks": ticks,
		"terrain": world.terrain,
		"berries": _berries_to_data(world),
		"agents": _agents_to_data(agents),
		"drought_until": world.drought_until_day,
		"burning": _burning_to_data(world),
		"villages": _villages_to_data(villages),
		"wars": wars.to_data() if wars != null else [],
		"goals": _goals_to_data(goals),
		"kingdoms": kingdoms.to_data() if kingdoms != null else [],
		"log": event_log.to_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open %s for writing" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

## Returns the loaded save as a Dictionary, or an empty one if there is
## no save (or it failed to parse).
func load_game() -> Dictionary:
	if not save_exists():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _agents_to_data(agents: Agents) -> Array:
	var out: Array = []
	for a in agents.agents:
		# Hunger/health only matter for people (sheep don't go hungry),
		# but storing them for everyone keeps the format uniform; old
		# saves without them load as full and healthy. Age and lifespan
		# are likewise stored for everyone (sheep keep 0, which they
		# ignore) so a loaded world keeps its generations instead of
		# resetting everyone to a newborn.
		out.append({"kind": a.kind, "x": a.pos.x, "y": a.pos.y, "hunger": a.hunger, "health": a.health, "age": a.age, "lifespan": a.lifespan, "job": a.job, "blessed": a.blessed, "sick": a.sick, "immune": a.immune, "at_war": a.at_war, "hero": a.hero, "hero_name": a.hero_name, "innate_trait": a.innate_trait, "hero_deed": a.hero_deed, "surname": a.surname, "generation": a.generation, "weapon_tier": a.weapon_tier, "armor_tier": a.armor_tier, "tool_tier": a.tool_tier})
	return out

## Berries as a flat list of [x, y, count] triples (only tiles that
## have any berries are stored).
func _berries_to_data(world: GodSimWorld) -> Array:
	var out: Array = []
	for tile in world.berries.keys():
		var t: Vector2i = tile
		out.append([t.x, t.y, int(world.berries[t])])
	return out

## Burning tiles as a flat list of [x, y, ticks-left] triples.
func _burning_to_data(world: GodSimWorld) -> Array:
	var out: Array = []
	for tile in world.burning.keys():
		var t: Vector2i = tile
		out.append([t.x, t.y, int(world.burning[t])])
	return out

func _villages_to_data(villages: Villages) -> Array:
	var out: Array = []
	for v in villages.villages:
		out.append({"name": v.name, "x": v.tile.x, "y": v.tile.y, "day": v.founded_day, "color": v.color.to_html(), "food": v.food, "wood": v.wood, "stone": v.stone, "iron": v.iron, "marble": v.marble, "steel": v.steel, "extra_houses": v.extra_houses_built, "blessed_until": v.blessed_until_day, "last_war": v.last_war_day, "kingdom": v.kingdom})
	return out

## Goals as a Dictionary (era, winters, wars won, achievements, and
## the scenario state). An absent goals node saves an empty dict, so
## old callers without goals keep working.
func _goals_to_data(goals: Goals) -> Dictionary:
	if goals == null:
		return {}
	return {
		"era": goals.era,
		"winters": goals.winters_survived,
		"wars_won": goals.wars_won,
		"achievements": goals.achievements,
		"scenario_state": goals.scenario_state,
		"scenario_reason": goals.scenario_reason,
	}

## Rebuild the world from loaded data. Returns false if the data is empty
## or unusable (caller should generate a fresh world instead).
## Old saves have no "log" key — the history just starts empty — and
## no "berries" key — forests restock to full (see rebuild_berries).
func apply_save(data: Dictionary, world: GodSimWorld, agents: Agents, villages: Villages, event_log: EventLog, wars: Wars = null, goals: Goals = null, kingdoms: Kingdoms = null) -> bool:
	if data.is_empty():
		return false
	world.seed_value = int(data.get("seed", 0))
	var loaded_terrain: Array = data.get("terrain", [])
	if loaded_terrain.size() == GodSimWorld.WIDTH * GodSimWorld.HEIGHT:
		world.terrain.clear()
		for value in loaded_terrain:
			world.terrain.append(int(value))
	else:
		# Save is from an older/different map size — regenerate instead.
		world.generate_new(world.seed_value)
	if data.has("berries"):
		world.berries.clear()
		for item in data.get("berries", []):
			var triple: Array = item
			if triple.size() == 3:
				world.berries[Vector2i(int(triple[0]), int(triple[1]))] = int(triple[2])
	else:
		world.rebuild_berries()
	# Phase 9 — a drought in progress, and any fire still burning, carry
	# over a save (old saves have neither: no drought, no fire).
	world.drought_until_day = int(data.get("drought_until", 0))
	world.burning.clear()
	for item in data.get("burning", []):
		var triple: Array = item
		if triple.size() == 3:
			world.burning[Vector2i(int(triple[0]), int(triple[1]))] = int(triple[2])
	agents.clear_all()
	for item in data.get("agents", []):
		var d: Dictionary = item
		var kind := int(d.get("kind", 0))
		var pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		var na := SimAgent.new(kind, pos)
		na.hunger = float(d.get("hunger", 0.0))
		na.health = float(d.get("health", 100.0))
		na.age = float(d.get("age", 0.0))
		# Old saves have no lifespan — keep the fresh random one from
		# _init instead of inventing a value.
		if d.has("lifespan"):
			na.lifespan = float(d.get("lifespan", 0.0))
		# Old saves have no job — JOB_NONE, and the village hires them
		# at the next scan.
		na.job = int(d.get("job", -1))
		na.blessed = bool(d.get("blessed", false))
		na.sick = float(d.get("sick", 0.0))
		na.immune = bool(d.get("immune", false))
		# Phase 10 — a raider's war mark (old saves have none: at home).
		# The war itself is restored below, so the mark points at a
		# real war again instead of dangling.
		na.at_war = int(d.get("at_war", -1))
		# Phase 11 — a hero's name, trait and deed (old saves have
		# none: nobody was a hero yet).
		na.hero = bool(d.get("hero", false))
		na.hero_name = String(d.get("hero_name", ""))
		# Phase 12 — the trait is stored as "innate_trait" now (it was
		# "hero_trait" in Phase 11, "trait" briefly in Phase 12); old
		# saves fall back to either key.
		na.innate_trait = int(d.get("innate_trait", d.get("trait", d.get("hero_trait", -1))))
		na.hero_deed = String(d.get("hero_deed", ""))
		# Phase 12 — a family surname and generation (old saves have
		# none: they start a family of generation 1 with a random
		# surname, the same as a freshly spawned person).
		na.weapon_tier = int(d.get("weapon_tier", 0))
		na.armor_tier = int(d.get("armor_tier", 0))
		na.tool_tier = int(d.get("tool_tier", 0))
		na.surname = String(d.get("surname", ""))
		if na.surname == "" and kind == SimAgent.Kind.PERSON:
			na.surname = SimAgent.SURNAMES[randi() % SimAgent.SURNAMES.size()]
		na.generation = int(d.get("generation", 1))
		agents.agents.append(na)
	villages.clear_all()
	for item in data.get("villages", []):
		var d: Dictionary = item
		# Old saves have no colour — derive it from the founding order,
		# the same way new villages pick theirs.
		var col: Color = Villages.VILLAGE_COLORS[villages.villages.size() % Villages.VILLAGE_COLORS.size()]
		var saved_color := String(d.get("color", ""))
		if saved_color != "":
			col = Color.html(saved_color)
		var nv: Villages.VillageData = Villages.VillageData.new(
			String(d.get("name", "Village")),
			Vector2i(int(d.get("x", 0)), int(d.get("y", 0))),
			int(d.get("day", 1)),
			col
		)
		# Old saves have no stockpiles — they start empty, with no
		# extra houses: the village rebuilds its builder houses as
		# woodcutters bring timber in.
		nv.food = float(d.get("food", 0.0))
		nv.wood = float(d.get("wood", 0.0))
		nv.stone = float(d.get("stone", 0.0))
		nv.iron = float(d.get("iron", 0.0))
		nv.marble = float(d.get("marble", 0.0))
		nv.steel = float(d.get("steel", 0.0))
		nv.extra_houses_built = int(d.get("extra_houses", 0))
		nv.blessed_until_day = int(d.get("blessed_until", 0))
		# Phase 10 — the day its last war ended (old saves have none:
		# it has never been at war, so it may raid at once).
		nv.last_war_day = int(d.get("last_war", 0))
		# Phase 17 — the kingdom it belongs to (old saves have none:
		# -1, independent — Towns found kingdoms on the next tick).
		nv.kingdom = int(d.get("kingdom", -1))
		villages.villages.append(nv)
	# Phase 10 — a war in progress carries over a save (old saves have
	# none: no wars). Restored after the agents, so the raiders' war
	# marks point at a real war. Skipped when the caller did not pass
	# a Wars node (older tests) — those worlds simply have no wars.
	if wars != null:
		wars.from_data(data.get("wars", []))
	# Phase 13 — goals (old saves have none: they start in the Stone
	# Age with no achievements and a fresh scenario).
	# Phase 17 — kingdoms (old saves have none: they start empty
	# and Towns found kingdoms on the next tick). Restored after the
	# villages, so the kingdom members point at real villages.
	if kingdoms != null:
		kingdoms.from_data(data.get("kingdoms", []))
	if goals != null:
		var gd: Dictionary = data.get("goals", {})
		goals.era = int(gd.get("era", 0))
		goals.winters_survived = int(gd.get("winters", 0))
		goals.wars_won = int(gd.get("wars_won", 0))
		goals.achievements = gd.get("achievements", {})
		goals.scenario_state = int(gd.get("scenario_state", 0))
		goals.scenario_reason = String(gd.get("scenario_reason", ""))
	event_log.from_data(data.get("log", []))
	world.queue_redraw()
	agents.queue_redraw()
	villages.queue_redraw()
	return true
