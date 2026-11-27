class_name Wars
extends Node2D

## Phase 10 — war & conflict. Villages have rivals now, and borders
## mean something. When a village is crowded and hungry — or just
## crowded — it raids the nearest village: a war party walks to the
## enemy territory, fights there (numbers plus a wall bonus decide it),
## and the winner takes food from the loser. Wars are logged and
## visible: a red border on both villages at war, crossed swords where
## the battle is fought, and a red dot above each raider on the march.
## Walls (from Town stage) matter — a walled defender fights half
## again as hard.
##
## A war has two states. MARCH: the raiders walk to the enemy (they
## hop waypoint to waypoint, so lakes and mountains do not stop them).
## BATTLE: the party has reached the enemy's territory, and the fight
## lasts a day — then it resolves (the bigger force, with the wall
## bonus, wins), the winner takes food, and the loser loses people.
## After a war both villages need 10 days to recover before the next
## one, so war is an event, not a permanent state.
##
## Phase 13 — a war ended with a winner (winner_name is the winning
## village). Goals counts it: winning a war is an achievement and one
## half of the Classical era's requirement.
signal war_ended(winner_name: String)
##
## Wars are saved (still v5): the active wars, each raider's war mark,
## and each village's last-war day all round-trip, so a war in progress
## survives a save/load. A war is found by its id (not its place in
## the list), so removing one war never orphans another's raiders.

enum State { MARCH, BATTLE }

## A village raids when it is big enough and hungry (little food for
## its people) — or just big (a Town raids even when it is fed).
const WAR_MIN_POP := 15  # a Village can raid (a Hamlet is too small)
const WAR_CROWDED_POP := 30  # a Town raids even when it is fed
const WAR_HUNGER_FOOD_PER_PERSON := 0.5  # food below this per citizen = hungry
const WAR_MAX_RANGE_TILES := 30  # the nearest village must be this close to raid (two Towns sit ~26 tiles apart when their territories touch, so 20 was too short for wars to ever happen in real play)
const WAR_COOLDOWN_DAYS := 10  # days after a war before a village can raid again
const WAR_PARTY_MIN := 3   # a raiding party is at least 3 adults
const WAR_PARTY_MAX := 15  # and at most 15 (half the adults, capped)
const BATTLE_TICKS := 120  # a battle lasts a day
const WALL_BONUS := 1.5    # a walled defender (Town/City) fights half again as hard
const LOOT_FRACTION := 0.5  # the winner takes half the loser's food
const LOOT_CAP := 15.0     # ...up to 15 units
const LOSER_DEATH_FRACTION := 0.5   # the loser loses half its fighting force
const WINNER_DEATH_FRACTION := 0.15  # the winner loses 15% of its force

var world: GodSimWorld = null
var agents: Agents = null
var villages: Villages = null
var event_log: EventLog = null
var kingdoms: Kingdoms = null  # set by Main; raids respect kingdoms and set wars

var current_day: int = 1
## Each war: {"id": int, "attacker": int, "defender": int,
## "state": State, "battle_left": int, "battle_pos": Vector2}.
## The id is unique per war (never reused), so a raider's at_war mark
## keeps pointing at the right war even when another war ends first.
var wars: Array = []
var _next_war_id := 0
var _scan_counter := 0
var _ticks := 0  # drives the battle marker's pulse

func clear_all() -> void:
	wars.clear()
	queue_redraw()

## Is this village already in a war (as attacker or defender)?
func _is_at_war(vi: int) -> bool:
	for war in wars:
		var w: Dictionary = war
		if int(w.get("attacker", -1)) == vi or int(w.get("defender", -1)) == vi:
			return true
	return false

## The raiders of a war, by its id.
func _party_for(war_id: int) -> Array[SimAgent]:
	var out: Array[SimAgent] = []
	if agents == null:
		return out
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.at_war == war_id:
			out.append(a)
	return out

