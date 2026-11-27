class_name Kingdoms
extends Node

## Phase 17 — kingdoms & diplomacy. Villages that grow into Towns do
## not stand alone any more: a Town founds a kingdom (or joins a
## nearby one), and the kingdom has a king, a capital, a colour and a
## name. Kingdoms fight, make peace, form alliances and lose villages
## to rebellion — the politics above the village.
##
## A kingdom is {name, color, capital, members}. A village belongs to
## at most one kingdom (its kingdom idx, -1 = independent, stored on
## VillageData). The king is the capital's oldest hero (or, when the
## capital has no hero, its oldest adult) — resolved on demand, so a
## king's death is a succession, not a dangling reference. The king's
## trait boosts every village in the kingdom, not just the capital.
##
## Relations between two kingdoms are one of peace / war / allied,
## stored per pair. A raid between kingdoms sets war. A war with no
## raid for 10 days becomes peace. Two neighbouring kingdoms at peace
## for 20 days become allies — and allies never raid each other. A
## member village that starves for 3 days rebels and leaves.

const KINGDOM_MIN_STAGE := 2        # a Town (30 citizens) can found or join
const JOIN_RANGE_TILES := 25.0      # join a kingdom this close, else found your own
const PEACE_DAYS := 10              # a war with no raid this long becomes peace
const ALLY_DAYS := 20               # neighbours at peace this long become allies
const ALLY_RANGE_TILES := 25.0      # neighbours this close can ally
const REBEL_HUNGRY_DAYS := 3        # starve this long and a member rebels
const REBEL_FOOD_PER_PERSON := 0.5  # below this food per citizen, a village is starving
const REBEL_JOIN_COOLDOWN_DAYS := 30  # a rebel may not rejoin a kingdom this long

## The kingdom colours — royal, distinct from the village palette.
const KINGDOM_COLORS := [
	Color("#8e44ad"), Color("#c0392b"), Color("#d4ac0d"), Color("#16a085"),
	Color("#2e86c1"), Color("#e67e22"), Color("#6c3483"), Color("#1e8449"),
]

class KingdomData:
	var name: String = ""
	var color: Color = Color.WHITE
	var capital: int = -1
	var members: Array[int] = []
	## The king's name as last logged, so a change of king is a
	## succession line ("" = never logged, or no king).
	var last_king_name: String = ""

var kingdoms: Array[KingdomData] = []
## Relations, keyed "a_b" (a < b, the two kingdom indices): a Dictionary
## {state: String ("peace"/"war"/"allied"), since_day: int, last_raid_day: int}.
var relations: Dictionary = {}
## Starving days per member village (village idx -> consecutive hungry days).
var hungry_days: Dictionary = {}

var agents: Agents = null
var villages: Villages = null
var event_log: EventLog = null
var current_day: int = 1

## The kingdom a village belongs to (-1 = independent). A village's
## index in kingdoms[] is the kingdom's id, so members must be kept in
## sync when a kingdom falls.
func kingdom_of(village_idx: int) -> int:
	if village_idx < 0 or village_idx >= villages.villages.size():
		return -1
	return villages.villages[village_idx].kingdom

## The king of a kingdom: the capital's oldest hero, or — when the
## capital has no hero — its oldest adult. Null when the capital has
## no one at all.
func king_of(kingdom_idx: int) -> SimAgent:
	if kingdom_idx < 0 or kingdom_idx >= kingdoms.size():
		return null
	var capital: int = kingdoms[kingdom_idx].capital
	if capital < 0 or capital >= villages.villages.size():
		return null
	var hero := agents.leader_of(capital)
	if hero != null:
		return hero
	# No hero in the capital: the oldest adult wears the crown.
	var best: SimAgent = null
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == capital and not a.is_child():
			if best == null or a.age > best.age:
				best = a
	return best

## The king's trait for a kingdom (-1 = no king, no boost).
func king_trait(kingdom_idx: int) -> int:
	var king := king_of(kingdom_idx)
	if king == null:
		return -1
	return king.innate_trait

## The trait that boosts a village: its kingdom's king, when it has
## one — else its own leader (the pre-kingdom rule).
func trait_for_village(village_idx: int) -> int:
	var k := kingdom_of(village_idx)
	if k >= 0:
		return king_trait(k)
	return agents.leader_trait(village_idx)

## One simulation day: found/join kingdoms, watch kings, run
## diplomacy, watch for rebellions, and let fallen kingdoms fall.
func tick(day: int) -> void:
	current_day = day
	_form_or_join()
	_watch_kings()
	_run_diplomacy()
	_watch_rebellions()
	_prune_kingdoms()

