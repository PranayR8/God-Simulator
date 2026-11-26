class_name Hud
extends CanvasLayer

## The phone UI: top stats bar, bottom tool toolbar, sim controls.
##
## The HUD never touches the game directly — it only emits signals, and
## Main (main.gd) does the work. Keeping UI and game logic separate makes
## both easier to change later.

signal tool_selected(tool: String)
signal brush_changed(wide: bool)
signal pause_pressed
signal speed_pressed
signal save_pressed
signal new_world_pressed
signal zoom_in_pressed
signal zoom_out_pressed
signal zoom_fit_pressed

# Tool ids — Main matches on these strings.
const TOOL_PAINT_GRASS := "paint_grass"
const TOOL_PAINT_WATER := "paint_water"
const TOOL_PAINT_FOREST := "paint_forest"
const TOOL_PAINT_MOUNTAIN := "paint_mountain"
const TOOL_SPAWN_PERSON := "spawn_person"
const TOOL_SPAWN_SHEEP := "spawn_sheep"
const TOOL_RAIN := "rain"
const TOOL_LIGHTNING := "lightning"
const TOOL_METEOR := "meteor"

var current_tool: String = TOOL_PAINT_GRASS
var brush_wide: bool = false

@onready var _day_label: Label = $TopBar/Margin/HBox/DayLabel
@onready var _people_label: Label = $TopBar/Margin/HBox/PeopleLabel
@onready var _villages_label: Label = $TopBar/Margin/HBox/VillagesLabel
@onready var _animals_label: Label = $TopBar/Margin/HBox/AnimalsLabel
@onready var _pause_button: Button = $TopBar/Margin/HBox/PauseButton
@onready var _speed_button: Button = $TopBar/Margin/HBox/SpeedButton
@onready var _hint_label: Label = $HintLabel
@onready var _log_panel: PanelContainer = $LogPanel
@onready var _log_toggle: Button = $LogPanel/Margin/VBox/HeaderRow/LogToggle
@onready var _log_latest: Label = $LogPanel/Margin/VBox/LogLatest
@onready var _log_scroll: ScrollContainer = $LogPanel/Margin/VBox/LogScroll
@onready var _log_entries: Label = $LogPanel/Margin/VBox/LogScroll/LogEntries

## The history panel sits top-left, below the stats bar. Collapsed it
## shows just the latest event; expanded it scrolls the whole log.
const LOG_COLLAPSED_BOTTOM := 140.0
const LOG_EXPANDED_BOTTOM := 496.0

var log_expanded := false

var _tool_buttons := {}

func _ready() -> void:
	_tool_buttons = {
		TOOL_PAINT_GRASS: $BottomBar/Margin/ToolGrid/ToolGrass,
		TOOL_PAINT_WATER: $BottomBar/Margin/ToolGrid/ToolWater,
		TOOL_PAINT_FOREST: $BottomBar/Margin/ToolGrid/ToolForest,
		TOOL_PAINT_MOUNTAIN: $BottomBar/Margin/ToolGrid/ToolMountain,
		TOOL_SPAWN_PERSON: $BottomBar/Margin/ToolGrid/ToolPerson,
		TOOL_SPAWN_SHEEP: $BottomBar/Margin/ToolGrid/ToolSheep,
		TOOL_RAIN: $BottomBar/Margin/ToolGrid/ToolRain,
		TOOL_LIGHTNING: $BottomBar/Margin/ToolGrid/ToolLightning,
		TOOL_METEOR: $BottomBar/Margin/ToolGrid/ToolMeteor,
	}
	for tool in _tool_buttons:
		var button: Button = _tool_buttons[tool]
		button.pressed.connect(_on_tool_button_pressed.bind(tool))
	$BottomBar/Margin/ToolGrid/BrushButton.pressed.connect(_on_brush_button_pressed)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	$TopBar/Margin/HBox/SaveButton.pressed.connect(func() -> void: save_pressed.emit())
	$TopBar/Margin/HBox/NewButton.pressed.connect(func() -> void: new_world_pressed.emit())
	$ZoomBox/ZoomInButton.pressed.connect(func() -> void: zoom_in_pressed.emit())
	$ZoomBox/ZoomOutButton.pressed.connect(func() -> void: zoom_out_pressed.emit())
	$ZoomBox/ZoomFitButton.pressed.connect(func() -> void: zoom_fit_pressed.emit())
	_log_toggle.pressed.connect(_on_log_toggle_pressed)
	_select_tool(TOOL_PAINT_GRASS)

func update_stats(day: int, people: int, villages: int, animals: int) -> void:
	_day_label.text = "Day %d" % day
	_people_label.text = "People %d" % people
	_villages_label.text = "Villages %d" % villages
	_animals_label.text = "Animals %d" % animals

func set_paused(is_paused: bool) -> void:
	_pause_button.text = "Play" if is_paused else "Pause"

func set_speed(multiplier: int) -> void:
	_speed_button.text = "%dx" % multiplier

func set_hint(text: String) -> void:
	_hint_label.text = text

## Redraw the history panel from the log's entries (dictionaries with
## "day" and "text"). Newest entry first; the collapsed one-liner shows
## only the latest.
func update_log(entries: Array) -> void:
	if entries.is_empty():
		_log_latest.text = "No events yet — the story starts soon."
		_log_entries.text = ""
		return
	var newest: Dictionary = entries[entries.size() - 1]
	_log_latest.text = "Day %d — %s" % [int(newest.get("day", 1)), String(newest.get("text", ""))]
	var lines: Array[String] = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		lines.append("Day %d — %s" % [int(e.get("day", 1)), String(e.get("text", ""))])
	_log_entries.text = "\n".join(lines)

func _on_log_toggle_pressed() -> void:
	log_expanded = not log_expanded
	_log_scroll.visible = log_expanded
	_log_latest.visible = not log_expanded
	_log_panel.offset_bottom = LOG_EXPANDED_BOTTOM if log_expanded else LOG_COLLAPSED_BOTTOM
	_log_toggle.text = "Hide" if log_expanded else "Show"

func _on_tool_button_pressed(tool: String) -> void:
	_select_tool(tool)

func _on_brush_button_pressed() -> void:
	brush_wide = not brush_wide
	var button: Button = $BottomBar/Margin/ToolGrid/BrushButton
	button.text = "Brush: Wide" if brush_wide else "Brush: Fine"
	brush_changed.emit(brush_wide)

func _select_tool(tool: String) -> void:
	current_tool = tool
	for key in _tool_buttons:
		var button: Button = _tool_buttons[key]
		# Highlight the active tool with a warm tint.
		button.modulate = Color(1.0, 0.85, 0.45) if key == tool else Color.WHITE
	tool_selected.emit(tool)
