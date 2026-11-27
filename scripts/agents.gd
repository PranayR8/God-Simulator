class_name Agents
extends Node2D

## Owns every living agent: movement, reproduction, and drawing.
## The world (GodSimWorld) answers "is this tile walkable?" — agents prefer
## grass and forest and never walk on water or mountains.

const MAX_PEOPLE := 260
const MAX_SHEEP := 140
const BREED_TIME := 60.0  # ticks of cooldown after breeding (15s at 1x)
# Per tick, per agent standing next to a mate. Tuned down from 0.003 in
# Phase 3: now that people die (starvation, old age), births must be
# slow enough that the population finds a balance instead of exploding
# past the food limit and jamming at the cap. (The hunger gate below
# does the rest: only the well-fed breed, so a village that outgrows
# its food stops growing until its food catches up.)
const BREED_CHANCE := 0.001

## Hunger (Phase 2, people only). Hunger rises every tick; at 100 the
## person is starving and health drains. A berry restores 50 hunger,
## so a person eats about one berry a day. Death starts after ~2 days
## with no food (1 day to max hunger + 1 day of draining health).
const HUNGER_MAX := 100.0
const HUNGER_PER_TICK := 100.0 / 120.0  # full → starving in 1 day
const HUNGER_SEEK := 50.0  # start looking for food at half hunger
const BERRY_HUNGER := 50.0  # hunger restored by one berry
const HEALTH_MAX := 100.0
const STARVE_DRAIN_PER_TICK := 100.0 / 120.0  # health 100 → 0 in 1 day of starving
const HEALTH_REGEN_PER_TICK := 2.0  # health recovered per tick while fed
const FORAGE_RANGE := 20  # tiles; how far a hungry person will walk for food
const FORAGE_MARGIN := 4  # tiles past their territory a citizen may forage

## Seasons (Phase 7). Winter cold: an unprotected person freezes in
## ~5 days (health 100 over 600 ticks); a walled village (Town/City)
## halves the drain, so it lasts ~10 days — the wall buys time, but
## only a full food store carries a village through the whole winter.
## Spring doubles births, Winter halves them. Autumn is the harvest:
## a farmer brings in 3 food per work-cycle (24 a day) instead of 1,
## so the store fills before winter; in Winter the land is frozen and
## farmers produce nothing.
const COLD_DRAIN_PER_TICK := 100.0 / 600.0
const BREED_SPRING_MULT := 2.0
const BREED_WINTER_MULT := 0.5
const HARVEST_AUTUMN_FOOD := 3.0

## The season right now (set by tick; Main owns the day count).
var season: int = GodSimWorld.SEASON_SPRING
var current_day: int = 1  # set by tick(); the village blessing is dated by day

## Blessings (Phase 8). A blessed village is fertile and productive for
## a season: its people breed twice as often, and each farmer brings in
## one extra unit of food per work-cycle.
const BLESS_VILLAGE_BREED_MULT := 2.0
const BLESS_VILLAGE_FARMER_BONUS := 1.0

## Plague (Phase 9). A sick person is ill for 5 days (600 ticks). While
## sick they lose health (0.15/tick = 90 over the sickness — a healthy
## person survives at ~10, anyone below 90 health dies) and cannot
## recover, so the plague kills the weak. It spreads to anyone standing
## within 30px (the same closeness as breeding): each sick neighbour is
## a 0.002 chance per tick, so in a crowd it rips through the village
## and in a sparse settlement it barely moves.
const PLAGUE_DURATION := 600.0
const PLAGUE_DRAIN_PER_TICK := 0.15
const PLAGUE_SPREAD_RADIUS := 30.0
const PLAGUE_SPREAD_CHANCE := 0.002

var agents: Array[SimAgent] = []
var world: GodSimWorld = null
var villages: Villages = null  # set by Main; used to keep citizens near home

## Phase 12 — the highest generation born so far in each house
## (surname -> generation). A house's milestone is logged once, when
## its first child of a new generation is born.
var _house_generations: Dictionary = {}

## Emitted when a child is born. village_name is "" for a nomad birth;
## Main stamps the day and lets the EventLog aggregate births.
signal child_born(village_name: String)

## Emitted when someone freezes to death in winter (Phase 7).
## village_name is "" for a nomad; Main logs it.
signal cold_died(village_name: String)
signal plague_died(village_name: String)

## Emitted when a person dies of starvation. village_name is "" for a
## nomad; Main logs it (aggregated per village per day, like births).
signal starved(village_name: String)

## Emitted when a person dies of old age. village_name is "" for a
## nomad; Main logs it (aggregated per village per day).
signal old_age_died(village_name: String)

## Phase 11 — heroes. hero_made: a person became a hero (hero_title
## is "Mara the Swift", deed is why — "blessed by the god", "founder
## of Wilwick"). hero_died: a hero died — Main logs it by name, so
## losing a hero reads as a loss, not just a number. village_name is
## "" for a nomad hero.
signal hero_made(hero_title: String, village_name: String, deed: String)
signal hero_died(hero_title: String, village_name: String)

