extends Node2D

## Game controller: owns the world, agents, villages, powers, and save
## system; runs the tick simulation; translates touch/mouse input into
## painting, spawning, and powers; drives the camera.
##
## Input rules (kept simple on purpose):
## - one finger / left mouse: use the selected tool (paint, spawn, power)
## - two fingers: drag to pan, pinch to zoom
## - right/middle mouse drag: pan, mouse wheel: zoom
## - Space: pause, F: fit the whole world on screen

const TICK_INTERVAL := 0.25   # seconds per tick at 1x speed
const TICKS_PER_DAY := 120    # a day lasts 120 ticks (30s at 1x)
const SPEEDS := [1, 2, 4]
const MIN_ZOOM := 0.2
const MAX_ZOOM := 2.5
const HUD_RESERVE_PX := 200.0  # top bar + bottom toolbar, kept out of "fit"

var paused := false
var speed_index := 0
var current_tool: String = Hud.TOOL_PAINT_GRASS
var brush_wide := false

var day := 1
var total_ticks := 0

## The world's history — one EventLog for the whole game, created here
## so it exists before _ready wires everything up.
var event_log := EventLog.new()

var _tick_acc := 0.0
var _painting := false
var _touches := {}  # touch index -> last screen position (Vector2)
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _pan_last_mid := Vector2.ZERO
var _panning_mouse := false
var _last_paint_tile := Vector2i(-1, -1)

@onready var world: GodSimWorld = $World
@onready var agents: Agents = $Agents
@onready var villages: Villages = $Villages
@onready var powers: Powers = $Powers
@onready var save_system: SaveSystem = $SaveSystem
@onready var camera: Camera2D = $Camera2D
@onready var hud: Hud = $HUD

func _ready() -> void:
	# Wire the nodes together (each one keeps a reference to what it needs).
	agents.world = world
	agents.villages = villages
	villages.world = world
	villages.agents = agents
	powers.world = world
	powers.agents = agents
	# History: villages and births report through signals; Main stamps
	# the day and writes them into the log, and the HUD redraws.
	agents.child_born.connect(_on_child_born)
	agents.starved.connect(_on_starved)
	villages.village_founded.connect(_on_village_founded)
	villages.people_joined.connect(_on_people_joined)
	event_log.changed.connect(_on_log_changed)
	hud.tool_selected.connect(_on_tool_selected)
	hud.brush_changed.connect(_on_brush_changed)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.speed_pressed.connect(_on_speed_pressed)
	hud.save_pressed.connect(_on_save_pressed)
	hud.new_world_pressed.connect(_on_new_world_pressed)
	hud.zoom_in_pressed.connect(func() -> void: _zoom_by(1.25))
	hud.zoom_out_pressed.connect(func() -> void: _zoom_by(0.8))
	hud.zoom_fit_pressed.connect(_fit_camera)
	if save_system.save_exists():
		var data := save_system.load_game()
		if save_system.apply_save(data, world, agents, villages, event_log):
			day = int(data.get("day", 1))
			total_ticks = int(data.get("ticks", 0))
			hud.set_hint("World loaded — welcome back!")
		else:
			_new_world()
	else:
		_new_world()
	_fit_camera()
	_update_hud()
	hud.update_log(event_log.entries)

func _new_world() -> void:
	world.generate_new()
	agents.clear_all()
	villages.clear_all()
	day = 1
	total_ticks = 0
	event_log.clear()
	event_log.add(1, "A new world began")
	# Starter life so the world feels alive right away.
	agents.spawn_scattered(SimAgent.Kind.PERSON, 10)
	agents.spawn_scattered(SimAgent.Kind.SHEEP, 8)
	_save_quietly()
	_update_hud()
	hud.set_hint("New world! Paint terrain, then spawn people.")

func _save_quietly() -> void:
	save_system.save_game(world, agents, villages, event_log, day, total_ticks)


# --- simulation ------------------------------------------------------------

func _process(delta: float) -> void:
	if paused:
		return
	# The accumulator makes ticks happen at a steady rate no matter the
	# frame rate; speed just makes the accumulator fill faster.
	_tick_acc += delta * SPEEDS[speed_index]
	while _tick_acc >= TICK_INTERVAL:
		_tick_acc -= TICK_INTERVAL
		_do_tick()

func _do_tick() -> void:
	total_ticks += 1
	day = 1 + total_ticks / TICKS_PER_DAY
	world.tick()  # berries regrow
	agents.tick(TICK_INTERVAL)
	villages.tick(day)
	if total_ticks % 40 == 0:
		_save_quietly()  # autosave every 40 ticks (~10s at 1x)
	_update_hud()

func _update_hud() -> void:
	hud.update_stats(day, agents.count_people(), villages.count(), agents.count_animals())


# --- camera ----------------------------------------------------------------

