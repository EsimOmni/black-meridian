# CLAUDE.md — OMNI: BLACK MERIDIAN

Guidance for Claude Code (and any AI agent) working in this repository. Codex / other agents
read `AGENTS.md` (a synced mirror of this file). The authoritative design + production spec is
**`docs/OMNI-BLACK-MERIDIAN-brief.pdf`** — read it before any non-trivial change.

## What this is

A single-player **real-time-with-pause mafia empire management strategy game** for Windows / Steam,
built in **Godot 4.7 (Forward+)**. Original IP. You play **Aiko Velora, the Resolver** — the ruling
Meridian Compact's fixer in *Black Meridian*, a rain-soaked interspecies metropolis. The player is a
**problem architect**, not a general or a shooter: "I decide which problem becomes somebody else's war."

This is a brand-new standalone repo (its own git), separate from the `personax` repo. The game is
inspired by the *structure* of a TV crime drama but is 100% original expression — see the IP boundary
rules below; they are non-negotiable.

## The one decision that governs everything (brief §1)

> **The strategic simulation is authoritative. The city is a visual proxy.**

We simulate district ownership, economy, relationships, police pressure, rival intent, crises and
narrative consequences. We **visualize** those through traffic, crowds, weather, signage and district
deterioration. We never build a city-scale life simulation. The cinematic first-person (Gaussian-splat)
scenes follow the same rule: small, controlled spaces for emotional weight — never a second open-world game.

Corollary: **never put authoritative simulation state inside city-scene nodes.** State lives in
`src/` services (autoloads + data Resources). Scenes read from it; they don't own it.

## Current status

- **Engine binary:** `C:\Users\User\Godot\Godot_v4.7-stable_win64.exe` (+ `_console.exe` for headless).
- **Milestone:** Month 1 (Architecture + Risk Spikes). Done: repo, data model, GameState, TimeService
  (strategic tick + 3 speeds + pause), EconomyService + EconomyMath (the §7.2 formulas, unit-tested),
  WorldSeed (Glass Wharf slice), greybox city, management camera, minimal HUD, bootstrap.
- **Open (Month 1):** GDGS splat benchmark (the kill-criterion risk spike), save/load, one placeholder
  fixer job. See `docs/prompts/` for the ordered build slices.

## Architecture (brief §13.2–§13.4)

Deterministic strategic simulation **separated from presentation**. Core services live in `src/`:

```
GameState (autoload)        authoritative world container + lookups
TimeService (autoload)      real-time-with-pause; 1s strategic tick, rival tick ~10s, 3 speeds
EconomyService (autoload)   dirty/clean economy; settles each tick
EconomyMath                 pure §7.2 formulas (DirtyIncome/CleanCapital/ExposureGain), unit-tested
WorldSeed                   builds the vertical-slice world in code (migrates to /data later)
BM (enums.gd)               shared enums + constants (ControlState, VenueType, Speed, Phase, ...)
```

Data shapes are **typed Godot Resources** (`src/core/*_data.gd`): `DistrictData`, `VenueData`,
`FactionData`, `CharacterData`. Every authored operation is data-driven — never hard-coded into a UI scene.

```
/src        core, simulation, ai, jobs, narrative, presentation, save
/data       typed Resources / JSON: characters, districts, factions, jobs, narrative
/scenes     bootstrap, city, cinematic, ui
/assets     characters, city, vehicles, props, splat, ui, audio
/tests      unit, integration, smoke
/tools      import, validation
/docs       the brief PDF + prompts/ (the build series)
```

## Design pillars — do not violate (brief §6)

1. **Fixer strategy, not tactical combat.** There is NO tactical combat layer. Violence is an
   *operational approach* with political/economic/emotional consequences. This cuts a whole game's
   worth of animation/AI/level-design — protect that cut.
2. **The city shows the state.** District stats are not menu-only; they manifest in the proxy city.
3. **Loyalty is a network of motives** (trust/ambition/fear/grievance/secrets/leverage), not one number.
   Betrayal is **deterministic and telegraphed**, never an untelegraphed random roll (brief §7.6).