## Phase 12 — lineage. house_generation: a house reached a new
## generation (generation 2+). Main logs it ("House of Mara, 3rd
## generation"), so a bloodline can be traced in the History.
signal house_generation(surname: String, generation: int)

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func count_people() -> int:
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON:
			n += 1
	return n

func count_animals() -> int:
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.SHEEP:
			n += 1
	return n

## Phase 11 — heroes. A hero is made when the god blesses them, when
## they found a village, or when they survive a war or a plague (see
## the callers: powers.bless_person_at, villages._try_found,
## wars._resolve_war, and _update_plague below). Returns false when
## the person is already a hero (or not a person) — a hero is made
## once, and their name and trait are theirs for life.
func make_hero(a: SimAgent, deed: String) -> bool:
	if a == null or a.kind != SimAgent.Kind.PERSON or a.hero:
		return false
	a.hero = true
	a.hero_name = _unused_hero_name()
	# Phase 12 — a hero keeps the trait they were born with (the
	# bloodline decides what kind of hero they become). An old save's
	# person may have no trait yet; give them one rather than leaving
	# them traitless.
	if a.innate_trait < 0:
		a.innate_trait = _rng.randi_range(0, SimAgent.HERO_TRAIT_NAMES.size() - 1)
	# Phase 12 — a hero founds a house named after their first name:
	# their surname becomes their hero name and their generation
	# resets to 1, so "House of Mara" starts with Mara and her
	# children are its 2nd generation.
	a.surname = a.hero_name
	a.generation = 1
	a.hero_deed = deed
	hero_made.emit(a.hero_title(), _home_name(a), deed)
	return true

## A first name no living hero is using, so heroes stay distinct.
func _unused_hero_name() -> String:
	var used := {}
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON and a.hero and a.hero_name != "":
			used[a.hero_name] = true
	var free: Array[String] = []
	for n in SimAgent.HERO_NAMES:
		if not used.has(n):
			free.append(n)
	if free.is_empty():
		return SimAgent.HERO_NAMES[_rng.randi_range(0, SimAgent.HERO_NAMES.size() - 1)]
	return free[_rng.randi_range(0, free.size() - 1)]

## The hero citizens of a village.
func heroes_of(village_idx: int) -> Array[SimAgent]:
	var out: Array[SimAgent] = []
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON and a.village == village_idx and a.hero:
			out.append(a)
	return out

## The village's leader: its oldest hero. The leader's trait boosts
## the whole village (see the trait effects below); when the leader
## dies, the next-oldest hero takes over — and a village with no hero
## has no leader and no boost, which is how losing a hero hurts.
func leader_of(village_idx: int) -> SimAgent:
	var best: SimAgent = null
	for a in heroes_of(village_idx):
		if best == null or a.age > best.age:
			best = a
	return best

## The leader's trait for a village (-1 = no hero, no leader, no boost).
func leader_trait(village_idx: int) -> int:
	var l := leader_of(village_idx)
	if l == null:
		return -1
	return l.innate_trait

## The leader's trait for one person's village (-1 when they have no
## village or their village has no hero). The trait effects below all
## go through this, so a village's boost follows its leader.
func _leader_trait_for(a: SimAgent) -> int:
	if a.kind != SimAgent.Kind.PERSON or a.village < 0:
		return -1
	return leader_trait(a.village)

## Does this village already have a hero who survived a plague? A
## village remembers its plague survivor — only one is made per
## village, so a plague does not mint a dozen heroes at once.
func _has_plague_hero(village_idx: int) -> bool:
	for a in heroes_of(village_idx):
		if a.hero_deed == "survived the plague":
			return true
	return false

## A hero's home village name ("" for a nomad).
func _home_name(a: SimAgent) -> String:
	if a.village >= 0 and villages != null and a.village < villages.villages.size():
		return villages.villages[a.village].name
	return ""

## Report a hero's death. Call AFTER the hero is removed from the
## list — the agent object still carries its name and village, but
## heroes_of() no longer counts them, so Main can tell whether the
## village has lost its last hero. Called at every place an agent is
## erased (and by Wars for battle deaths).
func note_hero_death(a: SimAgent) -> void:
	if a.kind == SimAgent.Kind.PERSON and a.hero:
		hero_died.emit(a.hero_title(), _home_name(a))

func clear_all() -> void:
	agents.clear()
	queue_redraw()

func spawn(kind: int, tile: Vector2i) -> void:
	if not world.is_walkable(tile.x, tile.y):
		return
	agents.append(SimAgent.new(kind, world.tile_to_world(tile.x, tile.y)))
	queue_redraw()

func spawn_scattered(kind: int, count: int) -> void:
	for i in count:
		var tile := random_walkable_tile()
		if tile.x >= 0:
			spawn(kind, tile)

func random_walkable_tile() -> Vector2i:
	for attempt in 60:
		var x := _rng.randi_range(0, GodSimWorld.WIDTH - 1)
		var y := _rng.randi_range(0, GodSimWorld.HEIGHT - 1)
		if world.is_walkable(x, y):
			return Vector2i(x, y)
	return Vector2i(-1, -1)