## One tick of war time — Main calls this every tick with the day, after
## the villages have had their scan. Raids are considered every 8th
## tick (like founding and hiring), so wars start gradually, not all
## at once.
func tick(day: int) -> void:
	current_day = day
	_ticks += 1
	_scan_counter += 1
	if _scan_counter % 8 == 0:
		_try_trigger_war()
	# Advance each war, backwards so removing one never skips another.
	var wi := wars.size() - 1
	while wi >= 0:
		var war: Dictionary = wars[wi]
		var war_id: int = int(war.get("id", -1))
		var di: int = int(war.get("defender", -1))
		var party := _party_for(war_id)
		if party.is_empty():
			# The whole party died on the march (starved, or old age)
			# — the raid falls apart before it begins.
			var defender_name := ""
			if di >= 0 and di < villages.villages.size():
				defender_name = villages.villages[di].name
			event_log.add(current_day, "The raid on %s fell apart — the raiders never arrived" % defender_name)
			_end_war(wi)
			wi -= 1
			continue
		if int(war.get("state", 0)) == State.MARCH:
			var defender: Villages.VillageData = villages.villages[di]
			var centre := world.tile_to_world(defender.tile.x, defender.tile.y)
			var arrived := false
			var arrival_pos := Vector2.ZERO
			# A raider has arrived when they stand on the defender's
			# land (a claimed tile) or right at its heart — the battle
			# is fought on the village's own ground.
			for a in party:
				var at := world.world_to_tile(a.pos)
				if villages.is_in_territory(defender, at) or a.pos.distance_to(centre) <= 2.0 * GodSimWorld.TILE:
					arrived = true
					arrival_pos = a.pos
					break
			if arrived:
				war["state"] = State.BATTLE
				war["battle_left"] = BATTLE_TICKS
				war["battle_pos"] = arrival_pos
				var attacker_name := villages.villages[int(war.get("attacker", -1))].name
				event_log.add(current_day, "The raiders of %s have reached %s — the battle begins!" % [attacker_name, defender.name])
		else:
			var left: int = int(war.get("battle_left", 0)) - 1
			war["battle_left"] = left
			if left <= 0:
				_resolve_war(wi)
		wi -= 1
	queue_redraw()

## Consider one raid per scan: the first village that is big enough,
## hungry or crowded, has a neighbour in range, and is not already at
## war (or recovering from one) sends a party.
func _try_trigger_war() -> void:
	if villages == null or agents == null:
		return
	for ai in villages.villages.size():
		var defender := _can_raid(ai)
		if defender >= 0:
			_start_war(ai, defender)
			return

## Can this village raid? Returns the defender's index, or -1.
func _can_raid(ai: int) -> int:
	var v: Villages.VillageData = villages.villages[ai]
	var pop := villages.population_of(v)
	if pop < WAR_MIN_POP:
		return -1
	if _is_at_war(ai):
		return -1
	# A village that has been at war needs time to recover before the
	# next one — but a village that has NEVER been at war (last_war_day
	# 0) may raid at once; the cooldown is for recovery, not a delay
	# on the first war.
	if v.last_war_day > 0 and current_day < v.last_war_day + WAR_COOLDOWN_DAYS:
		return -1
	# Hungry (little food for its people) or just crowded (a Town).
	var hungry := v.food < float(pop) * WAR_HUNGER_FOOD_PER_PERSON
	var crowded := pop >= WAR_CROWDED_POP
	if not hungry and not crowded:
		return -1
	# The nearest neighbour within raiding range, not already at war.
	# Phase 17 — never raid your own kingdom or an ally. Prefer a
	# village in a kingdom you are already at war with, so a war is
	# fought between kingdoms, not just the two villages that started it.
	var best := -1
	var best_d := INF
	var war_best := -1
	var war_best_d := INF
	for di in villages.villages.size():
		if di == ai:
			continue
		if _is_at_war(di):
			continue
		if kingdoms != null:
			var ka := kingdoms.kingdom_of(ai)
			var kd := kingdoms.kingdom_of(di)
			if ka >= 0 and ka == kd:
				continue  # same kingdom: never raid your own
			if kingdoms.relation_between(ka, kd) == "allied":
				continue  # allies never raid each other
		var d := Vector2(v.tile - villages.villages[di].tile).length()
		if d < best_d:
			best_d = d
			best = di
		if kingdoms != null and kingdoms.relation_between(kingdoms.kingdom_of(ai), kingdoms.kingdom_of(di)) == "war" and d < war_best_d:
			war_best_d = d
			war_best = di
	if war_best >= 0 and war_best_d <= float(WAR_MAX_RANGE_TILES):
		return war_best
	if best < 0 or best_d > float(WAR_MAX_RANGE_TILES):
		return -1
	# The party needs enough adults to send.
	if villages.adults_of(v) < WAR_PARTY_MIN:
		return -1
	return best