4. **Walk through the consequence.** Major beats occasionally drop into a constrained first-person
   splat scene — to inspect, speak, plant/remove an object, walk away — never to shoot.

## IP boundary — HARD RULES (brief §2)

- Do **not** reproduce another series' character names, biographies, relationships, dialogue patterns,
  plot beats, episode structures, geography, estates, costumes or production design.
- Do **not** market the game as an adaptation/unofficial game/analogue of any existing series.
- Do **not** put third-party series imagery in mood boards, store assets or trailers.
- Keep any structural comparison table in internal docs only.
- Only abstract genre structures are retained (ruling dynasty, rival factions, a fixer, disputed
  territory, betrayal, institutional pressure, escalating reprisals).
- Title + character bible + first trailer need an IP review before any public announcement.

## Scope discipline — the failure mode to avoid (brief §12)

The biggest risk for a tiny AI-assisted studio is **producing assets before the mechanic is proven.**
Honor the roadmap gates:
- Month 1 gate: a 15-minute greybox loop must be playable.
- Month 2 gate: a full 25–30 min Night Cycle must be **fun with cubes and placeholder art**. If it
  isn't fun without final visuals, **do not enter asset production.**
- Explicit cuts (brief §12.3): no character combat, no tactical maps, no drivable vehicles, no
  open-world exploration, no runtime AI generation, no console ports before PC validation, no more
  than one splat sequence in the vertical slice. Respect these.

## Splat risk (brief §14, §7.7) — the kill criterion

Godot has no built-in Gaussian-splat support; we rely on the community **GDGS** plugin. Month 1
includes a benchmark. **If 500k splats can't run acceptably on the target desktop, switch to the
mesh provider immediately — do not postpone the decision.** Use Marble's high-quality GLB +
collider GLB as the `MeshWorldProvider` fallback behind a `CinematicWorldProvider` interface.
Do NOT migrate the whole project to Unity to preserve one cinematic technique.

## AI asset pipeline (brief §10, §16) — buy nothing by default

HYBRID route. Local generation + Blender for control; cloud only where it earns its place. Generated
geometry is **provisional** until Blender cleanup + Godot validation. Subscription discipline:
- **Marble Pro** (~$35/mo) only during cinematic production months (splat worlds). Not for objects.
- **Meshy Pro** (~$20/mo) one production-burst month for hero character bases + hero props (has a
  Godot bridge with animation transfer). Output is input to Blender, not a game-ready asset.
- **Tripo** — $0 initially; local Hunyuan3D/TripoSR cover proxies. Only swap in for a benchmarked
  geometry win. Never pay Meshy + Tripo simultaneously.
- Total targeted external spend for the 6-month slice: ~$55–90.

## Conventions

- GDScript, typed where practical. `class_name` for reusable data/util scripts; autoloads stay
  script-only and are referenced by their autoload name (`GameState`, `TimeService`, `EconomyService`).
- **Pure logic gets unit tests** under `tests/unit/` (run headless, exit 0 = pass). Keep testable math
  out of autoloads (see `EconomyMath` — split from `EconomyService` precisely so it's testable; an
  autoload script referenced via `preload` resolves to the singleton and static calls fail).
- Commit directly to the current branch. No PRs unless asked.
- Don't add features/refactors beyond the current slice. Minimal footprint.

## Verify before "done"

Headless is the truth. After any change:

```sh
GODOT="C:/Users/User/Godot/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . --import                       # registers scripts, catches parse errors
"$GODOT" --headless --path . -s tests/unit/test_economy.gd  # unit tests (exit 0 = pass)
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"  # boot smoke (empty = clean)
```

For gameplay-feel changes, also run the editor (`--editor --path .`) and play (F5) — type-checking
and headless boot are not feature testing.

## Running

Open in Godot 4.7 (desktop shortcut "BLACK MERIDIAN (Godot)" or `--editor --path .`). Main scene =
`scenes/bootstrap/bootstrap.tscn`. In-game: SPACE pause/resume, X cycle speed, WASD pan, wheel zoom,
click a venue to inspect.
