<!-- This file mirrors CLAUDE.md as the repo doctrine, PLUS a Gemini-only operator section at the very bottom ("## Gemini operator layer — delegating to Codex and Claude"). Keep the mirrored body in sync with CLAUDE.md; the Gemini-only section is intentionally NOT in CLAUDE.md/AGENTS.md/CODEX.md and must not be synced away. -->

# CLAUDE.md — OMNI: BLACK MERIDIAN

Guidance for Claude Code (and any AI agent) working in this repository. Codex, Gemini, and other agents
read `AGENTS.md` (and their respective synced mirrors `CODEX.md` and `GEMINI.md`). The authoritative design + production spec is
**`docs/OMNI-BLACK-MERIDIAN-brief.pdf`** — read it before any non-trivial change.

> **Primary model = Claude Fable 5.** Read **`docs/FABLE.md`** for the Fable operating layer (effort,
> long-run behavior, subagents, memory, and the hard rule: never instruct the model to echo its reasoning
> into responses — it triggers a `reasoning_extraction` refusal). On any `stop_reason: "refusal"`, fall
> back to Claude Opus 4.8 for that call. Record cross-run lessons in **`tasks/lessons.md`** and reference
> it at the start of each slice.

> **Repo location:** `D:\black-meridian` (moved off C: on 2026-07-01). Remote: `EsimOmni/black-meridian`
> (private). Godot 4.7 binary: `D:\Godot\Godot_v4.7-stable_win64.exe` (moved off C: 2026-07-02).

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

- **Engine binary:** `D:\Godot\Godot_v4.7-stable_win64.exe` (+ `_console.exe` for headless).
- **Milestone:** Month 2 COMPLETE — the full systemic Night-Cycle loop is built and gate-passed
  (2026-07-04). Month 1 (Architecture + Risk Spikes) done: data model, GameState, TimeService, Economy,
  WorldSeed, greybox city, save/load, splat spike. Month 2 slices, all committed + independently probed
  (deterministic, zero-RNG, save-safe): **P05** economy squeeze (pause racket / pressure front) · **P06**
  heat→disruption→income + latched inspection · **P07** RivalDirector (telegraph→land sabotage) · **P08**
  systemic job generation (sim-triggered, byte-identical rebuild) · **P09** Night-Cycle phase machine
  (COUNCIL→OPERATIONS→CRISIS→RECKONING, per-tick settle preserved) · **P10** loyalty/betrayal motive
  network (two-gate, telegraphed, *preventable*) · **P11** first-pass noir UI theme (Palette + generated
  theme.tres).
- **Splat kill criterion: RESOLVED → SPLAT_OK** (2026-07-02). GDGS v2.2.0 + Godot-4.7 push-constant patch
  renders 542k splats at 483 avg / 420 low fps @1080p on the 5060 Ti (`docs/prompts/notes/P01-splat-benchmark.md`).
- **Month-2 gate: PASSED** (`docs/prompts/notes/P08-month2-gate.md`, `P11-month2-gate.md`). Feel verdict
  "fun, stress, very good" (short session) + a full-cycle integrity probe proving the chain
  money→heat→inspection→rival→job→phases is INTACT and self-feeding (rival sabotage spawns jobs). **Month 3
  (asset production) is authorized** under the existing discipline: proxy first, Sketchfab license-gated,
  no GLB replaces a validated mechanic, AI 90 / human 10.
- **Open (deferred, not blocking):** P05b operative pool · P06b evidence chains · P06c Central Pressure ·
  P07b rival noise/actions · P07c rival memory · P08b more job origins · P10b hidden motives + multi-lieutenant ·
  P19 final UI polish. See `docs/prompts/` for the ordered build slices.

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
geometry is **provisional** until Blender cleanup + Godot validation.

Production doctrine (adopted 2026-07-02, see `tasks/lessons.md`):
- **Concept → asset-split.** Approve a full concept image (keyframe) for a location/set first, THEN
  generate individual assets to match it. Never generate assets piecemeal without a master.
- **AI ~90% / human ~10%.** AI does first-pass everything; the human 10% is curation, Blender cleanup,
  integration, taste. Budget every asset task as 90/10.
- **Prefer ready plugins/templates** (GDGS, controller/camera templates, asset-library addons) over
  bespoke code for anything that isn't the game's identity. The sim is core; plumbing is not.

Subscription discipline:
- **Marble Pro** (~$35/mo) only during cinematic production months (splat worlds). Not for objects.
- **Meshy Pro** (~$20/mo) one production-burst month for hero character bases + hero props (has a
  Godot bridge with animation transfer). Output is input to Blender, not a game-ready asset.
- **Tripo** — $0 initially; local Hunyuan3D/TripoSR cover proxies. Only swap in for a benchmarked
  geometry win. Never pay Meshy + Tripo simultaneously.