## Start a war: half the attacker's adults (3–15) march on the
## nearest village. Each raider is marked with the war's id and the
## enemy's centre, so they walk there (see Agents._pick_target) and
## the war can find them again.
func _start_war(ai: int, di: int) -> void:
	var attacker: Villages.VillageData = villages.villages[ai]
	var defender: Villages.VillageData = villages.villages[di]
	var war_id := _next_war_id
	_next_war_id += 1
	var war := {
		"id": war_id,
		"attacker": ai,
		"defender": di,
		"state": State.MARCH,
		"battle_left": 0,
		"battle_pos": Vector2.ZERO,
	}
	wars.append(war)
	var party_size := clampi(villages.adults_of(attacker) / 2, WAR_PARTY_MIN, WAR_PARTY_MAX)
	var target := world.tile_to_world(defender.tile.x, defender.tile.y)
	var sent := 0
	for a in agents.agents:
		if sent >= party_size:
			break
		if a.kind == SimAgent.Kind.PERSON and a.village == ai and not a.is_child() and a.at_war < 0:
			a.at_war = war_id
			a.war_target = target
			a.has_target = false
			sent += 1
	if kingdoms != null:
		kingdoms.note_raid(kingdoms.kingdom_of(ai), kingdoms.kingdom_of(di))
	event_log.add(current_day, "%s has declared war on %s!" % [attacker.name, defender.name])
	queue_redraw()

## Resolve a battle that has run its day. The bigger force wins — the
## attacker's raiding party against half the defender's adults, with
## a wall multiplying the defender (a Town or City fights half again
## as hard). The winner takes half the loser's food (up to 15); the
## loser loses half its fighting force, the winner 15% of its own.
## The fallen are counted to their home village and logged.
func _resolve_war(wi: int) -> void:
	var war: Dictionary = wars[wi]
	var war_id: int = int(war.get("id", -1))
	var ai: int = int(war.get("attacker", -1))
	var di: int = int(war.get("defender", -1))
	var attacker: Villages.VillageData = villages.villages[ai]
	var defender: Villages.VillageData = villages.villages[di]
	var party := _party_for(war_id)
	# Phase 16 — a fighter counts for their weapon's edge: a raiding
	# party of iron swords hits harder than the same count of stone
	# clubs, and a village's defenders count the same way (halved,
	# as before — the defenders are not all at the gate).
	var attacker_force := agents.weapon_force(party)
	var defender_adults := agents.adults_of_village(di)
	var defender_force := agents.weapon_force(defender_adults) * 0.5
	# Phase 16 — armour saves lives: each side's deaths are cut by
	# its average armour protection (bronze 10%, iron 20%, steel 30%).
	var raider_protect := agents.avg_armor_protection(party)
	var defender_protect := agents.avg_armor_protection(defender_adults)
	var walled := villages.stage_of(defender) >= 2
	if walled:
		defender_force *= WALL_BONUS
	# Phase 11 — a Strong leader's village fights 25% harder, on
	# either side of the battle.
	var atk_trait := agents.leader_trait(ai)
	var def_trait := agents.leader_trait(di)
	if kingdoms != null:
		atk_trait = kingdoms.trait_for_village(ai)
		def_trait = kingdoms.trait_for_village(di)
	if atk_trait == SimAgent.HERO_TRAIT_STRONG:
		attacker_force *= SimAgent.HERO_STRONG_MULT
	if def_trait == SimAgent.HERO_TRAIT_STRONG:
		defender_force *= SimAgent.HERO_STRONG_MULT
	# Phase 18 — a Brave leader's village fights 15% harder.
	if atk_trait == SimAgent.HERO_TRAIT_BRAVE:
		attacker_force *= SimAgent.HERO_BRAVE_MULT
	if def_trait == SimAgent.HERO_TRAIT_BRAVE:
		defender_force *= SimAgent.HERO_BRAVE_MULT
	var attacker_wins := attacker_force > defender_force
	# The spoils: the winner takes half the loser's food, up to a cap.
	var loser: Villages.VillageData = defender if attacker_wins else attacker
	var winner: Villages.VillageData = attacker if attacker_wins else defender
	var loot := minf(loser.food * LOOT_FRACTION, LOOT_CAP)
	loser.food -= loot
	winner.food += loot
	if attacker_wins:
		var leader := agents.leader_of(ai)
		_kill_defenders(di, maxi(1, int(defender_force * LOSER_DEATH_FRACTION * (1.0 - defender_protect))))
		_kill_raiders(war_id, maxi(1, int(attacker_force * WINNER_DEATH_FRACTION * (1.0 - raider_protect))))
		event_log.add(current_day, "%s defeated %s in battle, taking %d food!" % [attacker.name, defender.name, int(loot)])
		# Phase 11 — a hero who led their village to victory is named
		# in the log (only if they lived to tell it).
		if leader != null and agents.agents.has(leader):
			event_log.add(current_day, "%s led %s to victory over %s." % [leader.hero_title(), attacker.name, defender.name])
	else:
		var leader := agents.leader_of(di)
		_kill_raiders(war_id, maxi(1, int(attacker_force * LOSER_DEATH_FRACTION * (1.0 - raider_protect))))
		_kill_defenders(di, maxi(1, int(defender_force * WINNER_DEATH_FRACTION * (1.0 - defender_protect))))
		event_log.add(current_day, "%s repelled %s's raid — the raiders were driven off!" % [defender.name, attacker.name])
		if leader != null and agents.agents.has(leader):
			event_log.add(current_day, "%s held %s against %s's raid." % [leader.hero_title(), defender.name, attacker.name])
	# Phase 13 — a war ended with a winner; Goals counts it.
	war_ended.emit(winner.name)
	# Phase 18 — every survivor of the battle is a Veteran now,
	# and some come home Crippled: a fifth of the losing side's
	# survivors, a tenth of the winning side's.
	_mark_veterans_and_wounded(war_id, di, attacker_wins)
	# Phase 11 — the oldest raider who came home alive becomes a hero:
	# surviving a war is the kind of thing a village remembers.
	var survivors := _party_for(war_id)
	var oldest: SimAgent = null
	for r in survivors:
		if r.hero:
			continue
		if oldest == null or r.age > oldest.age:
			oldest = r
	if oldest != null:
		agents.make_hero(oldest, "survived the war against " + defender.name)
	_end_war(wi)

