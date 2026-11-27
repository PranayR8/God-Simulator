class_name Goals
extends Node

## Phase 13 — goals, eras & achievements.
##
## Eras: Stone -> Bronze -> Iron -> Classical -> Medieval, each
## unlocked by mining a new material (stone, iron, marble, steel).
## The era is a progression marker — the log announces each one, so
## the player gets a clear "you did it" moment — and the houses
## redraw in the era's style, so the age is visible on the map.
##
## Achievements: a checklist of nine things to do. Each one unlocks
## once, the first time its condition is true, and the log names it.
##
## Phase 18 — there is no ending. The game is an endless god
## simulator: the 100-day scenario (grow a village to 100 citizens
## before Day 100, with a win/loss banner that paused the game) is
## gone. The HUD's goal line now points at the next achievement to
## chase, so there is always something to aim for and never a reason
## to stop.
##
## Goals never touches the game directly — Main calls tick(day) every
## tick and connects the signals to the log and the banner.

## Phase 15 — five eras, and they advance on what the villages have
## mined: stone -> Bronze, iron -> Iron, marble -> Classical, steel ->
## Medieval. The old milestone eras (first City, 100 citizens, 10
## winters + a war) are achievements now, not era gates — the age
## advances because your people learned to use a new material, not
## because a counter ticked over.
const ERA_NAMES := ["Stone", "Bronze", "Iron", "Classical", "Medieval"]

const ACHIEVEMENTS := [
	{"id": "first_village", "name": "First Village", "desc": "Found your first village."},
	{"id": "five_villages", "name": "Five Villages", "desc": "Have 5 villages at once."},
	{"id": "raise_city", "name": "Raise a City", "desc": "Grow a village to City stage."},
	{"id": "first_hero", "name": "First Hero", "desc": "A hero rises."},
	{"id": "third_generation", "name": "Third Generation", "desc": "A house reaches its 3rd generation."},
	{"id": "win_war", "name": "Win a War", "desc": "A village wins a war."},
	{"id": "save_village", "name": "Save a Village", "desc": "A village survives a plague."},
	{"id": "hundred_citizens", "name": "100 Citizens", "desc": "Reach 100 people."},
	{"id": "ten_winters", "name": "Ten Winters", "desc": "Survive ten winters."},
]

signal era_changed(era_name: String)
signal achievement_unlocked(achievement_id: String, achievement_name: String)

var era: int = 0
var winters_survived: int = 0
var wars_won: int = 0
var achievements: Dictionary = {}

var agents: Agents = null
var villages: Villages = null

var _last_season: int = -1
var _was_plague: bool = false
var _had_people: bool = false

## Reset everything (a new world starts in the Stone Age with no
## achievements).
func clear_all() -> void:
	era = 0
	winters_survived = 0
	wars_won = 0
	achievements = {}
	_last_season = -1
	_was_plague = false
	_had_people = false

func tick(day: int) -> void:
	if agents == null or villages == null:
		return
	# A winter is survived when Winter turns to Spring.
	var season := GodSimWorld.season_index_for_day(day)
	if _last_season == GodSimWorld.SEASON_WINTER and season == GodSimWorld.SEASON_SPRING:
		winters_survived += 1
	_last_season = season
	# A plague is survived when it ends (nobody sick anymore) and
	# people are still alive to tell it.
	var plague_now := agents.count_sick() > 0
	if _was_plague and not plague_now and agents.count_people() > 0:
		_unlock("save_village")
	_was_plague = plague_now
	if agents.count_people() > 0:
		_had_people = true
	_check_eras()
	_check_achievements()

func _check_eras() -> void:
	# Each era unlocks when ANY village first stockpiles its resource.
	# A village that mines stone moves the whole world into Bronze;
	# iron into Iron; marble into Classical; steel into Medieval.
	if era == 0 and _any_village_has("stone"):
		era = 1
		era_changed.emit(ERA_NAMES[era])
	if era == 1 and _any_village_has("iron"):
		era = 2
		era_changed.emit(ERA_NAMES[era])
	if era == 2 and _any_village_has("marble"):
		era = 3
		era_changed.emit(ERA_NAMES[era])
	if era == 3 and _any_village_has("steel"):
		era = 4
		era_changed.emit(ERA_NAMES[era])

## Does any village have at least one unit of this mined resource?
func _any_village_has(resource: String) -> bool:
	for v in villages.villages:
		match resource:
			"stone":
				if v.stone >= 1.0:
					return true
			"iron":
				if v.iron >= 1.0:
					return true
			"marble":
				if v.marble >= 1.0:
					return true
			"steel":
				if v.steel >= 1.0:
					return true
	return false

func _check_achievements() -> void:
	var people := agents.count_people()
	if villages.count() >= 1:
		_unlock("first_village")
	if villages.count() >= 5:
		_unlock("five_villages")
	for v in villages.villages:
		if villages.stage_of(v) >= 3:
			_unlock("raise_city")
			break
	for a in agents.agents:
		if a.hero:
			_unlock("first_hero")
			break
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.generation >= 3:
			_unlock("third_generation")
			break
	if wars_won >= 1:
		_unlock("win_war")
	if people >= 100:
		_unlock("hundred_citizens")
	if winters_survived >= 10:
		_unlock("ten_winters")

func _unlock(achievement_id: String) -> void:
	if bool(achievements.get(achievement_id, false)):
		return
	achievements[achievement_id] = true
	var achievement_name := achievement_id
	for def in ACHIEVEMENTS:
		if String(def.get("id", "")) == achievement_id:
			achievement_name = String(def.get("name", achievement_id))
			break
	achievement_unlocked.emit(achievement_id, achievement_name)

## A war ended with a winner (called from Main when Wars reports one).
func note_war_won(_winner_name: String) -> void:
	wars_won += 1

## The current era's name (for the HUD's goal line).
func era_name() -> String:
	return ERA_NAMES[clampi(era, 0, ERA_NAMES.size() - 1)]

## The largest village's population (the HUD's progress number).
func largest_village_pop() -> int:
	var best := 0
	for v in villages.villages:
		best = maxi(best, villages.population_of(v))
	return best

## The goal line for the HUD. There is no ending, so it points at
## the next achievement to chase (with how many are done), and once
## all nine are unlocked it points at the next era instead.
func goal_text() -> String:
	var done := 0
	for def in ACHIEVEMENTS:
		if bool(achievements.get(String(def.get("id", "")), false)):
			done += 1
	for def in ACHIEVEMENTS:
		if not bool(achievements.get(String(def.get("id", "")), false)):
			return "Next: %s · %d/9 achievements" % [String(def.get("name", "")), done]
	return next_era_text()

## What the next era needs (shown once all nine achievements are
## unlocked).
func next_era_text() -> String:
	match era:
		0:
			return "Next era: Bronze — mine stone."
		1:
			return "Next era: Iron — mine iron."
		2:
			return "Next era: Classical — mine marble."
		3:
			return "Next era: Medieval — mine steel."
		_:
			return "Medieval era — build as you like."
