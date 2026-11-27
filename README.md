# God Simulator — Godot 4 Project

A small god simulator game in the spirit of WorldBox (but its own thing):
paint a tile world, spawn people and animals, watch them found named
villages, and smite them with rain, lightning, and meteors. Phone-first,
built with Godot 4 and GDScript.

This is the real-codebase version of the web game — the one that can grow
into a real mobile app.

## What's in v1

- **64×48 tile world** (24 px tiles): grass, water, forest, mountain,
  plus scorched rock left by lightning and meteors.
- **Painting** with a brush — fine (1 tile) or wide (3×3) — by touch or mouse.
- **Life**: people and sheep wander on their own, prefer grass/forest,
  avoid water and mountains, and reproduce slowly when conditions are good.
- **Hunger & food**: every person gets hungry over time. Forests grow
  berries (small red dots, up to 5 per tile) that regrow over time; a
  hungry person walks to the nearest berries and eats. Grass alone gives
  nothing — a village with no forest nearby starves, and deaths are
  logged as "died of starvation". Citizens may forage a few tiles past
  their border to find food. Only the well-fed have children, so a
  village that outgrows its food stops growing until the food catches
  up.
- **Aging & death**: people are born, grow up, grow old, and die. Children
  are small and can't have children of their own; adults are full size;
  elders walk slower and have grey hair. Each person lives 60–90 days,
  then dies of old age — the log says so, and births replace the dead,
  so the population settles at what the land can feed instead of
  climbing to the cap and freezing.
- **Village growth stages**: villages grow up. At 6 citizens a place is
  a Hamlet, at 15 a Village, at 30 a Town, at 60 a City — and you can
  see it: the territory gets bigger, more and larger houses appear, a
  stone wall ring goes up at Town, and a keep with the village flag at
  City. The houses spread out as the village grows — the built-up area
  widens with the population instead of piling every house at the
  centre — so a City looks like a town spread across its land, not a
  knot in the middle of an empty circle. The label shows the stage, and
  the log records each promotion ("Wilwick became a Town"). A village
  that loses people falls back down a stage, too.