## One simulation tick: hunger and health, movement, then maybe breed.
## dt is the tick length in seconds (used for movement).
func tick(dt: float, p_season: int, p_day: int) -> void:
	season = p_season
	current_day = p_day
	var i := 0
	while i < agents.size():
		var a := agents[i]
		a.age += 1.0
		a.breed_cooldown = maxf(0.0, a.breed_cooldown - 1.0)
		if a.kind == SimAgent.Kind.PERSON:
			if _update_hunger(a):
				# Starved to death — removed from the list, so don't
				# advance i; the next agent slid into this slot.
				continue
			if _update_aging(a):
				# Died of old age — same removal, same rule.
				continue
			if _update_cold(a):
				# Froze to death — same removal, same rule.
				continue
			if _update_plague(a):
				# Died of plague — same removal, same rule.
				continue
			_try_eat(a)
		_move_agent(a, dt)
		# Phase 10 — a raider is away at war: they do no job while
		# they march and fight (their work is the war).
		if a.kind == SimAgent.Kind.PERSON and a.job >= 0 and not a.is_child() and a.at_war < 0:
			_do_job(a)
		i += 1
	_try_breed()
	_spread_plague()
	queue_redraw()

## A citizen's work. Farmers harvest food into the village store (one
## unit per 15 ticks — 8 a day — where there's forest to farm in the
## inner half; Phase 7: Autumn is the harvest, 3 units a cycle, and
## Winter grows nothing, so the village lives off what it stored).
## Woodcutters clear the forest at the outer edge (one tile per day, +2
## wood), so the forest edge near the village recedes while the tended
## core stays fed. Builders need no per-tick work — each one raises the
## house count (see Villages.house_count). A worker with nothing to do
## (no forest in their half) just waits — they keep the job.
func _do_job(a: SimAgent) -> void:
	a.job_timer -= 1.0
	if a.job_timer > 0.0:
		return
	if a.village < 0 or villages == null or a.village >= villages.villages.size():
		return
	var v: Villages.VillageData = villages.villages[a.village]
	var radius := villages.territory_radius_px(v)
	if a.job == SimAgent.JOB_FARMER:
		a.job_timer = 15.0
		# Phase 6: the farmer harvests food into the village store —
		# one unit per 15 ticks (8 a day) — but only where there's
		# forest to farm in the inner half of the territory. The berries
		# on the map are natural regrowth now, foraged when the store is
		# empty. (Phase 5's tend — adding a berry to the map — is
		# replaced by this: the farmer's output is the stockpile, and
		# the stockpile number in the village label is the visible food.)
		# Phase 7 — the harvest: Autumn brings in 3 units a cycle (the
		# bumper crop to carry the village through winter); Winter
		# grows nothing (the land is frozen), so the village lives off
		# what it stored. Spring and Summer are the normal 1 unit.
		if _has_forest_in_inner_half(v, radius * 0.5) and season != GodSimWorld.SEASON_WINTER and not world.is_drought():
			var gain := 1.0
			if season == GodSimWorld.SEASON_AUTUMN:
				gain = HARVEST_AUTUMN_FOOD
			# Phase 8 — a blessed village's farmers bring in one extra
			# unit per cycle (the blessing's growth).
			if villages.is_blessed(v, current_day):
				gain += BLESS_VILLAGE_FARMER_BONUS
			# Phase 11 — a Wise leader's farmers bring in one extra
			# unit per cycle too: wisdom feeds the village, and a fed
			# village breeds (only the well-fed breed).
			if _leader_trait_for(a) == SimAgent.HERO_TRAIT_WISE:
				gain += SimAgent.HERO_WISE_FARMER_BONUS
			v.food += gain
	elif a.job == SimAgent.JOB_WOODCUTTER:
		a.job_timer = 120.0
		var t := _furthest_forest_tile(v, radius * 0.5, radius + 2.0 * GodSimWorld.TILE)
		if t.x >= 0:
			world.set_terrain(t.x, t.y, GodSimWorld.Terrain.GRASS)
			# Phase 6: felling a tile yields timber for the store.
			v.wood += Villages.WOOD_PER_TILE

## Is there any forest to farm in the inner half of the territory?
## A farmer only produces food where there's land to farm — a village
## on open grass has no farmers at all (see _assign_jobs), and a
## village whose inner forest is gone stops producing until the land
## recovers. Woodcutters only clear the outer ring, so they don't eat
## the farmers' land. Picking a forest tile directly (instead of a
## random tile and hoping it's forest) is what makes farmers actually
## feed a village — on open land with only a few forest tiles, a random
## pick almost never lands on one.
func _has_forest_in_inner_half(v: Villages.VillageData, max_r: float) -> bool:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var r_tiles := int(ceil(max_r / GodSimWorld.TILE))
	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var t := Vector2i(v.tile.x + dx, v.tile.y + dy)
			if not world.in_bounds(t.x, t.y):
				continue
			if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
				continue
			if world.tile_to_world(t.x, t.y).distance_to(center) > max_r:
				continue
			return true
	return false

