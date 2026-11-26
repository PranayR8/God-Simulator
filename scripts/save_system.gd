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
		"version": 1,
		"seed": world.seed_value,
		"day": day,
		"ticks": ticks,
		"terrain": world.terrain,
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
		out.append({"kind": a.kind, "x": a.pos.x, "y": a.pos.y})
	return out

func _villages_to_data(villages: Villages) -> Array:
	var out: Array = []
	for v in villages.villages:
		out.append({"name": v.name, "x": v.tile.x, "y": v.tile.y, "day": v.founded_day, "color": v.color.to_html()})
	return out

## Rebuild the world from loaded data. Returns false if the data is empty
## or unusable (caller should generate a fresh world instead).
## Old saves have no "log" key — the history just starts empty.
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
	agents.clear_all()
	for item in data.get("agents", []):
		var d: Dictionary = item
		var kind := int(d.get("kind", 0))
		var pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		agents.agents.append(SimAgent.new(kind, pos))
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