- **Jobs**: adult citizens take jobs based on what's nearby — Farmers
  harvest food into the village store (a village with farmers stops
  starving), Woodcutters clear the forest at the village's edge (the
  forest visibly recedes) and bring in timber, Builders raise houses
  faster. You can tell who's doing what at a glance: a small dot above
  the head and a trim on the tunic, green for farmers, brown for
  woodcutters, grey for builders. Hires show up in the History ("A
  farmer took up work in Wilwick"). A village on open grass gets only
  builders — there's nothing to farm or fell.
- **Resources & stockpiles**: every village stores food and wood, shown
  in its label ("Wilwick · Town · 33 · F12 · W8"). Farmers fill the food
  store (one unit per harvest, where there's forest to farm); citizens
  eat from the store first and only forage berries when it's empty — so
  a village with a full store weathers a lean spell, and an empty one
  starves. Woodcutters fill the wood store (2 per felled tile), and
  each extra house a builder raises costs 2 wood — a village with
  builders but no timber stays at its basic houses.
- **Seasons**: the year has a rhythm — four seasons of 15 days each.
  Spring doubles births and grows food fast, Summer is the peak of
  growth, Autumn is the harvest (farmers bring in 3 food a cycle, so
  the stores fill), and Winter grows nothing: no new berries, farmers
  idle, and the cold drains the health of anyone without shelter or
  food. A stocked store fully protects a village; a Town or City wall
  halves the drain; everyone else freezes ("froze to death" in the
  History). The map tints by season — golden in Autumn, pale and snowy
  in Winter — and the top bar shows the season, so you can tell it at
  a glance. Winter is the test your stockpiles were built for.
- **Blessings**: three positive powers, each with a cooldown, so you
  choose where to spend your favour. **Bless Person** (tap a person)
  marks them for life with a golden aura — they walk half again as
  fast, recover health three times as fast, and live half again as
  long. **Bless Village** (tap inside a territory) blesses the whole
  village for a season: its people breed twice as often and its
  farmers bring in one extra unit of food per cycle, and its territory
  border turns gold. **Fertile Rain** (tap the forest) grows food at
  once — every forest tile in the radius gains berries, up to the max.
  A blessed village grows visibly faster than an unblessed one: in the
  test, two identical villages ran a season and the blessed one ended
  at 65 citizens (a City) against 28, with a food store of 496 against
  112. Blessings show up in the History ("Wilwick was blessed — it
  will grow fast this season").
- **Disasters**: the world can hurt itself — and so can you. **Plague**
  spreads between people standing close (a sickly green glow marks the
  ill) and kills the weak; the survivors recover immune, so it burns
  out instead of lingering. **Drought** stops all food growth for a
  season and shrinks the lakes a tile at a time. **Wildfire** walks
  through the forest, leaving scorched land behind — rain puts it out.
  Random disasters arrive every few weeks with a day's warning in the
  History, and the **Disaster** button lets you unleash a random one
  where you tap (10-day cooldown). A crowded village hit by plague
  lost half its people; a sparse settlement barely noticed it.
- **War**: villages have rivals now. A village that is crowded (30+
  people) or hungry (its food store below half a unit per person) raids
  its nearest neighbour within 30 tiles, if neither is already at war
  and neither has fought in the last 10 days. A war party of adult
  citizens — half the adults, 3 to 15 — walks to the enemy territory
  (a red dot marks each raider); when the first raider crosses the
  border, the battle begins for a day, and both villages' borders turn
  red with crossed swords marking the clash. Numbers decide it, and a
  Town or City wall multiplies the defender's strength by 1.5: the
  winner takes up to half the loser's food (capped at 15), the loser
  loses half its fighters and the winner a few of its own, and the
  whole thing is in the History ("Wilwick has declared war on
  Kelholt!"). A bigger walled village beats a smaller unwalled one;
  the loser comes out poorer in people and food.
- **Heroes**: individuals matter now. A person the god blesses, the
  first citizen of a village (its founder), or someone who survives a
  war or a plague becomes a named hero — "Mara the Swift", "Joren the
  Hardy" — with a trait (Strong, Wise, Swift, Hardy) and a golden ring
  instead of the plain village ring, so you can spot them at a glance.
  The oldest hero leads their village, and their trait boosts the whole
  village: Strong fights 25% harder in war, Wise farmers bring in an
  extra food per cycle, Swift people walk 25% faster and breed sooner,
  Hardy people recover twice as fast and take half the winter cold.
- **Traits & families**: the world has a memory now. Every person is
  born with a trait (Strong, Wise, Swift, Hardy) and a family surname,
  and a child inherits one parent's trait, their parent's surname, and
  the next generation — so a bloodline's character passes down. A hero
  founds a house named after their first name ("House of Mara"), and
  the History records the line: "House of Mara, 2nd generation",
  "House of Mara, 3rd generation". A village founded by a Strong
  bloodline is led by a Strong hero and fights harder; one founded by
  a Wise bloodline is led by a Wise hero and feeds better.
- **Goals, eras & achievements**: there is something to aim for now.
  The HUD shows the current goal from the start — "Grow a village to
  100 citizens before Day 100" — with live progress. Nine achievements
  mark the way ("First Village", "Raise a City", "Save a Village",
  "Third Generation"...). Win the scenario and a victory banner lands;
  let everyone die, or the 100th day pass, and it is defeat — then you
  keep playing in free play.
- **Resources, miners & era buildings**: the mountains hold more than
  scenery now. Every peak carries stone, iron, marble or steel —
  stone common, steel the rarest — and a village ringed by mountains
  hires miners, who work the nearest peak and haul its resource into
  the store (the label shows what a village actually has). The eras
  advance on what your people mine, not on a day count: stone moves
  the world into Bronze, iron into Iron, marble into Classical, steel
  into Medieval. And the ages look different — Stone thatch huts,
  Bronze warm timber, Iron grey stone and slate, Classical white
  marble with a column, Medieval dark stone with a steep roof — so
  you can tell the era from the rooftops.
- **Gear & the inspect panel**: every adult carries the era they grew
  up in — a weapon, armour and a tool in stone, bronze, iron or steel.
  Gear is set when they come of age and kept for life, so an Iron Age
  village holds elders with stone clubs, the middle-aged with bronze
  swords, and the young with iron. It matters: an iron sword hits
  harder in war, iron armour saves lives, and an iron hoe brings in
  a quarter again the food. Tap the Inspect tool, then tap any
  villager, and their panel opens — their age, health, hunger, job
  and trait; their weapon, armour and tool; and their heritage, the
  house they belong to and the generation they are — with a white
  ring marking who you picked.
- **Kingdoms & diplomacy**: a village that grows into a Town founds
  a kingdom — or joins a nearby one. The kingdom has a name, a
  colour, a capital wearing a gold crown, and a king: the capital's
  oldest hero, whose trait boosts every village in the kingdom. A
  king's death is a succession. Kingdoms fight, make peace after 10
  quiet days, and ally after 20 peaceful days as neighbours — and
  allies are never raided. A village that starves rebels and founds
  its own kingdom; a kingdom with no living village falls. You can
  read it off the map: a kingdom's villages wear its colour on
  their borders, and a member village's label names its kingdom.
  Their deeds go in the History ("Perrin the Swift became a hero of
  Wilwick — founder of Wilwick"), and when a hero dies they are named
  too ("Finn the Swift of Wilwick has died") — losing a hero costs the
  village its leader's boost.
  (Wilwick, Kelholt, Bramley…) that grows houses and population over time.
  Every village owns a territory — a coloured border that grows with its
  citizens and stops at the halfway point to its nearest neighbour, so
  two territories meet at their border but never overlap — and every
  person belongs to a village (a coloured ring under their feet shows
  which one). A group that forms close to an existing village joins it
  instead of founding a new one right next door, and any nomad who
  comes within a few tiles of a village's border joins it too — the
  history log shows these as "N people joined Wilwick". Citizens
  wander inside their own border, and children are born into their
  parent's village. Village names and citizen counts are
  drawn on the map.
- **Powers**: Rain (heals scorched land, grows forest), Lightning (kills
  creatures, scorches trees), Meteor (crater, kills in a radius).
- **Simulation**: pause/play, 1×/2×/4× speed, tick-based. The HUD shows
  Day, People, Villages, and Animals live.
- **History (event log)**: a panel in the top-left records what happened,
  newest first — villages founded, children born (summarised per village
  per day, so births don't flood the log), lightning and meteor strikes
  with how many died, rain. Collapsed it shows just the latest event;
  tap Show to scroll the full history (last 50 events). The log is
  saved with the world and comes back when you reload.
- **Camera**: zoom in/out buttons, pinch to zoom, two-finger drag to pan
  (right/middle-drag and mouse wheel on desktop), Fit button.
- **Save/load**: autosaves every ~10 seconds, plus a Save button, to
  `user://world.json`. The world loads automatically on start.
  "New" generates a fresh world.

## Project layout

```
project.godot          Engine settings (portrait 720×1280, stretch canvas_items)
main.tscn              Main scene: world + agents + villages + powers + HUD
icon.svg               App icon
scripts/
  main.gd              Game controller: ticks, input (touch/mouse), camera
  world.gd             Grid data, procedural generation, terrain drawing
  agent.gd             One creature's data (person / sheep)
  agents.gd            Movement, breeding, drawing of all creatures
  village.gd           Village founding, growth, territories, citizens, drawing
  powers.gd            Rain / Lightning / Meteor effects
  event_log.gd         The world's history (dated events, birth aggregation)
  save_system.gd       JSON save/load (user://world.json)
  hud.gd               Top bar, tool toolbar, history panel — signals only
```

## Install Godot and run it

Godot is free and open source — no account, no royalties.

1. Go to **https://godotengine.org** and download Godot **4.3 or newer**
   (this project was validated with 4.7.2). Pick the standard build for
   your OS — Windows, macOS, or Linux.
2. Unzip it and run the Godot executable.
3. In the Project Manager, click **Import**, pick this folder's
   `project.godot`, and click **Import & Edit**.
4. Press **F5** (or the Play button, top right) to run the game.
   - On desktop, the game opens in a 720×1280 portrait window.
   - `Space` pauses, `F` fits the whole world on screen.

No extra setup is needed — there are no plugins, no assets to download,
and no TileSet to configure. All art is procedural (flat colors and
shapes drawn in code).

## Controls

| Action | Touch (phone) | Mouse / keyboard (desktop) |
|---|---|---|
| Paint terrain / use a power | Drag with one finger | Drag with left mouse |
| Spawn a person / sheep | Tap a tile | Click a tile |
| Pan the camera | Drag with two fingers | Right- or middle-drag |
| Zoom | Pinch | Mouse wheel, or + / − buttons |
| Fit whole world | "Fit" button | "Fit" button (or `F`) |
| Pause / speed | Pause and 1× buttons | `Space` |
| Save / new world | Save and New buttons | — |

## Exporting

Exporting needs the **export templates**: in the editor, go to
**Editor → Manage Export Templates** and download the matching version.

### Android (phone app)

1. Install the export templates (above).
2. Install the Android SDK — the easiest way is Android Studio, or the
   command-line tools. In Godot, set the SDK path under
   **Editor → Editor Settings → Export → Android**.
3. **Project → Export → Add → Android**, then export a debug APK.
   Plug your phone in (USB debugging on) and install the APK, or copy it
   over and open it on the phone.
4. For a Play Store release build you need a keystore — Godot's export
   window walks you through creating one.

### Web (playable in a browser)

1. Install the export templates.
2. **Project → Export → Add → Web**, then export.
3. Host the exported files anywhere static — itch.io, GitHub Pages,
   Netlify (all have free tiers). Open the page on your phone and
   add it to the home screen to play it like an app.

### iOS (App Store)

Needs a Mac with Xcode and an Apple Developer Program membership
($99/year). In Godot: **Project → Export → Add → iOS**, export the
Xcode project, then build and submit from Xcode. (Same path as an
Expo/React Native app would take.)

## v2 roadmap (ideas, not promises)

- More powers: volcano, flood, freeze, forest fire, plague
- More creatures: wolves, birds, fish — and creatures that fight
- Seasons and day/night
- Village depth: wars, trade, leaders, traits
- Sound effects and music
- Achievements and world stats
- Bigger worlds + performance work (spatial partitioning for agents)
- Multiplayer — much later; it needs a real server, not just the game

## Notes for learning

GDScript reads a lot like Python (indentation, `for`/`if`/`match`,
dynamic typing with optional type hints). Good places to start reading:
`scripts/world.gd` (data + drawing), then `scripts/agents.gd`
(movement and breeding), then `scripts/main.gd` (how input becomes
game actions). Comments mark the non-obvious parts.