- **Sketchfab (free tier, via Epic Games account — added 2026-07-03).** Free GLB downloads for
  **proxy/greybox enrichment only** — NOT hero assets that carry the game's identity. Two hard rules:
  1. **License-check every download before use.** Sketchfab "free" is mixed: CC0 (free), CC-BY
     (attribution required — track it), and **CC-BY-NC (commercial use FORBIDDEN)**. Black Meridian
     ships on Steam = commercial; a CC-BY-NC asset is a legal liability, never use one. Record each
     used asset's URL + license + required attribution in `assets/ATTRIBUTIONS.md` (create on first use).
  2. **Does NOT bypass the gates.** Free geometry is not an excuse to enter asset production early.
     Brief §12 still governs: no GLB — Sketchfab or otherwise — replaces a cube until the Month-2
     "fun with cubes" gate passes. Treat Sketchfab GLBs like any provisional geometry: input to
     Blender cleanup + Godot validation, not a game-ready asset.
- Total targeted external spend for the 6-month slice: ~$55–90 (Sketchfab free tier adds $0).

## Conventions

- GDScript, typed where practical. `class_name` for reusable data/util scripts; autoloads stay
  script-only and are referenced by their autoload name (`GameState`, `TimeService`, `EconomyService`).
- **From P03 onward, the `godot-ai` MCP server is the primary rail** for creating scenes, wiring
  nodes/signals and attaching scripts (the Unreal-MCP equivalent for Godot — it validates against the
  live editor at write time). Plain file edits stay fine for pure logic + unit tests.
- **Pure logic gets unit tests** under `tests/unit/` (run headless, exit 0 = pass). Keep testable math
  out of autoloads (see `EconomyMath` — split from `EconomyService` precisely so it's testable; an
  autoload script referenced via `preload` resolves to the singleton and static calls fail).
- Commit directly to the current branch. No PRs unless asked.
- Don't add features/refactors beyond the current slice. Minimal footprint.

## Verify before "done"

Headless is the truth. After any change:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64.exe"
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

---

## Gemini operator layer — delegating to Codex and Claude (Gemini-only; live-verified 2026-07-02)

You (Gemini, running inside Antigravity in this workspace) have a **PowerShell 5.1 shell** and BOTH the
`codex` CLI (`codex-cli 0.141.0`) and the `claude` CLI (`2.1.143`, Claude Code) on PATH — all three
verified callable from your shell on 2026-07-02. So you are not limited to your own model: for a
bounded, well-scoped sub-task you can hand work to **Codex** (billed to the ChatGPT subscription) or to
**Claude** (billed to the Claude subscription). You stay the architect — you decide, verify, and
integrate; the delegate does the grunt work and reports back.

**Shell rule — you are PowerShell 5.1, NOT bash:**
- `&&` is a parser error here. Chain with `;` (run sequentially) or `if ($?) { ... }` (run-if-success).
- `< /dev/null` does not exist. To stop `codex exec` waiting on stdin, use `$null | codex exec ...`.
- Quote paths with spaces; call exes with spaces via `& "C:\path\app.exe" args`.

### Delegate to Codex (bounded/mechanical/vision/batch → ChatGPT budget, NOT your model)

Codex is the little brother: reading & summarizing large files/logs, mechanical multi-file edits,
"where is X" searches, draft-then-review, batch/vision triage. It can also drive **BlenderMCP (port
9876)** and the **godot-ai MCP** live (both registered in `~/.codex/config.toml`).

```powershell
$null | codex exec --sandbox read-only "summarize d:\black-meridian\src\save\save_service.gd in 10 lines"
$null | codex exec --sandbox workspace-write "via BlenderMCP on port 9876: <do X>, then export <Y>"
```

- PROMPT first, `-i <image>` flags AFTER the prompt (order matters — `-i` before prompt hangs).
- Close stdin with `$null | ...` on any multi-`-i` or batch call, or it hangs on "Reading from stdin".
- NEVER kill a running `codex exec` — it flushes output only on completion; a killed run = lost work.

### Delegate to Claude (Sonnet / Haiku, headless → Claude budget; you pick the model + effort)

For a self-contained coding/reasoning sub-task you can shell out to Claude Code headless. **You decide
the model by task weight — default to the cheaper tier and only step up when the task earns it.** You
also pick effort; if unsure, high is a safe default for Sonnet, but don't burn high-effort on trivial work.

```powershell
claude -p "rename symbol Foo to Bar across src/ and show the diff" --model haiku
claude -p "implement the CinematicWorldProvider interface per docs/prompts/P01" --model sonnet
```

- `claude -p` does NOT need stdin closed — it waits 3s then proceeds on its own (harmless warning).
  Only `codex exec` needs the `$null |` guard. (Both round-trips live-verified 2026-07-02: Haiku
  returned clean; the Codex bridge spawned + reached the model, only blocked by a ChatGPT usage cap.)
- `--model haiku` → cheap/mechanical (renames, format fixes, boilerplate, short summaries).
- `--model sonnet` → real coding/reasoning (a feature slice, a non-trivial refactor, a tricky bug).
- **This bills the Claude subscription — it is NOT free like Codex.** Prefer Codex for anything Codex
  can do; reach for Claude only when you specifically want an Anthropic model's coding/reasoning.
- You CANNOT make Codex or your own runtime call Sonnet/Haiku — only the `claude` CLI can. No API key
  path is set up here; use the CLI, not a raw Anthropic API call.

### When NOT to delegate

Architectural decisions, IP-boundary judgment (brief §2), the splat-vs-mesh kill call, anything needing
full conversation context, or work so small the round-trip costs more than doing it yourself. Delegate
tasks, not decisions.