## Towns that stand alone found a kingdom, or join a nearby one.
func _form_or_join() -> void:
	for vi in villages.villages.size():
		var v: Villages.VillageData = villages.villages[vi]
		if v.kingdom >= 0:
			continue
		if villages.stage_of(v) < KINGDOM_MIN_STAGE:
			continue
		if villages.population_of(v) <= 0:
			continue
		# Join the nearest kingdom in range, if there is one — unless
		# this village is on a rebellion cooldown, in which case it
		# founds its own kingdom instead of crawling back.
		var best := -1
		var best_d := JOIN_RANGE_TILES
		if current_day < v.join_cooldown_until_day:
			best = -1
		else:
			for ki in kingdoms.size():
				var cap: Villages.VillageData = villages.villages[kingdoms[ki].capital]
				var d := Vector2(v.tile - cap.tile).length()
				if d < best_d:
					best_d = d
					best = ki
		if best >= 0:
			_add_member(best, vi)
			event_log.add(current_day, "%s joined the %s." % [v.name, kingdoms[best].name])
		else:
			_found_kingdom(vi)

func _found_kingdom(capital_idx: int) -> void:
	var v: Villages.VillageData = villages.villages[capital_idx]
	var k := KingdomData.new()
	k.name = "Kingdom of %s" % v.name
	k.color = KINGDOM_COLORS[kingdoms.size() % KINGDOM_COLORS.size()]
	k.capital = capital_idx
	k.members.append(capital_idx)
	kingdoms.append(k)
	v.kingdom = kingdoms.size() - 1
	event_log.add(current_day, "%s founded the %s." % [v.name, k.name])

func _add_member(kingdom_idx: int, village_idx: int) -> void:
	kingdoms[kingdom_idx].members.append(village_idx)
	villages.villages[village_idx].kingdom = kingdom_idx

func _remove_member(kingdom_idx: int, village_idx: int) -> void:
	kingdoms[kingdom_idx].members.erase(village_idx)
	villages.villages[village_idx].kingdom = -1

## A king's death is a succession: when the capital's king changes,
## the new one is crowned in the log.
func _watch_kings() -> void:
	for ki in kingdoms.size():
		var k := kingdoms[ki]
		var king := king_of(ki)
		var king_name := ""
		if king != null:
			king_name = king.hero_name if king.hero else "King %s" % king.surname
		if king_name != k.last_king_name:
			if k.last_king_name != "" and king_name != "":
				event_log.add(current_day, "%s is crowned king of the %s." % [king_name, k.name])
			elif k.last_king_name != "" and king_name == "":
				event_log.add(current_day, "The %s has no king." % k.name)
			k.last_king_name = king_name

## Diplomacy: wars cool into peace, neighbouring peaces ripen into
## alliances.
func _run_diplomacy() -> void:
	for key in relations.keys():
		var rel: Dictionary = relations[key]
		var parts := String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if a >= kingdoms.size() or b >= kingdoms.size():
			continue
		if String(rel.get("state", "peace")) == "war":
			if current_day - int(rel.get("last_raid_day", current_day)) >= PEACE_DAYS:
				rel["state"] = "peace"
				rel["since_day"] = current_day
				event_log.add(current_day, "The %s and the %s made peace." % [kingdoms[a].name, kingdoms[b].name])
		elif String(rel.get("state", "peace")) == "peace":
			if current_day - int(rel.get("since_day", current_day)) >= ALLY_DAYS and _are_neighbours(a, b):
				rel["state"] = "allied"
				rel["since_day"] = current_day
				event_log.add(current_day, "The %s and the %s formed an alliance." % [kingdoms[a].name, kingdoms[b].name])

## Two kingdoms are neighbours when any of their villages lie within
## allying range of each other.
func _are_neighbours(a: int, b: int) -> bool:
	for vi in kingdoms[a].members:
		for vj in kingdoms[b].members:
			var d := Vector2(villages.villages[vi].tile - villages.villages[vj].tile).length()
			if d <= ALLY_RANGE_TILES:
				return true
	return false

## A raid between two kingdoms sets them at war (and resets the
## war's clock). Called by Wars when a raid is declared.
func note_raid(attacker_kingdom: int, defender_kingdom: int) -> void:
	if attacker_kingdom < 0 or defender_kingdom < 0:
		return
	if attacker_kingdom == defender_kingdom:
		return
	var key := _pair_key(attacker_kingdom, defender_kingdom)
	var rel: Dictionary = relations.get(key, {"state": "peace", "since_day": current_day, "last_raid_day": current_day})
	if String(rel.get("state", "peace")) != "war":
		event_log.add(current_day, "The %s declared war on the %s!" % [kingdoms[attacker_kingdom].name, kingdoms[defender_kingdom].name])
	rel["state"] = "war"
	rel["last_raid_day"] = current_day
	relations[key] = rel

## The relation between two kingdoms ("peace" when they have never met).
func relation_between(a: int, b: int) -> String:
	if a < 0 or b < 0 or a == b:
		return "peace"
	var rel: Dictionary = relations.get(_pair_key(a, b), {})
	return String(rel.get("state", "peace"))

func _pair_key(a: int, b: int) -> String:
	if a < b:
		return "%d_%d" % [a, b]
	return "%d_%d" % [b, a]

