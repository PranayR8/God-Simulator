class_name EventLog
extends RefCounted

## The world's history: a dated list of what happened, newest last in
## storage, newest first on screen. Main owns one of these; the game
## systems report events through signals, Main stamps them with the
## current day, and the HUD redraws whenever `changed` fires.
##
## Births are aggregated: ten babies in one village on one day become a
## single line ("4 children were born in Wilwick") instead of ten lines,
## or births would drown out everything else. Everything else is one
## line per event. Only the last MAX_ENTRIES are kept.

const MAX_ENTRIES := 50

## One entry: {"day": int, "text": String, "kind": String,
##              "village": String, "count": int}.
## kind is "birth" for aggregated births, "event" for everything else.
var entries: Array = []

signal changed

func add(day: int, text: String) -> void:
	entries.append({
		"day": day, "text": text, "kind": "event",
		"village": "", "count": 1,
	})
	_trim()
	changed.emit()

## A birth in a village (village_name "" = nomad birth). If the most
## recent entry is already a birth summary for the same village on the
## same day, the count grows instead of a new line appearing.
func add_birth(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "birth" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _birth_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _birth_text(village_name, 1), "kind": "birth",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _birth_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A child was born" if count == 1 else "%d children were born" % count
	if count == 1:
		return "A child was born in %s" % village_name
	return "%d children were born in %s" % [count, village_name]

## A death by starvation (village_name "" = nomad). Aggregated like
## births: several deaths in one village on one day become one line,
## or a starving village would flood the log.
func add_starvation_death(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "starvation" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _starvation_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _starvation_text(village_name, 1), "kind": "starvation",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _starvation_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A nomad died of starvation" if count == 1 else "%d nomads died of starvation" % count
	if count == 1:
		return "A villager of %s died of starvation" % village_name
	return "%d villagers of %s died of starvation" % [count, village_name]

## A death by old age (village_name "" = nomad). Aggregated like
## births and starvation deaths: several elders dying in one village
## on one day become one line.
func add_old_age_death(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "old_age" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _old_age_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _old_age_text(village_name, 1), "kind": "old_age",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _old_age_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A nomad died of old age" if count == 1 else "%d nomads died of old age" % count
	if count == 1:
		return "An elder of %s died of old age" % village_name
	return "%d elders of %s died of old age" % [count, village_name]

## A death by winter cold (village_name "" = nomad). Aggregated like
## the other deaths: several freezing in one village on one day become
## one line, or a hard winter would flood the log.
func add_plague_death(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "plague" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _plague_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _plague_text(village_name, 1), "kind": "plague",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _plague_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A nomad died of plague" if count == 1 else "%d nomads died of plague" % count
	return "A villager of %s died of plague" % village_name if count == 1 else "%d villagers of %s died of plague" % [count, village_name]

func add_cold_death(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "cold" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _cold_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _cold_text(village_name, 1), "kind": "cold",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _cold_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A nomad froze to death" if count == 1 else "%d nomads froze to death" % count
	if count == 1:
		return "A villager of %s froze to death" % village_name
	return "%d villagers of %s froze to death" % [count, village_name]

## A death in battle (Phase 10, war). Aggregated like the other deaths:
## several falling in one village on one day become one line, or a hard
## battle would flood the log. village_name is the home village of the
## fallen (a raider who dies is counted to their own village).
func add_war_death(day: int, village_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "war" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _war_text(village_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _war_text(village_name, 1), "kind": "war",
		"village": village_name, "count": 1,
	})
	_trim()
	changed.emit()

func _war_text(village_name: String, count: int) -> String:
	if village_name == "":
		return "A nomad fell in battle" if count == 1 else "%d nomads fell in battle" % count
	if count == 1:
		return "A villager of %s fell in battle" % village_name
	return "%d villagers of %s fell in battle" % [count, village_name]

## A village reaching a new growth stage (or falling back down one):
## "Wilwick became a Town" / "Wilwick fell back to a Village". One
## line per change — stages move slowly, so this never floods the log.
func add_stage_change(day: int, village_name: String, stage_name: String, grew: bool) -> void:
	if grew:
		add(day, "%s became a %s" % [village_name, stage_name])
	else:
		add(day, "%s fell back to a %s" % [village_name, stage_name])

## A citizen took up a job (a village always has a name — nomads and
## children don't work). Aggregated like births: several hires of the
## same job in one village on one day become one line, or a growing
## village would flood the log.
func add_job(day: int, village_name: String, job_name: String) -> void:
	if not entries.is_empty():
		var last: Dictionary = entries[entries.size() - 1]
		if String(last.get("kind", "")) == "job" \
				and int(last.get("day", -1)) == day \
				and String(last.get("village", "")) == village_name \
				and String(last.get("job", "")) == job_name:
			var count := int(last.get("count", 1)) + 1
			last["count"] = count
			last["text"] = _job_text(village_name, job_name, count)
			changed.emit()
			return
	entries.append({
		"day": day, "text": _job_text(village_name, job_name, 1), "kind": "job",
		"village": village_name, "job": job_name, "count": 1,
	})
	_trim()
	changed.emit()

func _job_text(village_name: String, job_name: String, count: int) -> String:
	var plural := job_name.to_lower() + "s"
	if count == 1:
		return "A %s took up work in %s" % [job_name.to_lower(), village_name]
	return "%d %s took up work in %s" % [count, plural, village_name]

func _trim() -> void:
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()

func clear() -> void:
	entries.clear()
	changed.emit()

## The newest entry's text, for the collapsed one-line view.
func latest_text() -> String:
	if entries.is_empty():
		return "No events yet — the story starts soon."
	var last: Dictionary = entries[entries.size() - 1]
	return "Day %d — %s" % [int(last.get("day", 1)), String(last.get("text", ""))]

## One line per entry, newest first, for the expanded panel.
func full_text() -> String:
	var lines: Array[String] = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		lines.append("Day %d — %s" % [int(e.get("day", 1)), String(e.get("text", ""))])
	return "\n".join(lines)

## Save format: the entries array as-is (plain dictionaries, JSON-safe).
func to_data() -> Array:
	return entries.duplicate(true)

func from_data(data: Array) -> void:
	entries.clear()
	for item in data:
		if item is Dictionary:
			var e: Dictionary = item
			entries.append({
				"day": int(e.get("day", 1)),
				"text": String(e.get("text", "")),
				"kind": String(e.get("kind", "event")),
				"village": String(e.get("village", "")),
				"count": int(e.get("count", 1)),
			})
	_trim()
	changed.emit()
