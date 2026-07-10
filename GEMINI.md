<!-- This file mirrors CLAUDE.md as the repo doctrine, PLUS a Gemini-only operator section at the very bottom ("## Gemini operator layer — delegating to Codex and Claude"). Keep the mirrored body in sync with CLAUDE.md; the Gemini-only section is intentionally NOT in CLAUDE.md/AGENTS.md/CODEX.md and must not be synced away. -->

# CLAUDE.md — OMNI: BLACK MERIDIAN

Guidance for Claude Code (and any AI agent) working in this repository. Codex, Gemini, and other agents
read `AGENTS.md` (and their respective synced mirrors `CODEX.md` and `GEMINI.md`). The authoritative design + production spec is
**`docs/OMNI-BLACK-MERIDIAN-brief.pdf`** — read it before any non-trivial change.

> **🎯 READ `docs/NOW.md` FIRST — every session, before anything else.** It is the LIVE state:
> what we'''re doing right now, the next step, open decisions, key files for the active phase. This
> file holds the permanent rules; `NOW.md` holds the current situation. The "Current status"
> section below is a coarse milestone marker and can lag — `NOW.md` is the source of truth for
> "where did we leave off." **After finishing any slice/commit, UPDATE `docs/NOW.md`** (push the
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

### Interaction Protocol with Claude CLI

When communicating with Claude Code via CLI commands:

- **Prefix with `@gemini:`**: Every message you send Claude starts with `@gemini:`. That prefix tells Claude the query is coming through the operator bridge and to read `docs/tasks/gemini/QUEUE.md` before answering.
- **Use `-r <session-id>`, NOT `-c`** (updated 2026-07-04). `-c` grabs "the last session", which drifts across Antigravity windows and other Claude launches — the query lands in the wrong chat. Use `-r <full-session-id>` to hit the specific coordinator chat Cem picked. The `claude-bridge` skill (`docs/tasks/gemini/skills/claude-bridge/SKILL.md`) does this for you: it lists the JSONL session files under `C:\Users\User\.claude\projects\d--black-meridian\` sorted by last-modified, Cem picks one, you send with `-r <that-id>`. The coordinator-session ID is also recorded at the top of `QUEUE.md`.
- **Requesting the Next Task**: Once Cem picks the chat (via `/claude` slash or the skill), send `claude -r <id> "@gemini: bir sonraki taskım ne?"` — Claude reads the queue and points you at the active `QUEUED` brief in `inbox/`.
- **`-c` fallback**: only if you know for a fact only one Claude session for this repo has been touched recently. Prefer `-r`. Always.

### The shared task queue — `docs/tasks/gemini/`

The delegation loop is **file-based and asynchronous**. Both you and Claude read/write this folder:

```text
docs/tasks/gemini/
  QUEUE.md                  ← the ledger (one row/task, status, links, Active pointer)
  README.md                 ← the full protocol + brief/report schemas — read it once
  inbox/TASK-00X.md         ← Claude writes the brief (task spec) here
  done/TASK-00X-report.md   ← YOU write the outcome report here when finished
```

Your side of the loop:

1. `claude -c "@gemini: taskım ne?"` → Claude points you at the active `QUEUED` brief in `inbox/`.
2. Read the brief. Flip its `QUEUE.md` row to `IN_PROGRESS`. Do the work per its **Verify** steps —
   stay in scope (brief §12 gates, minimal footprint). Sub-delegate mechanical/vision parts to Codex
   only if the brief's **Delegation hint** allows it.
3. Write `done/TASK-00X-report.md` per the report schema (Outcome / What changed / **Verify result with
   real output, not claims** / Deviations / Follow-ups). Flip the row to `DONE`.
4. `claude -r <coordinator-id> "@gemini: TASK-00X bitti, sıradaki?"` → Claude verifies your report
   independently, then queues the next brief. If it doesn't hold up, Claude re-opens the task with a
   correction — expect that.

### Model routing — Flash vs Pro FOR THIS REPO (updated 2026-07-04)

You (Gemini) have two tiers: **3.5 Flash** and **3.1 Pro**. In this repo your job is *operator*, not
*architect* — the mimari kararları Claude/Cem verir. So **Flash is the default for ~95% of what you
do here.** Do not silently step up to Pro on Flash-shaped work — it costs more and doesn't help.

**Stay on Flash for (this is nearly everything you do here):**

- Running the `claude-bridge` skill (listing sessions, routing via `-r <id>`, sending prefixed messages).
- Executing a brief from `docs/tasks/gemini/inbox/` when it's well-scoped (a single-file edit, a new
  test, a small script, a well-defined GDScript slice like P08b-style additions).
- Flipping `QUEUE.md` rows, writing reports into `done/`.
- PowerShell shell work — `codex exec` invocations, dosya okuma/yazma, `claude -r ...` calls.
- MCP tool orchestration — BlenderMCP (port 9876), godot-ai MCP, chrome-devtools MCP.
- Reading a headless Godot log/grep result and declaring "clean" or "not clean".
- Deciding whether to sub-delegate a chunk to Codex — the routing call itself is Flash.
- Concept-image / render-folder triage → **actually delegate this to Codex** (ChatGPT-billed, better
  vision for batch), don't burn Gemini tokens on it.
- Mechanical multi-file renames / format fixes → **also delegate to Codex** by default.

**Escalate to Pro ONLY in these four cases:**

1. **Full brief PDF cross-section synthesis** — e.g. Cem asks "does §7 economy contradict §12 gates?"
   Long-context reasoning, Pro's home turf (128k retrieval Pro 84.9 vs Flash 77.3).
2. **Subtle determinism-bug diagnosis** — sim gives different results on the same seed and the cause
   isn't obvious after one probe. Pro **for the diagnosis**; drop back to Flash for the fix once the
   root cause is identified.
3. **Flash failed the same brief twice** — hard eskalasyon kuralı; don't loop Flash a third time on
   the same problem, escalate.
4. **A direct hard analytical question aimed at you** — Cem asks Gemini itself for an opinion on
   something like "is the P06b evidence chain math correct, can the chain break?" This is analytical
   depth, not a routing call.

**Never Pro for**: architectural decisions (those go to Claude), IP §2 judgment, splat-vs-mesh kill
call, or anything Cem/Claude has already decided. Pro is for depth on your own analytical work,
not for second-guessing the architect.

One-line mental model: **you are the hands, Flash is your default speed. Claude is the head.**