func _fit_camera() -> void:
	# Measure the visible area at zoom 1 first — get_visible_rect() already
	# includes the current zoom, so reset it before measuring.
	camera.zoom = Vector2.ONE
	camera.position = Vector2(
		GodSimWorld.WIDTH * GodSimWorld.TILE * 0.5,
		GodSimWorld.HEIGHT * GodSimWorld.TILE * 0.5
	)
	await get_tree().process_frame
	var view := get_viewport().get_visible_rect().size
	var usable := Vector2(view.x, view.y - HUD_RESERVE_PX)
	var zx := usable.x / (GodSimWorld.WIDTH * GodSimWorld.TILE)
	var zy := usable.y / (GodSimWorld.HEIGHT * GodSimWorld.TILE)
	var z := clampf(minf(zx, zy) * 0.98, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)
	_clamp_camera()

func _zoom_by(factor: float) -> void:
	var new_zoom := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(new_zoom, new_zoom)
	_clamp_camera()

func _pan_camera_by(delta_world: Vector2) -> void:
	camera.position += delta_world
	_clamp_camera()

func _clamp_camera() -> void:
	var view := get_viewport().get_visible_rect().size
	var world_size := Vector2(
		GodSimWorld.WIDTH * GodSimWorld.TILE,
		GodSimWorld.HEIGHT * GodSimWorld.TILE
	)
	# If the view is wider than the world, keep the world centred instead
	# of clamping to a range that no longer makes sense.
	if view.x >= world_size.x:
		camera.position.x = world_size.x * 0.5
	else:
		camera.position.x = clampf(
			camera.position.x, view.x * 0.5 - 80.0, world_size.x - view.x * 0.5 + 80.0
		)
	if view.y >= world_size.y:
		camera.position.y = world_size.y * 0.5
	else:
		camera.position.y = clampf(
			camera.position.y, view.y * 0.5 - 80.0, world_size.y - view.y * 0.5 + 80.0
		)


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input only fires when no UI control consumed the event,
	# so taps on buttons never reach the game.
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_SPACE:
				_on_pause_pressed()
			KEY_F:
				_fit_camera()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_painting = true
			_apply_tool_at_screen(event.position, true)
		elif _touches.size() == 2:
			# Second finger down: stop painting, start pinch/pan.
			_painting = false
			_pinch_start_dist = _touch_distance()
			_pinch_start_zoom = camera.zoom.x
			_pan_last_mid = _touch_midpoint()
	else:
		_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch_start_dist = 0.0
		if _touches.is_empty():
			_painting = false
			_last_paint_tile = Vector2i(-1, -1)

func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 1 and _painting:
		_apply_tool_along_screen(event.position)
	elif _touches.size() == 2:
		var mid := _touch_midpoint()
		# Pan by the movement of the midpoint (world follows the fingers).
		var delta := mid - _pan_last_mid
		_pan_last_mid = mid
		_pan_camera_by(-delta / camera.zoom.x)
		# Pinch to zoom, anchored to the zoom when the pinch started.
		var dist := _touch_distance()
		if _pinch_start_dist > 0.0 and dist > 0.0:
			var new_zoom := clampf(_pinch_start_zoom * (dist / _pinch_start_dist), MIN_ZOOM, MAX_ZOOM)
			camera.zoom = Vector2(new_zoom, new_zoom)
		_clamp_camera()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_by(1.15)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_by(0.87)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_painting = true
				_apply_tool_at_screen(event.position, true)
			else:
				_painting = false
				_last_paint_tile = Vector2i(-1, -1)
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_panning_mouse = event.pressed

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _painting:
		_apply_tool_along_screen(event.position)
	if _panning_mouse:
		_pan_camera_by(-event.relative / camera.zoom.x)
		_clamp_camera()

func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	return a.distance_to(b)

func _touch_midpoint() -> Vector2:
	var points := _touches.values()
	var mid := Vector2.ZERO
	for p in points:
		var pv: Vector2 = p
		mid += pv
	return mid / maxf(1.0, float(points.size()))


# --- tools -----------------------------------------------------------------

## Convert a screen position (touch/mouse) to a map tile. The canvas
## transform already includes the camera, so inverting it gives the
## world position under the finger/cursor.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var canvas_xform := get_viewport().get_canvas_transform()
	var world_pos: Vector2 = canvas_xform.affine_inverse() * screen_pos
	return world.world_to_tile(world_pos)

func _apply_tool_at_screen(screen_pos: Vector2, is_start: bool) -> void:
	var tile := _screen_to_tile(screen_pos)
	if not world.in_bounds(tile.x, tile.y):
		return
	match current_tool:
		Hud.TOOL_PAINT_GRASS, Hud.TOOL_PAINT_WATER, Hud.TOOL_PAINT_FOREST, Hud.TOOL_PAINT_MOUNTAIN:
			_paint_terrain(tile, _tool_terrain())
		Hud.TOOL_SPAWN_PERSON:
			if is_start:
				agents.spawn(SimAgent.Kind.PERSON, tile)
				_update_hud()
		Hud.TOOL_SPAWN_SHEEP:
			if is_start:
				agents.spawn(SimAgent.Kind.SHEEP, tile)
				_update_hud()
		Hud.TOOL_RAIN, Hud.TOOL_LIGHTNING, Hud.TOOL_METEOR:
			# Powers only log on the press, not on drags — a rain drag
			# paints dozens of tiles and would flood the log.
			var killed := powers.apply_power(_tool_power(), tile)
			if is_start:
				_log_power(current_tool, killed)
			_update_hud()

