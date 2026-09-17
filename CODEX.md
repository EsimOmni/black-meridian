<!-- This file mirrors CLAUDE.md. Codex and other agents: follow it as the repo doctrine. Keep in sync with CLAUDE.md. -->

# CLAUDE.md — OMNI: BLACK MERIDIAN

Guidance for Claude Code (and any AI agent) working in this repository. Codex, Gemini, and other agents
read `AGENTS.md` (and their respective synced mirrors `CODEX.md` and `GEMINI.md`). The authoritative design + production spec is
**`docs/OMNI-BLACK-MERIDIAN-brief.pdf`** — read it before any non-trivial change.

> # 🚨 ENGINE REBOOT — READ THIS BEFORE ANYTHING ELSE (2026-09-18)
>
> **This repository is no longer where the game is built.** OMNI: BLACK MERIDIAN moved from
> **Godot 4.7 to Unreal Engine 5.8.2**.
>
> | | |
> |---|---|
> | **Active development** | **`D:\black-meridian-ue`** → `EsimOmni/black-meridian-ue` (private) |
> | **This repo** | **ARCHIVE + behavioral oracle.** Never deleted, never rewritten, kept runnable. |
> | **Final Godot state** | tag **`godot-final`** → `aff9e43`, verified running (headless exit 0) |
>
> **Do NOT write new game code here.** This repo's only remaining jobs are (a) golden-vector
> extraction — it is the oracle S1 measures Unreal against — and (b) the side-by-side cinematic
> comparison at Gate B. Everything below about Godot slices (P01–P20), GDScript conventions and the
> `godot-ai` MCP rail describes **how the oracle was built**, not what to do next.
>
> **Authoritative plan:** `docs/unreal-reboot/` (authoring home) · mirrored at
> `D:\black-meridian-ue\Docs\plan\`. **S0 is complete**; evidence at
> `D:\black-meridian-ue\Docs\gates\S0.md`. **Next is S1 — Determinism Core**, not started.
>
> ⚠️ **Name collision:** the old Godot push had its own "S1" (Month-3 close, finished). The reboot's
> **S1 = Determinism Core**. They are unrelated — always confirm which one is meant.


> **🎯 READ `docs/NOW.md` FIRST — every session, before anything else.** It is the LIVE state:
> what we're doing right now, the next step, open decisions, key files for the active phase. This
> file (CLAUDE.md) holds the permanent rules; `NOW.md` holds the current situation. The "Current
> status" section below is a coarse milestone marker and can lag — `NOW.md` is the source of truth
> for "where did we leave off." **After finishing any slice/commit, UPDATE `docs/NOW.md`** (push the
> old state into its "Geçmiş" summary) so the next chat opens with full context. Cem should never
> have to re-explain where we are — that is what NOW.md is for.

> **Primary model = Claude Fable 5.** Read **`docs/FABLE.md`** for the Fable operating layer (effort,
> long-run behavior, subagents, memory, and the hard rule: never instruct the model to echo its reasoning
> into responses — it triggers a `reasoning_extraction` refusal). On any `stop_reason: "refusal"`, fall
> back to Claude Opus 4.8 for that call. Record cross-run lessons in **`tasks/lessons.md`** and reference
> it at the start of each slice.

> **Repo location:** `D:\black-meridian` (moved off C: on 2026-07-01). Remote: `EsimOmni/black-meridian`
> (private). Godot 4.7 binary: `D:\Godot\Godot_v4.7-stable_win64.exe` (moved off C: 2026-07-02).

## What this is

A single-player **real-time-with-pause mafia empire management strategy game** for Windows / Steam,
built in **Unreal Engine 5.8.2** (`D:\black-meridian-ue`). Original IP. *This repo holds the
earlier Godot 4.7 build, now the behavioral oracle — see the banner above.* You play **Aiko Velora, the Resolver** — the ruling
Meridian Compact's fixer in *Black Meridian*, a rain-soaked interspecies metropolis. The player is a
**problem architect**, not a general or a shooter: "I decide which problem becomes somebody else's war."

The game is inspired by the *structure* of a TV crime drama but is 100% original expression — see
the IP boundary rules below; they are non-negotiable.

## The one decision that governs everything (brief §1)

> **The strategic simulation is authoritative. The city is a visual proxy.**

We simulate district ownership, economy, relationships, police pressure, rival intent, crises and
narrative consequences. We **visualize** those through traffic, crowds, weather, signage and district
deterioration. We never build a city-scale life simulation. The cinematic first-person (Gaussian-splat)
scenes follow the same rule: small, controlled spaces for emotional weight — never a second open-world game.

Corollary: **never put authoritative simulation state inside presentation.** In Unreal that means
`BMSim` subsystems and `BMCore` types own it, never an Actor, Level or Widget. (In the Godot oracle it
was the `src/` autoloads — same rule, different nouns.)

## Current status

> **Phase: UNREAL REBOOT. S0 complete (2026-09-18), S1 not started.** See the banner at the top of
> this file — active development is in `D:\black-meridian-ue`, not here.

**S0 — repository bootstrap: PASSED, 11/11.** Evidence: `D:\black-meridian-ue\Docs\gates\S0.md`.
Unreal 5.8.2 (CL 56702186) · five modules (`BMCore` with **no Engine dependency** — that absence is
the determinism wall — plus `BMSim`/`BMGame`/`BMUI`/`BMEditor`) · LFS committed before any asset ·
editor build succeeded with 0 warnings · `BM.Smoke` passed · Shipping package built. S0 also produced
**four corrections to the planning package** (D-01's premise, the `.gitattributes` globs, the
non-existent glTF Importer plugin, the .NET 10 build path), all folded back in at `6fb3c97`.

**Next: S1 — Determinism Core.** Gate: *every hash golden vector matches exactly.* Two prerequisites —
extract the golden vectors by running this Godot oracle, and (recommended) the IDE half of D-01.

**Open decisions:** D-01 half-done (NetFx SDK installed; VS 2022 Community IDE still missing) ·
**D-02 / D-10 OPEN** — character identity + production route, resolved before S12; do **not** assume
`OMNI_CERT_AIKO_2026_0001_v1.0.0` represents Aiko Velora · D-07 splats excluded from the vertical
slice, revisitable only after Gate B.

### Godot line — final state (archive, for oracle use)

The Godot build reached **Month 4** and ends at **P20** (`de05ef9`): settings panel, rebindable input,
audio cues, onboarding nudges — 24/24 unit tests, clean import, boot smoke exit 0. Everything through
Month 2 (P05–P11 Night-Cycle loop, gate-passed "fun with cubes"), Month 3 (P12–P14 kit + VFX +
landmarks) and Month 4 (P16 NarrativeDirector, P17/P18 cinematic seam, P19 endings) is committed and
probed. Splat benchmark resolved SPLAT_OK (542k @ 483 fps), but **D-07 excludes splats from the Unreal
vertical slice**. Deferred-and-now-moot Godot backlog: P05b, P06b/c, P07b/c, P08b, P10b, P19 polish.


<details>
<summary><b>GODOT-ERA DOCTRINE (historical) — Godot architecture &amp; autoloads</b>  ·  <i>click to expand; this describes how the ORACLE was built, not current practice</i></summary>

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


</details>

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

<details>
<summary><b>GODOT-ERA DOCTRINE (historical) — Splat kill criterion (resolved; D-07 excludes splats from the UE slice)</b>  ·  <i>click to expand; this describes how the ORACLE was built, not current practice</i></summary>

## Splat risk (brief §14, §7.7) — the kill criterion

Godot has no built-in Gaussian-splat support; we rely on the community **GDGS** plugin. Month 1
includes a benchmark. **If 500k splats can't run acceptably on the target desktop, switch to the
mesh provider immediately — do not postpone the decision.** Use Marble's high-quality GLB +
collider GLB as the `MeshWorldProvider` fallback behind a `CinematicWorldProvider` interface.
Do NOT migrate the whole project to Unity to preserve one cinematic technique.


</details>

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
- **PROVEN 2026-07-08 — local Hunyuan3D 2.1 does hero geometry AND texture end-to-end, zero credit,
  on the 16GB 5060 Ti with no OOM.** `Mesh_Generation` → 200k-tri GLB, `Mesh_Texturing` → baked PBR
  (1024² baseColor + metallicRoughness, per-vertex UV) in ~2 min. Verified on the hybrid alien tower:
  hero-quality, faithful to the concept. **Implication: for a hero where a concept image beats
  box-modelling, the DEFAULT is local Hunyuan (geometry+texture) — spend Magnific/Meshy/Tripo credit
  ONLY if the local output fails a specific quality bar the paid tool provably clears.** Requires the
  reference be a transparent CUTOUT (rembg), never flat RGB — flat RGB gives a bas-relief, not a volume.
  Adapter: `tools/pipeline/hunyuan.py` (ComfyUI backend port 7821, env `OMNI_COMFY_URL`).
- **PROVEN 2026-07-10 — the hero image→3D pipeline for an ORGANIC + HARD-SURFACE hybrid (the alien
  tower).** When a single-view Hunyuan mesh comes out wrong, DON'T iterate the same tool blindly — the
  failure is structural and each stage below fixes a specific, diagnosed cause. This is the default
  recipe now for any hero where the concept mixes organic sculpt with architectural/hard-surface
  massing, or is tall-and-thin:
  1. **Root-cause first, match the tool to the sub-problem.** Single-view image→3D is strong on
     organic/sculpted form and WEAK on hard-surface (flat walls, sharp edges, windows) and on tall
     narrow verticals — it squashes the body and blurs architecture. Naming the failure mode beats
     re-rolling the same job.
  2. **Fix PROPORTION in 2D, before 3D.** Re-interpret the locked concept into a proportion-correct
     image with the **Magnific web runner** (`personax/tools/concept-campaigns/magnific/image_runner.py`,
     JSON brief, ref = the concept). **Seedream 5 Lite** (∞, free, ref-upload works in the runner) is
     the reliable ref-consistent model; Nano-Banana's ref-upload UI currently hangs the runner
     (`counter stayed ''`) — use Seedream. Free (unlimited tier), NOT the credit-metered MCP.
  3. **Kill the shadow — cast shadow becomes SLAB geometry.** The #1 cause of "relief/slab" Hunyuan
     output is the input's ground/drop shadow surviving the cutout; Hunyuan reads the grey shadow as
     volume. Prompt the image on a **pure solid WHITE background, floating, NO cast/drop/ground shadow,
     product-shot isolation** so a simple white-threshold alpha cuts perfectly. (Grey studio bg → the
     shadow blends in and survives; white bg → clean alpha.)
  4. **Single-view beats native multi-view for this.** `Hunyuan3Dv2ConditioningMultiView`
     (front/left/back/right → shape) EXISTS in the ComfyUI install but produced an unusable slab on the
     tower; the proportion-corrected single FRONT view through `Mesh_Generation.json` gave a proper
     volume. Try multi-view only if you have a specific reason; default to the best single clean view.
     (The `Hy3D*MultiViews*` nodes are for TEXTURING, not shape — they do NOT fix proportion.)
  5. **Delegate the mechanical rest to Codex** (ChatGPT-billed, zero credit): local Hunyuan texturing
     (`Mesh_Texturing.json`) → Blender pass — split the organic crown onto its own emissive material
     (measure the Z transition, don't hardcode), base-center the pivot, export the game GLB.
  6. **Godot glTF gotcha — metallic-mirror blowout.** Hunyuan's glTF ships `metallicFactor=1.0` + an
     ORM map, so Godot builds a metallic mirror and the HDRI/glow blows the mesh to WHITE in-scene
     (this, NOT the texture, was the "white tower"). `DistrictLandmarks._kill_mirror_keep_emission`
     drops metallic + the ORM channels while PRESERVING the mesh's own baked crown emission — the mesh
     self-lights, nothing crosses the glow threshold. Emission belongs in the GLB (Blender split), not
     injected code-side.
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
- **Magnific image→3D (MCP, credit-metered — see `docs/image-to-3d-tool.md`).** An alternative
  asset-entry path: an approved concept image → GLB (Trellis 2 / Tripo). For **low-volume hero /
  organic** geometry where a concept image beats box-modeling; grid-tile kit modules stay on
  Codex-Blender (image→3D can't guarantee the grid contract). Two hard rules:
  1. **MCP always charges — unlimited does NOT apply** (`unlimitedAppliesHere:false`). Real
     probed costs: Trellis 2 = 610/730/850 cr @512/1024/1536 (**exact**); Tripo v3.1 = 580
     no-tex / 1160 detailed-tex (variable); Tripo P1 = 580. Default first-pass = **Trellis 2
     @512 (610 cr)**; texture is deferred (doubles Tripo cost). **Model choice is a USER
     decision** — surface the real cost + certainty and get a yes before any paid generate.
  2. **Does NOT bypass the gates.** Raw output is provisional: mandatory Blender cleanup (retopo,
     base-center pivot, trim-sheet UV, LOD0/LOD1, collider) → `GLBValidator` → Godot test.
- Total targeted external spend for the 6-month slice: ~$55–90 (Sketchfab free tier adds $0).

## Agent roles — who does what (updated 2026-07-04)

Three agents work this repo. Roles are not interchangeable — pick by task shape, not availability.

- **Claude (Fable 5, `claude` CLI) — the architect / head.** Owns brief-critical design, IP §2
  judgment, splat-vs-mesh kill call, deterministic-sim invariants, cross-slice decisions, and
  anything that changes the game's shape. Reads this file + the brief PDF as scripture.
  Coordinates the task queue at `docs/tasks/gemini/` — writes briefs into `inbox/`, verifies
  reports from `done/` before advancing.
- **Gemini (3.5 Flash default, Antigravity in-workspace) — the operator / hands.** Executes
  well-scoped briefs from `docs/tasks/gemini/inbox/`, runs PowerShell/MCP tools, routes work
  to Codex/Claude via the `claude-bridge` skill (source at
  `docs/tasks/gemini/skills/claude-bridge/SKILL.md`; Gemini installs it as an Antigravity
  `/claude` workflow). Default = Flash for everything. Escalate to **Gemini 3.1 Pro** only for:
  (a) full brief PDF cross-section synthesis, (b) subtle determinism-bug diagnosis where the
  cause isn't obvious, (c) after Flash failed the same brief twice, (d) a direct hard
  analytical question aimed at Gemini itself (not a routing call). Everything else = Flash.
- **Codex (`codex exec`, ChatGPT-billed) — the little brother.** Mechanical multi-file edits,
  batch vision triage (render folder review, frame drift check), "where is X" searches,
  BlenderMCP (port 9876) and godot-ai MCP driving. Called by either Claude or Gemini for
  token-heavy grunt work — never for architectural decisions. See the global `CLAUDE.md`
  vision/QA delegate doctrine for command shapes and hard-won gotchas.

### The bridge protocol (`@gemini:` prefix)

Cem talks to Gemini through Antigravity; Gemini talks to Claude via
`claude -r <session-id> "@gemini: ..."` — always `-r` (specific session), never `-c` (last
session, drifts across windows). When you (Claude) see `@gemini:` at the start of a query,
the message is coming through the operator bridge — before answering, read
`docs/tasks/gemini/QUEUE.md` for the active pointer and `docs/tasks/gemini/README.md` for the
full loop mechanics + brief/report schemas. The queue is authoritative; don't answer from
memory. The coordinator-session ID that owns the queue is recorded at the top of `QUEUE.md`;
if it goes stale, update it there.

<details>
<summary><b>GODOT-ERA DOCTRINE (historical) — GDScript conventions &amp; the godot-ai MCP rail</b>  ·  <i>click to expand; this describes how the ORACLE was built, not current practice</i></summary>

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


</details>

<details>
<summary><b>GODOT-ERA DOCTRINE (historical) — Godot headless verification commands</b>  ·  <i>click to expand; this describes how the ORACLE was built, not current practice</i></summary>

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


</details>

<details>
<summary><b>GODOT-ERA DOCTRINE (historical) — Running the Godot build</b>  ·  <i>click to expand; this describes how the ORACLE was built, not current practice</i></summary>

## Running

Open in Godot 4.7 (desktop shortcut "BLACK MERIDIAN (Godot)" or `--editor --path .`). Main scene =
`scenes/bootstrap/bootstrap.tscn`. In-game: SPACE pause/resume, X cycle speed, WASD pan, wheel zoom,
click a venue to inspect.


</details>
