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