## A member village that starves for three days rebels and leaves.
func _watch_rebellions() -> void:
	for ki in kingdoms.size():
		var k := kingdoms[ki]
		for vi in k.members.duplicate():
			if vi == k.capital:
				continue
			var v: Villages.VillageData = villages.villages[vi]
			var pop := villages.population_of(v)
			if pop <= 0:
				continue
			if v.food < float(pop) * REBEL_FOOD_PER_PERSON:
				hungry_days[vi] = int(hungry_days.get(vi, 0)) + 1
			else:
				hungry_days[vi] = 0
			if int(hungry_days.get(vi, 0)) >= REBEL_HUNGRY_DAYS:
				hungry_days[vi] = 0
				_remove_member(ki, vi)
				# A rebel does not crawl back: it may not rejoin a
				# kingdom for 30 days, so it founds its own instead.
				v.join_cooldown_until_day = current_day + REBEL_JOIN_COOLDOWN_DAYS
				event_log.add(current_day, "%s rebelled against the %s!" % [v.name, k.name])

## A kingdom whose capital is empty hands the crown to its largest
## member; a kingdom with no living village at all falls, and its
## villages stand alone.
func _prune_kingdoms() -> void:
	var i := kingdoms.size() - 1
	while i >= 0:
		var k := kingdoms[i]
		var living: Array[int] = []
		for vi in k.members:
			if villages.population_of(villages.villages[vi]) > 0:
				living.append(vi)
		if living.is_empty():
			# The kingdom is gone: free its villages and drop it.
			for vi in k.members:
				villages.villages[vi].kingdom = -1
			event_log.add(current_day, "The %s has fallen." % k.name)
			kingdoms.remove_at(i)
			_reindex_kingdoms(i)
		elif not living.has(k.capital):
			# The capital is a ghost town: the largest living member
			# becomes the new capital.
			var best := living[0]
			for vi in living:
				if villages.population_of(villages.villages[vi]) > villages.population_of(villages.villages[best]):
					best = vi
			k.capital = best
			event_log.add(current_day, "%s is the new capital of the %s." % [villages.villages[best].name, k.name])
		i -= 1

## After a kingdom is removed, every higher kingdom index shifts down
## by one — rewrite the villages' kingdom ids and the relation keys.
func _reindex_kingdoms(removed_idx: int) -> void:
	for v in villages.villages:
		if v.kingdom > removed_idx:
			v.kingdom -= 1
	var new_relations: Dictionary = {}
	for key in relations.keys():
		var parts := String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if a == removed_idx or b == removed_idx:
			continue
		if a > removed_idx:
			a -= 1
		if b > removed_idx:
			b -= 1
		new_relations[_pair_key(a, b)] = relations[key]
	relations = new_relations

func clear_all() -> void:
	kingdoms.clear()
	relations.clear()
	hungry_days.clear()
	current_day = 1

## Save: each kingdom (name, colour, capital, members, last king),
## plus the relations between them. A village's kingdom idx is
## stored on the village itself (save_system), so a load re-links
## both sides. Old saves have no kingdoms: they start empty and
## Towns found kingdoms on the next tick.
func to_data() -> Array:
	var out: Array = []
	for k in kingdoms:
		out.append({
			"name": k.name, "color": k.color.to_html(), "capital": k.capital,
			"members": k.members.duplicate(), "last_king": k.last_king_name,
			"relations": _relations_for(kingdoms.find(k)),
		})
	return out

## The relations involving one kingdom, as {"other": idx, "state": s, ...}.
func _relations_for(ki: int) -> Array:
	var out: Array = []
	for key in relations.keys():
		var parts := String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if a == ki or b == ki:
			var other := b if a == ki else a
			var rel: Dictionary = relations[key]
			out.append({"other": other, "state": String(rel.get("state", "peace")), "since_day": int(rel.get("since_day", current_day)), "last_raid_day": int(rel.get("last_raid_day", current_day))})
	return out

func from_data(data: Array) -> void:
	clear_all()
	for item in data:
		var d: Dictionary = item
		var k := KingdomData.new()
		k.name = String(d.get("name", "Kingdom"))
		var saved_color := String(d.get("color", ""))
		k.color = Color.html(saved_color) if saved_color != "" else KINGDOM_COLORS[kingdoms.size() % KINGDOM_COLORS.size()]
		k.capital = int(d.get("capital", -1))
		var members: Array = d.get("members", [])
		for m in members:
			k.members.append(int(m))
		k.last_king_name = String(d.get("last_king", ""))
		kingdoms.append(k)
	# Relations are stored per kingdom, so a pair is written twice —
	# the second write just overwrites the first with the same values.
	for ki in kingdoms.size():
		var d2: Dictionary = data[ki]
		for rel_item in d2.get("relations", []):
			var rd: Dictionary = rel_item
			var other := int(rd.get("other", -1))
			if other < 0 or other >= kingdoms.size() or other == ki:
				continue
			relations[_pair_key(ki, other)] = {
				"state": String(rd.get("state", "peace")),
				"since_day": int(rd.get("since_day", current_day)),
				"last_raid_day": int(rd.get("last_raid_day", current_day)),
			}