## One log line for a power the player just used.
func _log_power(tool: String, killed: int) -> void:
	match tool:
		Hud.TOOL_RAIN:
			event_log.add(day, "Rain fell on the land")
		Hud.TOOL_LIGHTNING:
			if killed > 0:
				event_log.add(day, "Lightning struck, killing %d" % killed)
			else:
				event_log.add(day, "Lightning struck the ground")
		Hud.TOOL_METEOR:
			if killed > 0:
				event_log.add(day, "A meteor crashed down, killing %d" % killed)
			else:
				event_log.add(day, "A meteor crashed down, leaving a crater")

func _on_child_born(village_name: String) -> void:
	event_log.add_birth(day, village_name)

func _on_starved(village_name: String) -> void:
	event_log.add_starvation_death(day, village_name)

func _on_village_founded(village_name: String) -> void:
	event_log.add(day, "%s was founded" % village_name)

func _on_people_joined(village_name: String, count: int) -> void:
	if count == 1:
		event_log.add(day, "1 person joined %s" % village_name)
	else:
		event_log.add(day, "%d people joined %s" % [count, village_name])

func _on_log_changed() -> void:
	hud.update_log(event_log.entries)

func _apply_tool_along_screen(screen_pos: Vector2) -> void:
	# Dragging: interpolate tiles between the last painted tile and this
	# one so fast swipes don't leave gaps. Only paint and rain make
	# sense while dragging; spawn/lightning/meteor fire once, on press.
	var tile := _screen_to_tile(screen_pos)
	if not world.in_bounds(tile.x, tile.y):
		return
	var from := _last_paint_tile
	if from.x < 0:
		_apply_tool_at_screen(screen_pos, false)
		_last_paint_tile = tile
		return
	var steps := maxi(int(from.distance_to(Vector2(tile))), 1)
	for i in range(steps + 1):
		var t := Vector2(from).lerp(Vector2(tile), float(i) / steps)
		var tt := Vector2i(int(t.x), int(t.y))
		if world.in_bounds(tt.x, tt.y):
			if current_tool.begins_with("paint_"):
				_paint_terrain(tt, _tool_terrain())
			elif current_tool == Hud.TOOL_RAIN:
				powers.apply_power(Powers.Power.RAIN, tt)
	_last_paint_tile = tile

func _paint_terrain(tile: Vector2i, terrain_type: int) -> void:
	if brush_wide:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				world.set_terrain(tile.x + dx, tile.y + dy, terrain_type)
	else:
		world.set_terrain(tile.x, tile.y, terrain_type)
	world.queue_redraw()

func _tool_terrain() -> int:
	match current_tool:
		Hud.TOOL_PAINT_WATER:
			return GodSimWorld.Terrain.WATER
		Hud.TOOL_PAINT_FOREST:
			return GodSimWorld.Terrain.FOREST
		Hud.TOOL_PAINT_MOUNTAIN:
			return GodSimWorld.Terrain.MOUNTAIN
		_:
			return GodSimWorld.Terrain.GRASS

func _tool_power() -> int:
	match current_tool:
		Hud.TOOL_LIGHTNING:
			return Powers.Power.LIGHTNING
		Hud.TOOL_METEOR:
			return Powers.Power.METEOR
		_:
			return Powers.Power.RAIN


# --- HUD callbacks ---------------------------------------------------------

func _on_tool_selected(tool: String) -> void:
	current_tool = tool
	hud.set_hint(_hint_for_tool(tool))

func _on_brush_changed(wide: bool) -> void:
	brush_wide = wide

func _on_pause_pressed() -> void:
	paused = not paused
	hud.set_paused(paused)

func _on_speed_pressed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	hud.set_speed(SPEEDS[speed_index])

func _on_save_pressed() -> void:
	if save_system.save_game(world, agents, villages, event_log, day, total_ticks):
		hud.set_hint("World saved.")
	else:
		hud.set_hint("Save failed!")

func _on_new_world_pressed() -> void:
	_new_world()

func _hint_for_tool(tool: String) -> String:
	match tool:
		Hud.TOOL_PAINT_GRASS:
			return "Paint grass — drag to terraform."
		Hud.TOOL_PAINT_WATER:
			return "Paint water — lakes block creatures."
		Hud.TOOL_PAINT_FOREST:
			return "Paint forest — creatures love it."
		Hud.TOOL_PAINT_MOUNTAIN:
			return "Paint mountains — nothing walks over them."
		Hud.TOOL_SPAWN_PERSON:
			return "Tap to place a person. They wander and breed."
		Hud.TOOL_SPAWN_SHEEP:
			return "Tap to place a sheep."
		Hud.TOOL_RAIN:
			return "Rain — heals scorched land, grows forest."
		Hud.TOOL_LIGHTNING:
			return "Lightning — smites creatures, scorches trees."
		Hud.TOOL_METEOR:
			return "Meteor — leaves a crater. Use responsibly."
		_:
			return ""
