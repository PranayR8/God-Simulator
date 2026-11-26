# God Simulator — Roadmap: from toy to game

## Where the game is now (Phase 0 — done)

- Paint terrain (grass, water, forest, mountain), spawn people and sheep,
  breeding, villages that form when people cluster, village territories
  with citizen assignment, rain / lightning / meteor powers, pause and
  1x/2x/4x speed, autosave, and a HUD (Day, People, Villages, Animals).
- What it is: a living toy. What it isn't yet: a game — nothing to aim
  for, nothing at stake, and the world doesn't tell you what happened.

## How to use this roadmap

- Build **one phase at a time, in order**. Play it for at least 10
  minutes after each phase. If it isn't fun or it breaks something, fix
  it before moving on.
- Each phase lists what to build, what "done" means, and a 5-minute test.
- If a phase turns out bigger than expected, split it — never merge two
  phases into one build.
- Design rules for every phase:
  1. The player is a god, not a manager — they use powers and watch,
     they don't micromanage.
  2. Every feature must be visible on the map or in the log — if you
     can't see it, it doesn't exist.
  3. The sim must stay readable at a glance — one screen should tell
     you how the world is doing.

---

## Arc A — Make it alive (the world tells you stories)

### Phase 1 — Event log

- **Player feels:** the world talks back.
- **Build:** a scrollable log (bottom-left, or a toggle panel) recording
  dated events: village founded, child born, person died (with cause:
  old age / starvation / lightning / meteor), village reached a new
  stage, power used. Keep the last ~50 events.
- **Done when:** playing 5 minutes produces a log that reads like a
  little history, with correct counts (births match the population
  gained, deaths listed match the HUD drop).
- **Test:** start a new world, use lightning once, wait for a village to
  form. The log shows the strike, the deaths, and the founding with the
  right day numbers.
- **Don't build yet:** notifications / popups — the log comes first;
  alerts are polish (Phase 14).

### Phase 2 — Hunger & food

- **Player feels:** land matters — a village in a desert starves, one by
  a forest thrives.
- **Build:** each person has hunger that rises over time; forests grow
  berries (a visible food source on forest tiles); a hungry person walks
  to the nearest food and eats, restoring hunger. No food for too long
  → starvation (health drains, then death). Grass alone gives nothing.
- **Done when:** people near forest survive indefinitely; people on bare
  grass start dying of starvation after ~2 days; the event log says
  "died of starvation".
- **Test:** new world, paint a big grass-only island, spawn 10 people on
  it, run at 4x. They should start dying within a few days. Repeat with
  forest nearby — they survive.
- **Don't build yet:** farming (that's jobs, Phase 5) — foraging only.

### Phase 3 — Aging & death

- **Player feels:** generations turn over; the world isn't a blob that
  only grows.
- **Build:** each person has an age (in days); they age visibly
  (children small, adults full size, elders slower, grey hair); old age
  kills at a randomized lifespan (e.g. 60–90 days). Births replace
  deaths, so population finds a balance instead of hitting the cap and
  freezing.
- **Done when:** after ~30 days you can see children, adults, and
  elders; elders die of old age; population stabilizes instead of
  jamming at the cap.
- **Test:** run a village at 4x for 10 minutes. The log shows old-age
  deaths, and the population curve flattens instead of climbing to the
  cap and stopping.
- **Don't build yet:** family trees (Phase 12) — age and death first,
  lineage later.

---

## Arc B — Make villages matter (growth you can steer)

### Phase 4 — Village growth stages

- **Player feels:** a hamlet becoming a town is an achievement.
- **Build:** stages by citizen count: Hamlet (6), Village (15), Town
  (30), City (60). Each stage changes the look (more / bigger houses, a
  wall ring at Town, a keep or town hall at City) and grows the
  territory. The label shows the stage.
- **Done when:** a village visibly changes as it grows, and the stage
  name in the label matches its population.
- **Test:** cluster-spawn 70 people in one place, run at 4x. Watch it
  pass through all four stages with visible changes.
- **Don't build yet:** specialization (jobs decide what a village is
  good at — Phase 5).

### Phase 5 — Jobs

- **Player feels:** people have purposes; villages become
  self-sufficient.