## Phase 18 — after a battle, the living are Veterans, and some are
## Crippled. The losing side's survivors are crippled more often (a
## fifth) than the winning side's (a tenth). A Crippled Veteran walks
## half as fast and fights at half strength, for life.
func _mark_veterans_and_wounded(war_id: int, defender_idx: int, attacker_wins: bool) -> void:
	# Every survivor is a Veteran; the trait is silent for ordinary
	# villagers (the log names only heroes, so a big battle does not
	# flood the History). A fifth of the losing side's survivors and
	# a tenth of the winning side's come home Crippled.
	var raider_cripple_chance := 0.1 if attacker_wins else 0.2
	var crippled_count := 0
	for a in _party_for(war_id):
		var r: SimAgent = a
		r.add_acquired(SimAgent.ACQUIRED_VETERAN)
		if randf() < raider_cripple_chance and r.add_acquired(SimAgent.ACQUIRED_CRIPPLED):
			crippled_count += 1
			if r.hero:
				event_log.add(current_day, "%s was crippled in the war." % r.hero_title())
	var defender_cripple_chance := 0.2 if attacker_wins else 0.1
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == defender_idx and not a.is_child() and a.at_war < 0:
			var d: SimAgent = a
			d.add_acquired(SimAgent.ACQUIRED_VETERAN)
			if randf() < defender_cripple_chance and d.add_acquired(SimAgent.ACQUIRED_CRIPPLED):
				crippled_count += 1
				if d.hero:
					event_log.add(current_day, "%s was crippled in the war." % d.hero_title())
	event_log.add(current_day, "The war's survivors are Veterans now; %d came home crippled." % crippled_count)

## Kill up to count raiders of this war (the fallen are counted to
## their home village — the attacker's — and logged).
func _kill_raiders(war_id: int, count: int) -> void:
	var party := _party_for(war_id)
	var to_kill := mini(count, party.size())
	for i in to_kill:
		var a: SimAgent = party[i]
		var home_name := ""
		if a.village >= 0 and a.village < villages.villages.size():
			home_name = villages.villages[a.village].name
		agents.agents.erase(a)
		event_log.add_war_death(current_day, home_name)
		agents.note_hero_death(a)
	if to_kill > 0:
		agents.queue_redraw()