## The forest tile furthest from the village centre inside the annulus
## [min_r, max_r] — the forest edge, which is what a woodcutter clears.
## Returns (-1,-1) when there is no forest in the ring.
func _furthest_forest_tile(v: Villages.VillageData, min_r: float, max_r: float) -> Vector2i:
	var center := world.tile_to_world(v.tile.x, v.tile.y)
	var best := Vector2i(-1, -1)
	var best_d := -1.0
	var r_tiles := int(ceil(max_r / GodSimWorld.TILE))
	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var t := Vector2i(v.tile.x + dx, v.tile.y + dy)
			if not world.in_bounds(t.x, t.y):
				continue
			if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
				continue
			var d := world.tile_to_world(t.x, t.y).distance_to(center)
			if d < min_r or d > max_r:
				continue
			if d > best_d:
				best_d = d
				best = t
	return best

## Hunger rises every tick; at max hunger, health drains. Returns true
## if the person starved to death (and removes them from the list).
func _update_hunger(a: SimAgent) -> bool:
	a.hunger = minf(HUNGER_MAX, a.hunger + HUNGER_PER_TICK)
	if a.hunger >= HUNGER_MAX:
		a.health -= STARVE_DRAIN_PER_TICK
		if a.health <= 0.0:
			var home_name := ""
			if a.village >= 0 and villages != null and a.village < villages.villages.size():
				home_name = villages.villages[a.village].name
			agents.erase(a)
			starved.emit(home_name)
			note_hero_death(a)
			return true
	else:
		# Fed: slowly recover any health lost to an earlier hunger spell
		# — unless the winter cold is biting (an unprotected person
		# doesn't recover in winter; see _update_cold).
		if not (season == GodSimWorld.SEASON_WINTER and _winter_protection(a) < 1.0) and a.sick <= 0.0:
			var regen := HEALTH_REGEN_PER_TICK
			if a.blessed:
				regen *= SimAgent.BLESS_REGEN_MULT
			# Phase 11 — a Hardy leader's people recover twice as fast.
			if _leader_trait_for(a) == SimAgent.HERO_TRAIT_HARDY:
				regen *= SimAgent.HERO_HARDY_REGEN_MULT
			a.health = minf(HEALTH_MAX, a.health + regen)
	return false

## How protected this person is from the winter cold (Phase 7):
## 1.0 = fully protected — their village's food store is stocked, so
## they're fed through the winter; 0.5 = half — a Town or City's wall
## and keep shelter them, but they're still cold and hungry; 0.0 =
## unprotected — a Hamlet/Village with an empty store, or a nomad with
## no village at all. Sheep don't feel the cold (they have wool).
func _winter_protection(a: SimAgent) -> float:
	if a.kind != SimAgent.Kind.PERSON:
		return 1.0
	if a.village >= 0 and villages != null and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		if v.food >= 1.0:
			return 1.0
		if villages.stage_of(v) >= 2:
			return 0.5
	return 0.0

## Plague (Phase 9). A sick person drains health and cannot recover
## (see _update_hunger, which skips the regen while sick). When the
## sickness runs out they recover and are immune for life. Returns true
## if they died of plague (and removes them from the list).
func _update_plague(a: SimAgent) -> bool:
	if a.sick <= 0.0:
		return false
	a.sick -= 1.0
	if a.sick > 0.0:
		a.health -= PLAGUE_DRAIN_PER_TICK
		if a.health <= 0.0:
			var home_name := ""
			if a.village >= 0 and villages != null and a.village < villages.villages.size():
				home_name = villages.villages[a.village].name
			agents.erase(a)
			plague_died.emit(home_name)
			note_hero_death(a)
			return true
		return false
	# The sickness ran its course — recovered, and immune for life.
	a.immune = true
	# Phase 11 — surviving a plague can make a hero, but a village
	# remembers only one plague survivor, so a plague does not mint
	# a dozen heroes at once.
	if a.village >= 0 and not _has_plague_hero(a.village):
		make_hero(a, "survived the plague")
	return false

## One tick of plague spreading: each sick person can pass it to anyone
## standing close (within PLAGUE_SPREAD_RADIUS). A crowd is a chain of
## infections; a sparse settlement has no chain, so it burns out fast.
func _spread_plague() -> void:
	for a in agents.duplicate():
		if a.kind != SimAgent.Kind.PERSON or a.sick <= 0.0:
			continue
		for b in agents:
			if b.kind != SimAgent.Kind.PERSON or b.sick > 0.0 or b.immune:
				continue
			if a.pos.distance_to(b.pos) <= PLAGUE_SPREAD_RADIUS and _rng.randf() < PLAGUE_SPREAD_CHANCE:
				b.sick = PLAGUE_DURATION