- **Build:** citizens take jobs based on what's nearby: Farmer (tends
  the land around the village and produces food), Woodcutter (clears
  forest tiles near the village, producing wood), Builder (houses appear
  faster). Jobs are visible — a tiny tool marker or a different tunic
  trim. A villager picks the job their village needs most.
- **Done when:** a village with farmers stops starving without the
  player foraging for them; woodcutters visibly clear forest near the
  village.
- **Test:** found a village in a forest, run at 4x. Farmers appear, food
  flows, and the forest edge near the village recedes.
- **Don't build yet:** stockpiles (Phase 6) — jobs produce, storage
  comes next.

### Phase 6 — Resources & stockpiles

- **Player feels:** lean times are survivable if you prepared; plenty is
  a buffer, not a number.
- **Build:** villages store food and wood (shown in the village label or
  a tap-to-inspect panel). Houses cost wood; food is eaten from the
  stockpile first, then foraging. A village with a full stockpile
  weathers a bad season; an empty one starves.
- **Done when:** the stockpile numbers move for the right reasons (up
  with farmers / woodcutters, down as people eat and houses are built),
  and a village with a full store survives a winter (Phase 7) that kills
  an empty one.
- **Test:** watch a village's food number over 10 days: it rises after
  harvests and falls as citizens eat.
- **Don't build yet:** trade between villages (a Phase 10+ idea — hold
  it).

### Phase 7 — Seasons

- **Player feels:** the year has a rhythm; winter is something to
  prepare for.
- **Build:** a 4-season year (each ~15 days): Spring (births and food
  growth up), Summer (food growth peak), Autumn (harvest — stockpiles
  fill), Winter (no food growth, cold drains health of anyone without
  shelter / food). The map tints by season; the HUD shows the season.
- **Done when:** you can tell the season at a glance, and winter kills
  in unprepared villages but not prepared ones.
- **Test:** run a full year at 4x. Deaths spike in winter in a village
  with an empty stockpile; a stocked village survives.
- **Don't build yet:** weather events (rain is a power; storms are
  disasters — Phase 9).

---

## Arc C — Make it dramatic (godhood, disaster, war)

### Phase 8 — Blessings

- **Player feels:** generosity is as fun as smiting.
- **Build:** positive powers: Bless Person (a golden aura that makes
  them faster, stronger, longer-lived), Bless Village (fertility and
  growth for a season), Fertile Rain (like rain, but grows food). Each
  blessing has a cooldown, so the player chooses where to spend their
  favor.
- **Done when:** a blessed village grows visibly faster than an
  unblessed one, and a blessed person stands out on the map.
- **Test:** bless one of two identical villages; after a season, the
  blessed one has more citizens and a bigger territory.
- **Don't build yet:** curses beyond the existing powers — blessings
  first, then disasters give the dark side weight.

**Status: done.** Three positive powers, each with its own cooldown
(in ticks; 120 = 1 day), so the player chooses where to spend their
favour. **Bless Person** (1-day cooldown): tap a person within 2
tiles; they are marked for life — `blessed` on the agent, a golden
glow + gold ring drawn around them, walk speed ×1.5, health regen ×3,
lifespan ×1.5. **Bless Village** (5-day cooldown): tap inside a
territory; the village is blessed for a season (15 days,
`blessed_until_day`) — its people breed ×2 and its farmers bring in
+1 food per cycle — and its territory border turns gold. **Fertile
Rain** (1-day cooldown): tap the forest; every forest tile in a
4-tile radius gains 2 berries (capped at 5). A tap with no target, or
while a blessing recharges, spends nothing (returns 0 / -1 and shows
a hint); the button greys out while its cooldown runs. The toolbar
grew a third row for the three buttons (BottomBar 136 → 196px,
HUD_RESERVE_PX 200 → 260). Blessed flags survive saves (still v5 —
the new fields default safely). Verified by a deterministic test
(test_blessings.gd): bless person speed 26 → 39, lifespan ×1.5,
cooldown 120, a second cast refused (-1), the HUD button greys out
and lights back up; two identical 12×12 forest villages (15 adults
each) ran a season — the blessed one ended at pop 65 (a City, radius
16, food 496) against the unblessed 28 (radius 10, food 112), its
blessing worn off by day 16; fertile rain moved forest tiles 1 → 3
berries and capped a 4 at 5; cooldowns drain to zero; save round-trip
restores `blessed` and `blessed_until_day`. All regressions re-ran
green (hunger/aging/jobs/stages/join/villages/stockpiles/seasons)
and a live browser playthrough (Day 11–12, Wilwick · Town · 40, its territory border gold — "Wilwick was blessed — it will grow fast this season", "A golden light blessed a villager", and "Fertile rain fell — the forest is heavy with food" all in the History, the Bless Person and Bless Village buttons greyed out on their cooldowns, zero errors; a focused check confirmed the blessed person's golden halo stands out — the first version's glow was too faint to spot among 40 people, so it was strengthened to a 13px halo at 0.45 alpha with a 2.5px solid gold ring). One gotcha:
`yield` is a reserved keyword in GDScript — a local named `yield`
fails to parse ("Expected variable name after var"); the farmer's
output variable is `gain`.