## Kill up to count adult defenders of a village (its citizens at home,
## never its own raiders — a village at war has none elsewhere).
func _kill_defenders(di: int, count: int) -> void:
	var defender: Villages.VillageData = villages.villages[di]
	var adults: Array[SimAgent] = []
	for a in agents.agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == di and not a.is_child() and a.at_war < 0:
			adults.append(a)
	var to_kill := mini(count, adults.size())
	for i in to_kill:
		var fallen: SimAgent = adults[i]
		agents.agents.erase(fallen)
		event_log.add_war_death(current_day, defender.name)
		agents.note_hero_death(fallen)
	if to_kill > 0:
		agents.queue_redraw()

## End a war: the surviving raiders walk home (their war mark is
## cleared, so their normal movement sends them back to their own
## village), both villages remember the day (neither raids again for
## the cooldown), and the war leaves the list. Wars are found by id,
## so removing one never orphans another's raiders.
func _end_war(wi: int) -> void:
	var war: Dictionary = wars[wi]
	var war_id: int = int(war.get("id", -1))
	var ai: int = int(war.get("attacker", -1))
	var di: int = int(war.get("defender", -1))
	for a in _party_for(war_id):
		a.at_war = -1
		a.has_target = false
	if ai >= 0 and ai < villages.villages.size():
		villages.villages[ai].last_war_day = current_day
	if di >= 0 and di < villages.villages.size():
		villages.villages[di].last_war_day = current_day
	wars.remove_at(wi)
	queue_redraw()

## Save format: the wars list as plain dictionaries (JSON-safe). The
## raiders' at_war marks live on the agents, and each village's
## last-war day lives on the village — both saved alongside (see
## SaveSystem). Old saves have no "wars" key: no wars, no problem.
func to_data() -> Array:
	var out: Array = []
	for war in wars:
		var w: Dictionary = war
		var bp: Vector2 = w.get("battle_pos", Vector2.ZERO)
		out.append({
			"id": int(w.get("id", 0)),
			"attacker": int(w.get("attacker", -1)),
			"defender": int(w.get("defender", -1)),
			"state": int(w.get("state", 0)),
			"battle_left": int(w.get("battle_left", 0)),
			"battle_x": bp.x,
			"battle_y": bp.y,
		})
	return out

func from_data(data: Array) -> void:
	wars.clear()
	for item in data:
		if item is Dictionary:
			var d: Dictionary = item
			var wid := int(d.get("id", 0))
			wars.append({
				"id": wid,
				"attacker": int(d.get("attacker", -1)),
				"defender": int(d.get("defender", -1)),
				"state": int(d.get("state", 0)),
				"battle_left": int(d.get("battle_left", 0)),
				"battle_pos": Vector2(float(d.get("battle_x", 0.0)), float(d.get("battle_y", 0.0))),
			})
			_next_war_id = maxi(_next_war_id, wid + 1)
	queue_redraw()

func _draw() -> void:
	if villages == null or world == null:
		return
	for war in wars:
		var w: Dictionary = war
		var ai: int = int(w.get("attacker", -1))
		var di: int = int(w.get("defender", -1))
		if ai < 0 or di < 0 or ai >= villages.villages.size() or di >= villages.villages.size():
			continue
		# Both villages at war wear a red border, wider than their own
		# so it covers it — the border is what the war is about, and
		# red is the colour of war.
		for vi in [ai, di]:
			var v: Villages.VillageData = villages.villages[vi]
			villages.draw_territory_border(v, Color(1.0, 0.15, 0.1, 0.9), 4.0)
		# The battle: crossed swords where the fighting is, pulsing so
		# it reads as active, not a static mark.
		if int(w.get("state", 0)) == State.BATTLE:
			var bp: Vector2 = w.get("battle_pos", Vector2.ZERO)
			var pulse := 1.0 + 0.15 * sin(float(_ticks) * 0.3)
			draw_circle(bp, 13.0 * pulse, Color(1.0, 0.15, 0.1, 0.45))
			var r := 8.0 * pulse
			draw_line(bp + Vector2(-r, -r), bp + Vector2(r, r), Color(1.0, 0.9, 0.3, 1.0), 3.0)
			draw_line(bp + Vector2(r, -r), bp + Vector2(-r, r), Color(1.0, 0.9, 0.3, 1.0), 3.0)
	# Raiders on the march wear a red dot above their heads (above the
	# job dot), so the war party is visible crossing the map.
	if agents != null:
		for a in agents.agents:
			if a.kind == SimAgent.Kind.PERSON and a.at_war >= 0:
				draw_circle(a.pos + Vector2(0, -16), 3.0, Color(1.0, 0.15, 0.1, 1.0))