## Infect everyone healthy (and not immune) within radius_px of a point.
## Returns how many were infected — the way a plague is started, by the
## disaster system or the player's Disaster button.
func infect_at(pos: Vector2, radius_px: float) -> int:
	var count := 0
	for a in agents:
		if a.kind != SimAgent.Kind.PERSON or a.sick > 0.0 or a.immune:
			continue
		if a.pos.distance_to(pos) <= radius_px:
			a.sick = PLAGUE_DURATION
			count += 1
	return count

## How many people are currently sick (the disaster system watches this
## to know when a plague has burned out).
func count_sick() -> int:
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON and a.sick > 0.0:
			n += 1
	return n

## Winter cold (Phase 7). In Winter, a person without shelter or food
## loses health to the cold. A stocked store fully protects them; a
## Town/City wall halves the drain; everyone else freezes. Returns true
## if the person froze to death (and removes them from the list).
func _update_cold(a: SimAgent) -> bool:
	if season != GodSimWorld.SEASON_WINTER:
		return false
	if a.kind != SimAgent.Kind.PERSON:
		return false
	var protection := _winter_protection(a)
	if protection >= 1.0:
		return false
	var drain := COLD_DRAIN_PER_TICK * (1.0 - protection)
	# Phase 11 — a Hardy leader's people take half the winter cold.
	if _leader_trait_for(a) == SimAgent.HERO_TRAIT_HARDY:
		drain *= SimAgent.HERO_HARDY_COLD_MULT
	a.health -= drain
	if a.health <= 0.0:
		var home_name := ""
		if a.village >= 0 and villages != null and a.village < villages.villages.size():
			home_name = villages.villages[a.village].name
		agents.erase(a)
		cold_died.emit(home_name)
		note_hero_death(a)
		return true
	return false

## Old age: when a person's age reaches their randomized lifespan,
## they die. Returns true if they died (and removes them from the list).
func _update_aging(a: SimAgent) -> bool:
	if a.age < a.lifespan:
		return false
	var home_name := ""
	if a.village >= 0 and villages != null and a.village < villages.villages.size():
		home_name = villages.villages[a.village].name
	agents.erase(a)
	old_age_died.emit(home_name)
	note_hero_death(a)
	return true

