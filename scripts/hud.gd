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
signal banner_dismissed
## The Inspect panel's Close button was tapped; Main clears the
## selection (and the white ring) when this fires.
signal inspect_closed

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
const TOOL_BLESS_PERSON := "bless_person"
const TOOL_BLESS_VILLAGE := "bless_village"
const TOOL_FERTILE_RAIN := "fertile_rain"
const TOOL_DISASTER := "disaster"
const TOOL_INSPECT := "inspect"

var current_tool: String = TOOL_PAINT_GRASS
var brush_wide: bool = false

@onready var _day_label: Label = $TopBar/Margin/HBox/DayLabel
@onready var _season_label: Label = $TopBar/Margin/HBox/SeasonLabel
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
@onready var _goal_label: Label = $GoalPanel/Margin/GoalLabel
@onready var _banner_panel: PanelContainer = $BannerPanel
@onready var _banner_title: Label = $BannerPanel/Margin/VBox/BannerTitle
@onready var _banner_message: Label = $BannerPanel/Margin/VBox/BannerMessage
@onready var _inspect_panel: PanelContainer = $InspectPanel
@onready var _inspect_title: Label = $InspectPanel/Margin/VBox/InspectTitle
@onready var _inspect_body: Label = $InspectPanel/Margin/VBox/InspectBody

## The history panel sits top-left, below the stats bar. Collapsed it
## shows just the latest event; expanded it scrolls the whole log.
const LOG_COLLAPSED_BOTTOM := 140.0
const LOG_EXPANDED_BOTTOM := 496.0

var log_expanded := false

var _tool_buttons := {}
var _tool_powers := {}
var _last_cooldown_state := {}

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
		TOOL_BLESS_PERSON: $BottomBar/Margin/ToolGrid/ToolBlessPerson,
		TOOL_BLESS_VILLAGE: $BottomBar/Margin/ToolGrid/ToolBlessVillage,
		TOOL_FERTILE_RAIN: $BottomBar/Margin/ToolGrid/ToolFertileRain,
		TOOL_DISASTER: $BottomBar/Margin/ToolGrid/ToolDisaster,
		TOOL_INSPECT: $BottomBar/Margin/ToolGrid/ToolInspect,
	}
	# Which Power enum each blessing tool maps to, for the cooldown
	# display (update_cooldowns greys a button out while it recharges).
	_tool_powers = {
		TOOL_BLESS_PERSON: Powers.Power.BLESS_PERSON,
		TOOL_BLESS_VILLAGE: Powers.Power.BLESS_VILLAGE,
		TOOL_FERTILE_RAIN: Powers.Power.FERTILE_RAIN,
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
	$BannerPanel/Margin/VBox/BannerButton.pressed.connect(_on_banner_button_pressed)
	$InspectPanel/Margin/VBox/InspectClose.pressed.connect(_on_inspect_close_pressed)
	_select_tool(TOOL_PAINT_GRASS)

func update_stats(day: int, season_name: String, people: int, villages: int, animals: int) -> void:
	_day_label.text = "Day %d" % day
	_season_label.text = season_name
	_people_label.text = "People %d" % people
	_villages_label.text = "Villages %d" % villages
	_animals_label.text = "Animals %d" % animals

## Phase 13 — the goal line: the next achievement to chase (or the
## next era, once all nine are unlocked). Phase 18 — no scenario, no
## ending. The era name rides along so the player always knows which
## age they are in.
func update_goal(text: String, era_name: String) -> void:
	_goal_label.text = "%s · %s Age" % [text, era_name]

## Phase 13 — show the victory/defeat banner (the game pauses while
## it is up; Continue dismisses it and play resumes).
func show_banner(title: String, message: String) -> void:
	_banner_title.text = title
	_banner_message.text = message
	_banner_panel.visible = true

func hide_banner() -> void:
	_banner_panel.visible = false

## Show the Inspect panel for a person: the title names them, the
## body carries their stats, their items and their heritage.
func show_inspect(title: String, body: String) -> void:
	_inspect_title.text = title
	_inspect_body.text = body
	_inspect_panel.visible = true

func hide_inspect() -> void:
	_inspect_panel.visible = false

func _on_inspect_close_pressed() -> void:
	hide_inspect()
	inspect_closed.emit()

func _on_banner_button_pressed() -> void:
	hide_banner()
	banner_dismissed.emit()

func set_paused(is_paused: bool) -> void:
	_pause_button.text = "Play" if is_paused else "Pause"

func set_speed(multiplier: int) -> void:
	_speed_button.text = "%dx" % multiplier

func set_hint(text: String) -> void:
	_hint_label.text = text

## Grey out a blessing's button while it recharges (and light it back
## up when ready). Only touches a button when its state actually
## changed, so this can run every tick without flicker.
## Grey the Disaster button out while it recharges (10 days after the
## player unleashes one). Change-only, like update_cooldowns — the
## button is only touched when its state actually changes.
func update_disaster_button(on_cooldown: bool) -> void:
	if _last_cooldown_state.get(TOOL_DISASTER, false) == on_cooldown:
		return
	_last_cooldown_state[TOOL_DISASTER] = on_cooldown
	var button: Button = _tool_buttons[TOOL_DISASTER]
	button.disabled = on_cooldown

func update_cooldowns(cooldowns: Dictionary) -> void:
	for tool in _tool_powers:
		var power: int = _tool_powers[tool]
		var on_cooldown := int(cooldowns.get(power, 0)) > 0
		if _last_cooldown_state.get(tool, false) == on_cooldown:
			continue
		_last_cooldown_state[tool] = on_cooldown
		var button: Button = _tool_buttons[tool]
		button.disabled = on_cooldown

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
