# OMNI: BLACK MERIDIAN

Single-player real-time-with-pause **mafia empire management strategy** game for Windows / Steam.
Built in **Godot 4.7 (Forward+)**. Original IP — see `docs/OMNI-BLACK-MERIDIAN-brief.pdf` for the full
design + production brief (the authoritative spec).

You play **Aiko Velora**, the Resolver — the ruling Meridian Compact's fixer in a rain-soaked
interspecies metropolis. You do not command armies. You decide which problem becomes somebody
else's war.

## Core decision

The **strategic simulation is authoritative**; the city is a visual proxy. We simulate district control,
economy, relationships, police pressure and rival intent — and *visualize* that through traffic, crowds,
weather and district deterioration. We never build a city-scale life simulation.

## Current milestone — Month 1 (Architecture + Risk Spikes)

Goal: a **15-minute greybox loop must be playable** (brief §19, Month 1 gate).

- [x] Repo structure (brief §13.4)
- [x] `project.godot` + autoloads (GameState, TimeService, EconomyService)
- [ ] District / Venue / Faction / Character data model
- [ ] GameState + strategic tick (1s)
- [ ] One dirty-income loop
- [ ] Greybox Glass Wharf + management camera
- [ ] Bootstrap scene + minimal HUD
- [ ] Basic save/load
- [ ] GDGS splat benchmark (kill criterion: if 500k splats can't run, switch to mesh provider)

## Layout (brief §13.4)

```
/src        deterministic simulation, AI, jobs, narrative, presentation, save
/data       typed Resources / JSON: characters, districts, factions, jobs, narrative
/scenes     bootstrap, city, cinematic, ui
/assets     characters, city, vehicles, props, splat, ui, audio
/tests      unit, integration, smoke
/tools      import, validation
```

## Running

Open the folder in Godot 4.7. Main scene = `scenes/bootstrap/bootstrap.tscn`.

```
# headless smoke (Windows)
"C:/Users/User/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" --headless --path . --quit
```

## Principles

- Strategic sim authoritative; presentation is a proxy.
- No tactical combat — the player is a **problem architect**.
- Data-driven: every authored operation is a Resource/JSON, not hard-coded into UI scenes.
- Deterministic systems get unit tests.