## If this person is hungry: first eat from their village's food store
## (Phase 6 — the stockpile is the first resort), then forage a berry.
## A citizen with food in the store doesn't need to walk anywhere; a
## nomad, or a citizen whose store is empty, forages as before.
func _try_eat(a: SimAgent) -> void:
	if a.hunger < HUNGER_SEEK:
		return
	if a.kind == SimAgent.Kind.PERSON and a.village >= 0 and villages != null and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		if v.food >= 1.0:
			v.food -= 1.0
			a.hunger = maxf(0.0, a.hunger - BERRY_HUNGER)
			return
	var tile := world.world_to_tile(a.pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := Vector2i(tile.x + dx, tile.y + dy)
			if world.in_bounds(t.x, t.y) and world.eat_berry(t):
				a.hunger = maxf(0.0, a.hunger - BERRY_HUNGER)
				return

func _move_agent(a: SimAgent, dt: float) -> void:
	if not a.has_target or a.pos.distance_to(a.target) < 4.0:
		a.target = _pick_target(a)
		a.has_target = true
	var dir := (a.target - a.pos).normalized()
	var sp := a.speed()
	# Phase 11 — a Swift leader's people walk 25% faster (they get to
	# food, to work, and to war sooner).
	if _leader_trait_for(a) == SimAgent.HERO_TRAIT_SWIFT:
		sp *= SimAgent.HERO_SWIFT_SPEED_MULT
	a.pos += dir * sp * dt
	# Stay inside the map.
	a.pos.x = clampf(a.pos.x, 4.0, GodSimWorld.WIDTH * GodSimWorld.TILE - 4.0)
	a.pos.y = clampf(a.pos.y, 4.0, GodSimWorld.HEIGHT * GodSimWorld.TILE - 4.0)

## Pick a nearby walkable tile to walk to. People like grass and forest;
## sheep only really like grass. Water and mountains are never picked.
## Citizens stay near home: a person assigned to a village only picks
## targets inside their own territory, and if they have wandered outside
## it, they head back toward the village centre instead.
## The exception is hunger: a hungry person walks to the nearest food
## first (see _nearest_food_tile) — they may step a few tiles past
## their border to forage, but no further.
func _pick_target(a: SimAgent) -> Vector2:
	# Phase 10 — a raider marches to war. They do not wander home and
	# do not pick a nearby target; they hop from waypoint to waypoint
	# toward the enemy village (4 tiles at a time, always landing on
	# walkable land), so a lake or a mountain in the way does not stop
	# the march — they slide around it instead of walking into it and
	# getting stuck. Close to the enemy they mill around its centre
	# (the battle is fought there).
	if a.kind == SimAgent.Kind.PERSON and a.at_war >= 0:
		var to_enemy := a.war_target - a.pos
		var dist := to_enemy.length()
		if dist < 48.0:
			return a.war_target + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
		var dir := to_enemy / dist
		var waypoint := a.pos + dir * (4.0 * GodSimWorld.TILE)
		var wt := world.world_to_tile(waypoint)
		for attempt in 8:
			var nx := wt.x + _rng.randi_range(-2, 2)
			var ny := wt.y + _rng.randi_range(-2, 2)
			if world.in_bounds(nx, ny) and world.is_walkable(nx, ny):
				return world.tile_to_world(nx, ny)
		return a.pos
	if a.kind == SimAgent.Kind.PERSON and a.hunger >= HUNGER_SEEK:
		var food := _nearest_food_tile(a)
		if food.x >= 0:
			return world.tile_to_world(food.x, food.y)
	var tile := world.world_to_tile(a.pos)
	var has_home := false
	var home_center := Vector2.ZERO
	var home_radius := 0.0
	if a.kind == SimAgent.Kind.PERSON and villages != null and a.village >= 0 and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		has_home = true
		home_center = world.tile_to_world(v.tile.x, v.tile.y)
		home_radius = villages.territory_radius_px(v)
		if a.pos.distance_to(home_center) > home_radius:
			# Outside the border: walk home. A jittered point near the
			# centre keeps citizens from all marching to one spot.
			var back := home_center + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
			var back_tile := world.world_to_tile(back)
			if world.in_bounds(back_tile.x, back_tile.y):
				var bt := world.get_terrain(back_tile.x, back_tile.y)
				if bt != GodSimWorld.Terrain.WATER and bt != GodSimWorld.Terrain.MOUNTAIN:
					return back
			return home_center
	for attempt in 8:
		var nx := tile.x + _rng.randi_range(-4, 4)
		var ny := tile.y + _rng.randi_range(-4, 4)
		if not world.in_bounds(nx, ny):
			continue
		var t := world.get_terrain(nx, ny)
		if t == GodSimWorld.Terrain.WATER or t == GodSimWorld.Terrain.MOUNTAIN:
			continue
		if a.kind == SimAgent.Kind.SHEEP and t == GodSimWorld.Terrain.FOREST:
			continue
		var dest := world.tile_to_world(nx, ny)
		if has_home and dest.distance_to(home_center) > home_radius:
			continue
		return dest
	return a.pos

## Nearest forest tile with berries this person may walk to, searching
## outward ring by ring from where they stand (up to FORAGE_RANGE
## tiles). Citizens may only forage inside their territory plus a
## small margin past the border — a village with no forest nearby
## starves, which is the point: land matters. Nomads range freely.
## Returns Vector2i(-1, -1) when no reachable food exists.
func _nearest_food_tile(a: SimAgent) -> Vector2i:
	var from := world.world_to_tile(a.pos)
	var home_center := Vector2.ZERO
	var home_limit := INF
	if villages != null and a.village >= 0 and a.village < villages.villages.size():
		var v: Villages.VillageData = villages.villages[a.village]
		home_center = world.tile_to_world(v.tile.x, v.tile.y)
		home_limit = villages.territory_radius_px(v) + FORAGE_MARGIN * GodSimWorld.TILE
	for r in range(1, FORAGE_RANGE + 1):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var t := Vector2i(from.x + dx, from.y + dy)
				if _is_food_tile(t, home_center, home_limit):
					return t
		for dy in range(-r + 1, r):
			for dx in [-r, r]:
				var t := Vector2i(from.x + dx, from.y + dy)
				if _is_food_tile(t, home_center, home_limit):
					return t
	return Vector2i(-1, -1)

func _is_food_tile(t: Vector2i, home_center: Vector2, home_limit: float) -> bool:
	if not world.in_bounds(t.x, t.y):
		return false
	if world.get_terrain(t.x, t.y) != GodSimWorld.Terrain.FOREST:
		return false
	if world.berries_at(t) <= 0:
		return false
	if home_limit < INF:
		if world.tile_to_world(t.x, t.y).distance_to(home_center) > home_limit:
			return false
	return true

## Births by season (Phase 7): Spring doubles them, Winter halves
## them; Summer and Autumn are normal.
func _breed_multiplier() -> float:
	if season == GodSimWorld.SEASON_SPRING:
		return BREED_SPRING_MULT
	if season == GodSimWorld.SEASON_WINTER:
		return BREED_WINTER_MULT
	return 1.0

## Is this person in a village that is currently blessed (Phase 8)?
func _village_blessed(a: SimAgent) -> bool:
	if a.village < 0 or villages == null or a.village >= villages.villages.size():
		return false
	return villages.is_blessed(villages.villages[a.village], current_day)

func _try_breed() -> void:	# A creature breeds when it stands next to another of its kind on good
	# land, its cooldown has expired, and the population cap allows it.
	# (We iterate a copy of the list because breeding appends to it.)
	var people := count_people()
	var sheep := count_animals()
	for a in agents.duplicate():
		if a.breed_cooldown > 0.0:
			continue
		if a.is_child():
			# Children are too young to have children of their own.
			continue
		if a.kind == SimAgent.Kind.PERSON and a.at_war >= 0:
			# Phase 10 — raiders do not breed while they are away at
			# war (and a raider standing in the enemy village should
			# not start a family there).
			continue
		if a.kind == SimAgent.Kind.PERSON and a.hunger >= HUNGER_SEEK:
			# Only the well-fed breed. A village that outgrows its food
			# stops growing until its food catches up — this is what
			# lets the population settle at what the land can feed
			# instead of exploding to the cap and starving.
			continue
		var cap := MAX_PEOPLE if a.kind == SimAgent.Kind.PERSON else MAX_SHEEP
		var total := people if a.kind == SimAgent.Kind.PERSON else sheep
		if total >= cap:
			continue
		var tile := world.world_to_tile(a.pos)
		var t := world.get_terrain(tile.x, tile.y)
		if t != GodSimWorld.Terrain.GRASS and t != GodSimWorld.Terrain.FOREST:
			continue
		var breed_mult := _breed_multiplier()
		if _village_blessed(a):
			breed_mult *= BLESS_VILLAGE_BREED_MULT
		if _has_neighbour(a, 30.0) and _rng.randf() < BREED_CHANCE * breed_mult:
			var child := SimAgent.new(
				a.kind,
				a.pos + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
			)
			if a.kind == SimAgent.Kind.PERSON:
				# Children are born into their parent's village.
				child.village = a.village
				# Phase 12 — a child inherits a mix of their parents:
				# one parent's trait at random (the mate is the nearest
				# adult of the same kind standing close; with no mate
				# the child takes the breeding parent's trait), the
				# breeding parent's surname, and the next generation.
				var mate := _find_mate(a)
				if mate != null and _rng.randf() < 0.5:
					child.innate_trait = mate.innate_trait
				else:
					child.innate_trait = a.innate_trait
				child.surname = a.surname
				child.generation = a.generation + 1
				_note_birth_house(child)
			agents.append(child)
			# Phase 11 — a Swift leader's people breed 25% sooner.
			if _leader_trait_for(a) == SimAgent.HERO_TRAIT_SWIFT:
				a.breed_cooldown = BREED_TIME * SimAgent.HERO_SWIFT_BREED_MULT
			else:
				a.breed_cooldown = BREED_TIME
			if a.kind == SimAgent.Kind.PERSON:
				people += 1
				var home_name := ""
				if a.village >= 0 and villages != null and a.village < villages.villages.size():
					home_name = villages.villages[a.village].name
				child_born.emit(home_name)
			else:
				sheep += 1

## The nearest adult of the same kind standing close — the other
## parent, for inheritance. Returns null when there is no adult mate
## nearby (the child then takes the breeding parent's trait alone).
func _find_mate(a: SimAgent) -> SimAgent:
	var best: SimAgent = null
	var best_d := 30.0
	for other in agents:
		if other == a or other.kind != a.kind:
			continue
		if other.kind == SimAgent.Kind.PERSON and other.is_child():
			continue
		var d := other.pos.distance_to(a.pos)
		if d <= best_d:
			best = other
			best_d = d
	return best

## A house reached a new generation: record it, and tell Main once
## (generation 2+, so the founding generation itself is not a
## milestone — the hero's founding line already covers it).
func _note_birth_house(child: SimAgent) -> void:
	if child.surname == "":
		return
	var known: int = int(_house_generations.get(child.surname, 0))
	if child.generation > known:
		_house_generations[child.surname] = child.generation
		if child.generation >= 2:
			house_generation.emit(child.surname, child.generation)

func _has_neighbour(a: SimAgent, radius: float) -> bool:
	for other in agents:
		if other != a and other.kind == a.kind and other.pos.distance_to(a.pos) < radius:
			return true
	return false

## Remove every agent within radius_px of a point. Returns how many died.
func kill_in_radius(center: Vector2, radius_px: float) -> int:
	var dead := 0
	var i := agents.size() - 1
	while i >= 0:
		if agents[i].pos.distance_to(center) <= radius_px:
			var gone: SimAgent = agents[i]
			agents.remove_at(i)
			note_hero_death(gone)
			dead += 1
		i -= 1
	if dead > 0:
		queue_redraw()
	return dead

## How many people stand within radius_tiles of a tile (used by villages).
## The nearest PERSON within radius_px of a point, or null. Bless
## Person (Phase 8) targets through this — the god taps a person.
func nearest_person(pos: Vector2, radius_px: float) -> SimAgent:
	var best: SimAgent = null
	var best_d := radius_px
	for a in agents:
		if a.kind != SimAgent.Kind.PERSON:
			continue
		var d := a.pos.distance_to(pos)
		if d <= best_d:
			best = a
			best_d = d
	return best

func people_near(tile: Vector2i, radius_tiles: int) -> int:
	var center := world.tile_to_world(tile.x, tile.y)
	var n := 0
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON and a.pos.distance_to(center) <= radius_tiles * GodSimWorld.TILE:
			n += 1
	return n

func _draw() -> void:
	for a in agents:
		if a.kind == SimAgent.Kind.PERSON:
			_draw_person(a)
		else:
			_draw_sheep(a)

## A person, about one tile tall: legs, a coloured tunic, arms, a head
## with a hair cap. A small bob while walking keeps them feeling alive.
## Age shows: children are drawn smaller, elders keep full size but
## with grey hair (and they walk slower — see SimAgent.speed()).
func _draw_person(a: SimAgent) -> void:
	var bob := sin(a.age * 0.9) * 1.0
	var p := a.pos + Vector2(0, bob)
	# Phase 8 — a blessed person stands out: a golden glow and a gold
	# ring around them, drawn behind the figure. The glow is strong
	# enough to spot at fit zoom — a blessed person should read as
	# golden from across the map, not just up close.
	if a.blessed:
		var sc0 := 0.62 if a.is_child() else 1.0
		draw_circle(p, 13.0 * sc0, Color(1.0, 0.85, 0.2, 0.45))
		draw_arc(p, 10.0 * sc0, 0, TAU, 24, Color(1.0, 0.85, 0.2, 1.0), 2.5 * sc0)
	# Phase 9 — a sick person shows it: a sickly yellow-green glow, the
	# mirror of the blessed gold. The colour is a vivid lime, not a
	# grass green, so the ill stand out from the land they walk on.
	if a.sick > 0.0:
		var sc1 := 0.62 if a.is_child() else 1.0
		draw_circle(p, 12.0 * sc1, Color(0.65, 0.9, 0.15, 0.5))
		draw_arc(p, 9.0 * sc1, 0, TAU, 24, Color(0.65, 0.9, 0.15, 1.0), 2.5 * sc1)
	var skin := SimAgent.PERSON_COLOR
	var dark := Color("#5a4632")
	var sc := 0.62 if a.is_child() else 1.0
	var hair := Color("#b0b0b0") if a.is_elder() else a.hair_color
	# Legs.
	draw_line(p + Vector2(-2.5, 4) * sc, p + Vector2(-2.5, 9) * sc, dark, 2.0 * sc)
	draw_line(p + Vector2(2.5, 4) * sc, p + Vector2(2.5, 9) * sc, dark, 2.0 * sc)
	# Tunic: shoulders to hem.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-5, -2) * sc, p + Vector2(5, -2) * sc,
		p + Vector2(6.5, 5) * sc, p + Vector2(-6.5, 5) * sc,
	]), a.shirt_color)
	# Arms.
	draw_line(p + Vector2(-5, -1) * sc, p + Vector2(-7.5, 3) * sc, a.shirt_color, 2.0 * sc)
	draw_line(p + Vector2(5, -1) * sc, p + Vector2(7.5, 3) * sc, a.shirt_color, 2.0 * sc)
	# Head with a hair cap on top.
	draw_circle(p + Vector2(0, -6) * sc, 3.6 * sc, skin)
	draw_arc(p + Vector2(0, -6) * sc, 3.6 * sc, PI, TAU, 10, hair, 2.2 * sc)
	# A working citizen wears their job: a small dot above the head and
	# a trim stripe at the tunic hem, both in the job's color.
	if a.job >= 0:
		var jc: Color = SimAgent.JOB_COLORS[a.job]
		draw_circle(p + Vector2(0, -12) * sc, 2.5 * sc, jc)
		draw_line(p + Vector2(-6.5, 5) * sc, p + Vector2(6.5, 5) * sc, jc, 1.5 * sc)

