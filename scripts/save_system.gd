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

func save_game(world: GodSimWorld, agents: Agents, villages: Villages, event_log: EventLog, day: int, ticks: int) -> bool:
	var data := {
		"version": 3,
		"seed": world.seed_value,
		"day": day,
		"ticks": ticks,
		"terrain": world.terrain,
		"berries": _berries_to_data(world),
		"agents": _agents_to_data(agents),
		"villages": _villages_to_data(villages),
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
		out.append({"kind": a.kind, "x": a.pos.x, "y": a.pos.y, "hunger": a.hunger, "health": a.health, "age": a.age, "lifespan": a.lifespan})
	return out

## Berries as a flat list of [x, y, count] triples (only tiles that
## have any berries are stored).
func _berries_to_data(world: GodSimWorld) -> Array:
	var out: Array = []
	for tile in world.berries.keys():
		var t: Vector2i = tile
		out.append([t.x, t.y, int(world.berries[t])])
	return out

func _villages_to_data(villages: Villages) -> Array:
	var out: Array = []
	for v in villages.villages:
		out.append({"name": v.name, "x": v.tile.x, "y": v.tile.y, "day": v.founded_day, "color": v.color.to_html()})
	return out

## Rebuild the world from loaded data. Returns false if the data is empty
## or unusable (caller should generate a fresh world instead).
## Old saves have no "log" key — the history just starts empty — and
## no "berries" key — forests restock to full (see rebuild_berries).
func apply_save(data: Dictionary, world: GodSimWorld, agents: Agents, villages: Villages, event_log: EventLog) -> bool:
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
		villages.villages.append(Villages.VillageData.new(
			String(d.get("name", "Village")),
			Vector2i(int(d.get("x", 0)), int(d.get("y", 0))),
			int(d.get("day", 1)),
			col
		))
	event_log.from_data(data.get("log", []))
	world.queue_redraw()
	agents.queue_redraw()
	villages.queue_redraw()
	return true