**Next up: Phase 9, Disasters.**

### Phase 9 — Disasters

- **Player feels:** the world can hurt itself; your job is to save it
  (or watch it burn).
- **Build:** random disasters with warnings: Plague (spreads between
  people standing close, kills the weak — visible sick tint), Drought
  (lakes shrink, food stops growing for a season), Wildfire (spreads
  through forest, scorched land after). The player can also trigger one
  (a disaster button with a long cooldown). The event log records them.
- **Done when:** each disaster is visible, spreads by a clear rule, and
  ends; the log tells the story of what it did.
- **Test:** trigger a plague in a crowded village at 4x. It spreads,
  kills, and burns out — and a sparse village barely notices it.
- **Don't build yet:** war (Phase 10) — disasters are the world vs
  itself; war is villages vs each other.

**Status: done.** Three disasters, each with its own clear rule.
**Plague:** a sick person is ill for 5 days (600 ticks); while sick
they lose 0.15 health per tick (90 over the sickness — a healthy
person survives at ~10, anyone below 90 health dies) and cannot
recover, so the plague kills the weak. It spreads to anyone standing
within 30px (the same closeness as breeding), a 0.002 chance per tick
per sick neighbour — in a crowd it rips through the village, in a
sparse settlement it barely moves. The sick show a sickly green glow
(the mirror of the blessed gold); when the sickness runs out they
recover and are immune for life, so a plague burns out instead of
lingering. Deaths are logged ("died of plague", aggregated per village
per day) and the burnout is logged too ("The plague has burned out —
the survivors are immune"). **Drought:** for a season (15 days) no
food grows — berries do not regrow and farmers produce nothing — and
the lakes shrink a tile at a time (1 per 30 ticks, ~4 a day), a loss
that lasts (rain does not refill a lake). The map gets a dry brown
tint so a drought looks different from any season. **Wildfire:** a
fire starts on a forest tile and walks through the forest — each
burning tile lasts a day and can ignite each adjacent forest tile, so
it ends when it runs out of fuel, leaving scorched land behind.
Burning tiles draw an orange flame with a yellow heart; rain puts a
fire out (the tile is left as grass). Random disasters arrive every
15–30 days, with a 1-day warning in the History first ("The air grows
foul in Wilwick — plague is coming", "The land grows dry — a drought
is coming", "Smoke rises on the horizon — a wildfire is coming"), so
the player is not blindsided. The player can also trigger one with
the **Disaster** button (row 3 of the toolbar, next to Fertile Rain)
— it unleashes a random disaster where they tap, with a 10-day
cooldown, and greys out while it recharges. Disasters are saved
(still v5 — the new fields default safely): a drought in progress, a
burning tile, and a sick person all survive a save/load. Verified by
a deterministic test (test_disasters.gd): a crowded village (20
adults, mixed health) infected — 20 infected at the start, 10 deaths
(the weak), 10 immune survivors, nobody sick at the end; a sparse
settlement (5 people, 12 tiles apart) — 1 infected, 0 deaths, all 5
still there; a drought — berries stayed at 100 over 5 days (no
regrowth), the lake shrank 36 → 29, it ended on day 16 with both log
lines; a wildfire — a 12×12 forest burned to 144 scorched tiles and
burned out, rain extinguished a fresh fire; the Disaster button
unleashed a random disaster, set the 1200-tick cooldown, and refused
a second trigger; a due disaster was warned a day ahead and started
the next day; the save round-trip restored drought_until_day 18, 1
burning tile, and a sick person at 300 ticks. All regressions re-ran
green (hunger/aging/jobs/stages/join/villages/stockpiles/seasons/
blessings) and a live browser playthrough (a wildfire: Day 11–12, Wilwick · Town · 39–40, "A wildfire has started in the forest!" in the History, orange flames with yellow hearts burning through the forest at the village's edge, dark brown scorched land behind them, the Disaster button greyed out on its cooldown; a drought: Day 1, Wilwick · Village · 19, "A drought has come — the lakes shrink and the land dries" in the History, the map warm/olive from the drought tint, the Disaster button greyed out; a plague: Day 3–4, Wilwick · Village · 21, "Plague has come to Wilwick!" in the History, several people with bright lime sick glows, the Disaster button greyed out — zero errors throughout). Two things the playthrough caught: (1) the Disaster tool was never routed in _apply_tool_at_screen (the match had no TOOL_DISASTER case) and _apply_disaster was never defined, so the button did nothing on the first check — the deterministic test only called disasters.trigger_random directly, never the UI path; fixed by adding the match case and the function. (2) A wildfire with no forest near the tap spent the cooldown on nothing — trigger_random now falls back to a plague or a drought when there is no forest to catch. The sick tint was also strengthened (a grass green was camouflaged against the grass; it is now a vivid lime) and the drought tint was strengthened (0.12 → 0.20 alpha) so both read at a glance. One
gotcha: the disaster end-detection in disasters.tick must use the day
passed in, not world.current_day — world.tick (which sets it) runs
after disasters.tick in _do_tick, so the world's day is one tick
stale and a drought ending on the last tick of a test would never be
logged.

**Next up: Phase 10, War & conflict.**

### Phase 10 — War & conflict

- **Player feels:** villages have rivals; borders mean something.
- **Build:** when a village is crowded and hungry (or just crowded), it
  raids the nearest village: a war party walks to the enemy territory,
  fights (numbers plus a wall bonus decide it), the winner takes food
  from the loser. Wars are logged and visible (clashing markers, a red
  tint on the border). Walls (from Town stage) matter.
- **Done when:** two crowded, hungry villages go to war without the
  player doing anything, and the outcome follows the rules (bigger +
  walled wins; the loser loses food and people).
- **Test:** spawn two big villages close together with little food
  around, run at 4x. A raid happens, the log records it, and one
  village comes out poorer.
- **Don't build yet:** diplomacy / alliances — war first, peace later.

### Phase 11 — Heroes & leaders

- **Player feels:** individuals matter; you remember names.
- **Build:** exceptional people become named heroes: a blessed person,
  the first citizen of a village (founder), or someone who survives a
  war or plague. Heroes have a trait (Strong, Wise, Swift, Hardy) that
  helps their village, a golden ring instead of a plain one, and their
  deeds go in the log ("Mara the Swift saved Wilwick from starvation").
  Village leaders: the oldest hero leads, and their trait boosts the
  whole village.
- **Done when:** you can point at a person and know who they are and why
  they matter, and losing a hero hurts their village.
- **Test:** bless a person, run until they do something notable. The log
  names them, and their village grows faster while they live.
- **Don't build yet:** full family trees — heroes first, lineage is a
  later layer.

---

## Arc D — Make it a game (goals, then polish)

### Phase 12 — Traits, families & lineage

- **Player feels:** the world has memory; bloodlines rise and fall.
- **Build:** children inherit a mix of their parents' traits; families
  share a surname; the log records lineages ("House of Mara, 3rd
  generation"). A village's character drifts with its bloodlines.
- **Done when:** you can trace a family across generations in the log,
  and a village founded by one bloodline plays differently from another.
- **Test:** follow one family for 3 generations — the surname persists
  and traits pass down.
- **Don't build yet:** nothing — this is the last systems phase for a
  reason.

### Phase 13 — Goals, eras & achievements

- **Player feels:** there is something to aim for, and winning means
  something.
- **Build:** eras (Stone → Bronze → Iron → Classical) unlocked by
  milestones (first city, 100 citizens, survive 10 winters, win a war);
  achievements with a checklist ("Found 5 villages", "Raise a city",
  "Save a village from plague"); a scenario mode with a win condition
  ("Grow a city of 100 before Day 100") and a lose condition (everyone
  dies). The HUD shows the current goal.
- **Done when:** a new player can see what to do next, chase it, and get
  a clear "you did it" moment.
- **Test:** play the "first city" scenario. The goal is visible from the
  start, progress is tracked, and reaching it shows a victory banner.
- **Don't build yet:** leaderboards / sharing — single-player goals
  first.

### Phase 14 — Polish, sound & tutorial

- **Player feels:** the game is finished.
- **Build:** sound effects (ambient, power sounds, a soft chime for
  events), particles (rain splashes, fire embers, hearts on birth),
  day / night tint, camera shake on meteor, a 2-minute interactive
  tutorial ("paint grass, spawn a person, wait for a village"), and
  mobile control fixes from playtesting. Fix every annoyance found in
  Phases 1–13 first.
- **Done when:** a friend who has never played can open the game, finish
  the tutorial, and play for 10 minutes without asking you anything.
- **Test:** hand the link to someone new and watch (don't help). Every
  time they get stuck, that's a bug to fix.
- **Don't build yet:** anything new — this phase is for finishing, not
  adding.

---

## Explicitly out of scope (for now)

Online multiplayer, 3D, mod support, in-app purchases, accounts / cloud
saves. Revisit only after Phase 14 ships and people ask for one of them
by name.

## Status

- Phase 0 — done (Nov 26, 2026). Phase 1 (event log) — done (Nov 26, 2026): History panel, founding/birth/power lines, birth aggregation, save/load of the log; verified by a deterministic headless test and a live browser playthrough (6 villages, 13 log entries in 6 days, zero errors). Phase 2 (hunger & food) — done (Nov 26, 2026): hunger rises over time, forests grow berries (red dots, up to 5/tile, regrow 1 per 60 ticks), hungry people walk to the nearest berries and eat (one berry restores 50 hunger), no food → starvation (health drains, death after ~2 days, logged as "died of starvation", aggregated per village per day); citizens may forage a few tiles past their border; hunger/health and berries saved (save format v2). Verified by a deterministic headless test (grass island: 13 starvation deaths in 300 ticks; forest: 0 deaths in 600 ticks, 10 → 15 people; berries eaten + regrown) and a live browser playthrough (Day 5, Wilwick 26 citizens by a forest, berries visible, no starvation, zero errors). Phase 3 (aging & death) — done (Nov 26, 2026): every person has an age in days and a randomized lifespan (60–90 days); children are small and can't breed (under 12 days), adults are full size, elders (50+ days) walk slower and have grey hair; old age kills, logged as "died of old age" (aggregated per village per day); age and lifespan saved (save format v3, old saves load as newborns with a fresh random lifespan). Births rebalanced for a world with deaths: BREED_CHANCE 0.003 → 0.001 and only the well-fed breed (hunger < 50), so a village that outgrows its food stops growing until the food catches up. Also fixed the join rule's flakiness: the join distance is now measured to the CLOSEST member of the group, not to whichever person the founding scan happened to pick (a wanderer a tile or two out could veto the whole group's join). Verified by a deterministic headless test (old-age death + log line; child/adult/elder stages and speeds 26.0/26.0/15.6; lifespans inside 60–90 days; 10 children → 0 births, 10 adults → births; 80-day run: pop 21 → 82, 11 old-age deaths, 83 births, 0 starvation) and a live browser playthrough (Day 5, Wilwick 17, join lines in the log, children visibly small, berries on the trees, zero errors). Join regression re-run 3/3 green (8/8 joined). Note: a village founded far from food can starve out entirely and sit empty ("Kelholt · 0") — a ghost town; no cleanup yet (a later phase could disband empty villages). Phase 4 (village growth stages) — done (Nov 26, 2026): stages by citizen count — Hamlet (6), Village (15), Town (30), City (60). Each stage grows the territory cap (7/10/13/16 tiles), allows more and bigger houses (12/16/20/24, scaled 1.0–1.45×), a stone wall ring appears at Town, and a keep (stone tower with battlements and the village flag) at City. The map label shows the stage ("Wilwick · Town · 33"), and stage changes are logged ("Wilwick became a Town" / "Wilwick fell back to a Village" — stages are always derived from the current population, so a village that loses people falls back down). Verified by a deterministic headless test (all 9 threshold boundaries; wave-spawned climb 8 → 18 → 33 → 63 with radius 6 → 10 → 13 → 16 and the exact stage log lines; forced crash to 5 citizens falls back to Hamlet) and a live browser playthrough (Day 2, Wilwick · City · 78, wall ring + keep visible, log shows "became a Town" and "became a City", zero errors). House-spread fix (Nov 26, same day, his feedback): houses used to pile within 38px of the centre while the territory grew to 384px wide, so a City looked like a knot in an empty circle — now the built-up area spreads with the population (built-up radius 24 + 2.6 per citizen, capped at 65% of the territory, square-root spacing for even density), so a Hamlet clusters near the centre and a City spreads its houses across its land; verified by the same wave test (furthest house 45 → 71 → 110 → 188px across the four stages) and a live playthrough (Day 2, Wilwick · City · 76, ~20 houses spread across the territory, zero errors). Join/villages/hunger/aging regressions all re-ran green (the four /tmp test scripts were wiped by the VM and recreated from the recorded patterns; the test scripts now live in ~/workspace/god-simulator-checks/ so a VM replacement can't wipe them again). Phase 5 (jobs) — done (Nov 26, 2026): adult citizens take jobs based on what's nearby — Farmer (tends the forest in the inner half of the territory, one berry per 30 ticks, 4 a day, twice a tile's natural regrowth), Woodcutter (clears the furthest forest tile in the outer ring, one per day, so the forest edge near the village recedes while the tended core stays fed), Builder (each one raises the house count by one, up to the stage cap, so houses appear faster). The job mix follows the forest inside the territory (a village in the woods gets ~40% farmers / ~30% woodcutters / ~30% builders; a village on open grass gets only builders). A job is for life; children don't work and are hired when they grow up. Jobs are visible — a small dot above the head and a trim stripe at the tunic hem, in the job's color (green farmer, brown woodcutter, grey builder) — and hires are logged ("A farmer took up work in Wilwick", aggregated per job, village and day). Jobs are saved (save format v4; old saves load with no job and are hired at the next scan). Verified by a deterministic headless test (farmer tend +1 berry per call; woodcutter turns the furthest outer forest tile to grass; forest village 6 farmers / 5 woodcutters / 4 builders, 0 starvation, forest 144 → 119 tiles, hires logged, houses 10 vs pop/3 = 6; small-forest village 6 farmers, 0 starvation — the 6 tiles alone regrow 12/day against ~30/day eaten, so the farmers cover the gap; grass village 0 farmers / 0 woodcutters / 10 builders; save round-trip v4, 10 jobs saved and restored) and a live browser playthrough (Day 13, Wilwick · Town · 41, all three job lines in the History, green/brown/grey dots visible above heads, berries on the tended forest, zero errors). Two things the test taught: a farmer must pick a forest tile directly (a random tile in the inner half almost never lands on forest when the forest is sparse — the first version starved a small-forest village), and a person eats ~2 berries a day when food is nearby, not 1 (so the farmer tends 1 berry per 30 ticks). Join/stages/villages/hunger/aging regressions all re-ran green. Phase 6 (resources & stockpiles) — done (Nov 26, 2026): every village stores food and wood, shown in the map label ("Wilwick · Town · 33 · F12 · W8"). Farmers harvest food into the store — one unit per 15 ticks (8 a day) where there's forest to farm in the inner half (this replaces Phase 5's tend, which added a berry to the map; the farmer's output is now the stockpile number, and the berries on the map are natural regrowth, foraged when the store is empty). Citizens eat from the store first (one unit restores 50 hunger, the same as a berry), then forage. Woodcutters add 2 wood per felled tile. Houses cost wood: the base houses (one per 3 citizens) are free, but each extra house a builder raises costs 2 wood, built one per scan as timber comes in — so a village with builders but no woodcutters stays at its base house count. Stockpiles saved (save format v5; old saves load with empty stores and no extra houses, and rebuild them as wood comes in). Verified by a deterministic headless test (10-day forest village: food rose 17 → 123, 0 starvation, wood 92, 4 extra houses built, label shows F and W; buffer test: after the forest was stripped the store drained 123 → 0, no deaths in the first day on the store, 26 deaths by day 7.5 once it ran dry — the buffer is finite; grass village: 10 builders, 0 wood, 0 extra houses, then 5 extra houses built and all 10 wood spent once timber was given; save round-trip v5, stockpiles restored exactly) and a live browser playthrough (Day 13, Wilwick · Town · 38, label F16 · W8 — the numbers moved between screenshots, F6 → F16 and W6 → W8 — all three hire lines in the History, wall ring + spread houses + job dots visible, zero errors). Jobs/stages/join/villages/hunger/aging regressions all re-ran green (the jobs test's farmer unit check now asserts the store gains food instead of a berry on the map, and its save check expects v5). Phase 7 (seasons) — done (Nov 26, 2026): a 4-season year (15 days each) — Spring (births ×2, berries regrow every 45 ticks), Summer (food growth peak, berries every 30 ticks), Autumn (the harvest — farmers bring in 3 food a cycle, 24 a day, so the store fills; berries every 60 ticks), Winter (no food growth — no berry regrowth, farmers idle — and the cold drains the health of anyone without shelter or food). A stocked food store fully protects a village; a Town/City wall halves the drain; everyone else freezes (an unprotected person freezes in ~5 days, a walled one in ~10). The map tints by season (fresh green Spring, warm Summer, golden Autumn, pale snowy Winter) and the top bar shows the season; the History logs each season's arrival ("Winter has come — the cold will test your stores"). The season is derived from the day, so no save-format change (old saves just pick up the season from their day). Verified by a deterministic headless test (season indices exact for days 1/15/16/30/31/45/46/60/61; Autumn harvest: food 331 → 3282 in 15 days; stocked village through Winter: pop 41 → 41, 0 cold deaths, 0 starvation, store drained 3282 → 2369; empty-store village in Winter: pop 14 → 0, 16 cold deaths, log says "froze to death"; 10 nomads in Winter: all froze, 12 cold deaths; HUD reads 'Winter', world season 3) and a live browser playthrough (Day 16, first day of Summer, Wilwick · Town · 53, label F115 · W76 — the food store visibly filling, F107 → F115 between screenshots — "Summer has come — the land is at its greenest" in the History alongside the Spring birth boost (5 children born on Day 15, 4 on Day 14) and all three hire lines, the map warm-tinted, the HUD reading 'Summer', zero errors). A TopBar layout bug was caught by this playthrough: adding the SeasonLabel pushed the row ~80px past 720px, clipping the Day label on the left and the New button on the right, and shifting the Speed button so the check's clicks missed it (it ran at 1x and only reached Day 5); fixed by dropping the five TopBar labels from 22px to 18px. Two test-isolation lessons: the headless tests share user://world.json, and Main loads it in _ready — a seasons test that ran 80+ days left a day-348 Winter save that leaked into the jobs test and killed its grass villagers with cold; every test now deletes the save in _init. The jobs test's small-forest and grass phases also hand-found their villages (the natural founding scan can land a few tiles off, which put the 6 forest tiles outside the inner half and made it a founding test, not a jobs test). Phase 8 (blessings) — done (Nov 26, 2026): three positive powers, each with its own cooldown — Bless Person (1-day cooldown, tap a person within 2 tiles: marked for life with a golden aura, walk speed ×1.5, health regen ×3, lifespan ×1.5), Bless Village (5-day cooldown, tap inside a territory: blessed for a season — births ×2, farmers +1 food per cycle — and its territory border turns gold), Fertile Rain (1-day cooldown, tap the forest: every forest tile in a 4-tile radius gains 2 berries, capped at 5). A tap with no target, or while a blessing recharges, spends nothing; the button greys out while its cooldown runs. The toolbar grew a third row for the three buttons (BottomBar 136 → 196px, HUD_RESERVE_PX 200 → 260). Blessed flags survive saves (still v5 — the new fields default safely). Verified by a deterministic headless test (bless person speed 26 → 39, lifespan ×1.5, cooldown 120, a second cast refused, the HUD button greys out and lights back up; two identical 12×12 forest villages ran a season — the blessed one ended at pop 65, a City, radius 16, food 496, against the unblessed 28, radius 10, food 112, its blessing worn off by day 16; fertile rain moved forest tiles 1 → 3 berries and capped a 4 at 5; cooldowns drain to zero; save round-trip restores blessed and blessed_until_day) and a live browser playthrough (Day 11–12, Wilwick · Town · 40, its territory border gold — "Wilwick was blessed — it will grow fast this season", "A golden light blessed a villager", and "Fertile rain fell — the forest is heavy with food" all in the History, the Bless Person and Bless Village buttons greyed out on their cooldowns, zero errors; a focused check confirmed the blessed person's golden halo stands out — the first version's glow was too faint to spot among 40 people, so it was strengthened to a 13px halo at 0.45 alpha with a 2.5px solid gold ring). One gotcha: `yield` is a reserved keyword in GDScript — a local named `yield` fails to parse; the farmer's output variable is `gain`. Phase 9 (disasters) — done (Nov 26, 2026): three disasters, each with its own clear rule. Plague: a sick person is ill for 5 days; while sick they lose 0.15 health per tick (90 over the sickness — a healthy person survives at ~10, anyone below 90 health dies) and cannot recover, so it kills the weak; it spreads to anyone standing within 30px (0.002 per tick per sick neighbour) — in a crowd it rips through the village, in a sparse settlement it barely moves; the sick show a sickly green glow, and the survivors recover immune, so it burns out. Drought: for a season (15 days) no food grows (berries do not regrow, farmers produce nothing) and the lakes shrink a tile at a time (~4 a day, a loss that lasts); the map gets a dry brown tint. Wildfire: a fire starts on a forest tile and walks through the forest (each burning tile lasts a day and can ignite each adjacent forest tile), leaving scorched land; burning tiles draw an orange flame, rain puts a fire out. Random disasters arrive every 15–30 days with a 1-day warning in the History first, so the player is not blindsided. The player can also trigger one with the Disaster button (row 3 of the toolbar, next to Fertile Rain) — a random disaster where they tap, 10-day cooldown, greys out while it recharges. Disasters are saved (still v5 — the new fields default safely). Verified by a deterministic headless test (a crowded village: 20 infected, 10 deaths, 10 immune survivors, nobody sick at the end; a sparse settlement: 1 infected, 0 deaths, all 5 still there; a drought: berries stayed at 100 over 5 days, the lake shrank 36 → 29, it ended on day 16; a wildfire: a 12×12 forest burned to 144 scorched tiles and burned out, rain extinguished a fresh fire; the Disaster button set the 1200-tick cooldown and refused a second trigger; a due disaster was warned a day ahead and started the next day; the save round-trip restored drought_until_day 18, 1 burning tile, and a sick person at 300 ticks) and a live browser playthrough (a wildfire: Day 11–12, Wilwick · Town · 39–40, "A wildfire has started in the forest!" in the History, orange flames with yellow hearts burning through the forest at the village's edge, dark brown scorched land behind them, the Disaster button greyed out on its cooldown; a drought: Day 1, Wilwick · Village · 19, "A drought has come — the lakes shrink and the land dries" in the History, the map warm/olive from the drought tint, the Disaster button greyed out; a plague: Day 3–4, Wilwick · Village · 21, "Plague has come to Wilwick!" in the History, several people with bright lime sick glows, the Disaster button greyed out — zero errors throughout). Two things the playthrough caught: (1) the Disaster tool was never routed in _apply_tool_at_screen (the match had no TOOL_DISASTER case) and _apply_disaster was never defined, so the button did nothing on the first check — the deterministic test only called disasters.trigger_random directly, never the UI path; fixed by adding the match case and the function. (2) A wildfire with no forest near the tap spent the cooldown on nothing — trigger_random now falls back to a plague or a drought when there is no forest to catch. The sick tint was also strengthened (a grass green was camouflaged against the grass; it is now a vivid lime) and the drought tint was strengthened (0.12 → 0.20 alpha) so both read at a glance. One gotcha: the disaster end-detection in disasters.tick must use the day passed in, not world.current_day — world.tick (which sets it) runs after disasters.tick in _do_tick, so the world's day is one tick stale. Phases 10–14 — not started.
- Next up: Phase 10, War & conflict.