## A sheep: fluffy white body, four dark legs, a dark head at the front
## (facing whichever way it is walking), a wool tuft and an ear.
func _draw_sheep(a: SimAgent) -> void:
	var facing := 1.0
	if a.target.x < a.pos.x:
		facing = -1.0
	var bob := sin(a.age * 0.9 + 1.7) * 0.5
	var p := a.pos + Vector2(0, bob)
	var wool := SimAgent.SHEEP_COLOR
	var dark := Color("#3a3a3a")
	var outline := Color("#c8c8c8")
	# Legs.
	draw_line(p + Vector2(-6, 2), p + Vector2(-6, 7), dark, 1.5)
	draw_line(p + Vector2(-2, 3), p + Vector2(-2, 7), dark, 1.5)
	draw_line(p + Vector2(2, 3), p + Vector2(2, 7), dark, 1.5)
	draw_line(p + Vector2(6, 2), p + Vector2(6, 7), dark, 1.5)
	# Fluffy body: overlapping wool circles.
	draw_circle(p + Vector2(-5, -1), 4.5, wool)
	draw_circle(p + Vector2(5, -1), 4.5, wool)
	draw_circle(p + Vector2(0, -2), 5.5, wool)
	draw_circle(p + Vector2(0, -4), 4.0, wool)
	draw_arc(p + Vector2(0, -2), 5.5, 0, TAU, 16, outline, 1.0)
	# Head at the front, with a wool tuft and an ear.
	var head := p + Vector2(facing * 9.5, -3)
	draw_circle(head, 3.0, dark)
	draw_circle(head + Vector2(0, -3.5), 1.6, wool)
	draw_line(head + Vector2(-facing * 1.5, -2), head + Vector2(-facing * 4, -4.5), dark, 1.5)
