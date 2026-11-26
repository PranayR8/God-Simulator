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
- **Villages**: when enough people cluster, they found a named village
  (Wilwick, Kelholt, Bramley…) that grows houses and population over time.
  Village names are drawn on the map.
- **Powers**: Rain (heals scorched land, grows forest), Lightning (kills
  creatures, scorches trees), Meteor (crater, kills in a radius).
- **Simulation**: pause/play, 1×/2×/4× speed, tick-based. The HUD shows
  Day, People, Villages, and Animals live.
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
  village.gd           Village founding, growth, names, drawing
  powers.gd            Rain / Lightning / Meteor effects
  save_system.gd       JSON save/load (user://world.json)
  hud.gd               Top bar, tool toolbar, buttons — signals only
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
