# Lessons — BLACK MERIDIAN

Cross-run memory (the Fable memory-system pattern, see `docs/FABLE.md`). **Reference this at the start of
each slice.** One lesson per entry: a one-line summary, then why it mattered. Record corrections AND
confirmed approaches. Don't duplicate git history or the brief; update an existing entry rather than adding
a duplicate; delete entries that turn out wrong.

---

## Setup / environment

### Godot 4.7 binary lives at `D:\Godot\` (moved off C: 2026-07-02) — the Downloads copy was broken
The `Downloads\Godot_v4.7-stable_win64.exe` is a *directory* holding only the 198KB console launcher; the
real ~170MB editor was missing. Downloaded 4.7-stable from GitHub, extracted; the binary now lives at
`D:\Godot\Godot_v4.7-stable_win64.exe` (+ `_console.exe`) — the old `C:\Users\User\Godot\` path is gone.
Use `D:/Godot/...` for all headless runs. Desktop shortcut "BLACK MERIDIAN (Godot)" opens the project.

### Repo is on the D: drive: `D:\black-meridian` (moved off C: 2026-07-01)
The project was created under `C:\Users\User\Desktop\vs_code\black-meridian`, then moved to `D:\black-meridian`.
Git remote + history moved intact. If a path lookup fails on C:, it's on D:. Remote: `EsimOmni/black-meridian`
(private). Commit direct to master + push; no branches/PRs.

## GDScript / Godot

### Split testable math out of autoload scripts — statics on an autoload script don't resolve via preload
`EconomyService` is an autoload; calling its `static func`s from a test via `preload(...economy_service.gd)`
failed ("Nonexistent function") because the preloaded const resolves to the singleton, not the script class.
Fix: put pure formulas in a separate `class_name`'d RefCounted (`EconomyMath`) that both the service and the
test import. Rule: **any unit-testable logic goes in a `class_name` helper, never inside an autoload.**

### Headless verify recipe (the "done" gate)
`--import` (registers scripts, catches parse errors) → `-s tests/unit/<t>.gd` (exit 0 = pass) →
`--quit-after 120` + grep for `SCRIPT ERROR|ERROR:|Nonexistent` (empty = clean boot). A new `class_name`
script needs a fresh `--import` before tests see it.

## Pipeline / asset production (YouTuber-pipeline doctrine, adopted 2026-07-02)

### Concept first, then split into assets — never generate assets piecemeal
Generate a full concept image (keyframe/scene) for a location or set, approve the look, THEN split it into
individual assets (buildings, props, characters) generated to match that concept. One coherent art
direction; "does this asset fit?" becomes a mechanical check against the master instead of per-generation
taste-testing. Applies to P12+ (Glass Wharf art-direction master → modular kit) and all hero prop/char work.

### AI does ~90%, the human does the last 10% — budget the 10% deliberately
AI generates geometry/textures/code/first-pass everything; the human 10% is curation, Blender cleanup,
integration, taste. Don't automate the last 10% (that's where quality lives) and don't hand-do the first
90% (that's where time dies). Plan every asset task as 90/10 up front.

### Godot AI MCP is the Unreal-MCP equivalent — primary code/scene rail from P03 onward
The `godot-ai` MCP server (persistent editor integration: node/scene/script/signal/test tools) is this
project's equivalent of Unreal-MCP in the proven AI-game-dev pipelines. From P03 onward, prefer it for
creating scenes, wiring nodes/signals and attaching scripts — it validates against the live editor at write
time. Plain file edits remain fine for pure logic + unit tests (headless verify still the truth).

### Prefer ready plugins/templates over building from scratch
GDGS for splats, existing controller/camera templates, asset-library addons: adopt, then adapt. A maintained
plugin beats bespoke code for anything not core to the game's identity — the strategic sim IS core;
rendering/input plumbing is not.

### Drive Blender DIRECT over the BlenderMCP socket — skip Codex for asset production (2026-07-05)
Codex's BlenderMCP calls fail with `user cancelled MCP tool call` in non-interactive `codex exec` mode
(an approval-layer block — non-interactive can't answer the allow prompt; setting `approval_mode = "auto"`
on `get_scene_info` alone did NOT fix it, other blender tools still prompt), and Codex has a 4-hour quota
that runs out mid-task. **Instead drive Blender directly over its BlenderMCP TCP socket
(127.0.0.1:9876) with raw Python — no Codex, no MCP wrapper, no approval, no quota.** Send
`{"type":"execute_code","params":{"code":"<bpy python>"}}`, read back
`{"status":"success","result":{"executed":true,"result":"<stdout>"}}`; also supports `get_scene_info`
and `get_viewport_screenshot`. A Sonnet subagent (Bash → Python → socket) or the control tower itself
can model/LOD/collide/UV/export a whole asset this way. Use Codex only for vision *triage* (master-vs-render
gap analysis); the *driving* is cleaner direct. Proven end-to-end on the alien diplomatic tower hero.

### Green-by-claim is not green — re-run GLBValidator + eyeball the preview yourself (2026-07-05)
A producer subagent reported "SHIP, GLBValidator building gate pass" on the alien tower; the control-tower
re-run showed PASS: false (no UVs unwrapped — smart_project was skipped; a Blender default material leaked
onto the collider's empty slot → 4 materials > the 3-cap). The gate re-run caught a broken asset that would
otherwise have shipped. Rule: never accept an asset on the producer's claim — re-run the GLBValidator
(`tools/validation/validate_alien_tower.gd` pattern: `GLBValidator.validate_file(path, spec_for("building"))`)
AND read the preview against the master. Same discipline as the P06 mechanic line. Note the accepted-warn set
(matches warehouse_a): UV2-absent, draw_calls≤8, and the `_col` "no collision node" advisory (converts via the
`-col` import suffix) are all non-blocking.

## Godot AI MCP (the P03+ primary rail)

### An open editor CLOBBERS external project.godot edits — write settings through MCP `settings_set`
Editing project.godot on disk (new autoload, plugin enable) while the editor is open gets silently
reverted the next time the editor saves settings (e.g. `project_run(autosave=true)` / stop). The
JobDirector autoload and the gdgs plugin registration both vanished this way. Rule: with the editor open,
write ProjectSettings via `project_manage(op="settings_set")` — it updates memory AND disk in sync. Raw
file edits to project.godot are only safe with the editor closed. (Game *processes* read disk at launch,
so a run can look correct while the editor still holds — and later re-saves — stale settings.)

### `game_manage input_mouse` needs a motion event before button events land on UI
A bare button press/release at a coordinate does nothing; send `{event:"motion", position:...}` first to
move the pointer, then press+release. With that, full UI flows are drivable end-to-end (P03's job panel
was played through all four stages this way), and `get_ui_elements` gives exact button rects + texts —
better than screenshot-guessing for UI QA. Editor-side `recent_errors` can be stale/pre-run
(`recent_errors_may_predate_run: true`) — trust headless boot + the running game, not editor parse spam
from before a filesystem rescan.

### Editor-launched games eat the editor's debug shortcuts — F8 KILLS the game, F10 is swallowed
Binding quick-load to F8 made "load" terminate the process instantly with zero script error (F8 = the
editor's Stop Running Project shortcut, forwarded into the debug session); F10 events never arrive at all.
No SAVEDBG print ever ran — the process died before any game code. Rule: dev/debug bindings use plain keys
(F9 save + L load here); if a key "crashes" or "does nothing" with no log, suspect the editor shortcut
layer before suspecting the handler. Injected-key QA can also wedge the game loop via the debugger —
for save/load-class verification, a programmatic integration runner that instantiates the REAL bootstrap
scene (`tests/integration/bootstrap_smoke_runner`) beats key injection: same listeners, deterministic, CI-able.

### Save files use var_to_str, not JSON — float precision IS the determinism guarantee
A JSON round-trip truncates float digits, so save→load→same-tick→same-state fails in late decimals
(heat/motive floats drift from their never-serialized twins). `var_to_str`/`str_to_var` keep full float
precision and native StringName/Color/Vector2/typed-Dictionary keys, and `str_to_var` can't instantiate
objects (safe). Saves store the source of truth only; jobs store runtime state + are rebuilt from the
authored registry by id (`JobTemplates.by_id`; generated "gen@…" ids via `JobGenerator.rebuild`, whose
id encodes template + targeting — P08). Proven by `tests/integration/save_roundtrip_runner`
(byte-for-byte restore + deterministic replay + clean version refusal).

### Game-loop drivers that mutate state under other systems: bootstrap-wired node, NOT autoload
NightCycle (P09) advances GameState.phase every tick. As an autoload it would exist in EVERY unit-test
scene and silently advance phases under P05–P08 tests (test_rival_ai would break: phase would hit COUNCIL
gating and telegraphs would never open). As a bootstrap-wired `class_name` node it exists only in the real
game + its own test, which instantiates it explicitly. Rule: a driver whose _ready/tick changes shared
state belongs in the scene, not the autoload list, unless every test genuinely wants it running.

### Autoload→autoload signal wiring: connect deferred when the emitter loads later
Autoload singletons instantiate in project.godot order. JobDirector (`_ready` earlier) cannot touch
RivalDirector (registered later) inside its own `_ready` — the singleton node doesn't exist yet at
runtime, even though the identifier compiles. Pattern: `_connect_triggers.call_deferred()` in `_ready`;
by the first idle frame every autoload exists. Tests that rely on the wiring must
`await get_tree().process_frame` before emitting. (P08; will recur for P09/P10 directors.)

### Intent/window state lives ON the data Resource, not in the service node
FactionData carries the rival intent (P07); CharacterData carries the betrayal intent (P10,
`betrayal_ticks_until_land`, -1 = none). Payoff: the bootstrap-wired service stays stateless (survives
not existing in test scenes), SaveCodec picks the field up as a normal additive encode/decode
(`d.get(..., -1)`, SAVE_VERSION unchanged), and after a load the service just reads the restored
Resources — no rewiring. Rule: a telegraph→land window's state belongs on the entity it's about.

### Never park a test value exactly ON a float threshold
A betrayal-pressure setup summing to exactly the 1.4 gate (0.7+0.8+0.4-0.3-0.2) can land a hair under
in float64 and the telegraph never opens — a flaky-looking hard failure. Give boundary setups ≥0.05
margin on both sides (arm to 1.5, defuse to 1.2). Exact-boundary behavior gets its own dedicated test
with integers (see test_night_cycle's budget boundaries), never as a side effect of a scenario test.

### A probe POLICY can mask a working mechanic — check instrument thresholds against the latch's
P06d: the inspection latch re-arms only when combined < REARM (0.30), but the full-cycle probe's
policy unpaused rackets at 0.35 — heat flow resumed before re-arm, so inspection RECURRENCE was
physically unreachable no matter how right the game balance was (read as a mechanic failure, was an
instrument error; cost two probe runs). Two rules: (1) derive probe marks from the real service
constants (`EconomyService.HEAT_INSPECTION_REARM - 0.05`), never parallel literals; (2) a static
extremal policy (always-argMAX) cannot exercise a hysteresis loop — model the player's back-off
("answer quiet while the district cools") or the latch fires once per run and never again.

### GDScript `as` binds looser than `==` — `x == [...] as Array[T]` casts the bool
`restored.chosen_prep == [&"a"] as Array[StringName]` parses as `(x == [...]) as Array[...]` → parse
error "cannot convert bool". Pre-declare a typed var (`var expected: Array[StringName] = [...]`) and
compare against that.

## Splat / GDGS

### P01 kill-criterion verdict: SPLAT_OK — 542k splats @ 483 avg / 420 1%-low fps, 1080p, 5060 Ti
GDGS v2.2.0 (ReconWorldLab) renders 542,246 real capture splats ~8× above the brief's threshold on the
target GPU. `SplatWorldProvider` stays the default; mesh fallback is insurance only. Numbers + method:
`docs/prompts/notes/P01-splat-benchmark.md`. Bench scene: `scenes/cinematic/splat_bench.tscn` (self-quits,
prints BENCH_RESULT, saves a proof PNG).

### GDGS on Godot 4.7 needs the push-constant exact-size patch — re-apply on every plugin update
Stock GDGS pads push constants to 16 bytes; Godot 4.7 validates the exact per-shader block size
(upsweep 8B / spine 4B / downsweep 12B) → per-frame error storm, broken render, fake ~16 fps. Patched
`create_push_constant()` (no padding) + per-stage push constants in `_rasterize_state()`. If GDGS is ever
updated from upstream, re-apply or upstream this patch first — an "invalid" benchmark number from an error
storm looks like a real perf number if you don't grep the log for ERROR.

### Boot smoke: "RID ... leaked at exit" errors are PRE-EXISTING (since P14), not your slice
`--quit-after 120` prints ~15 DummyMaterial / 12 DummyMesh "leaked at exit" ERRORs. Verified on a clean
HEAD worktree (2026-07-04, during P06b): identical leaks with zero new code — they come from earlier
runtime-built city meshes (P14 kit assembler is the suspect), not from whatever slice you're verifying.
Compare against HEAD before blaming your change; a smoke regression means NEW lines beyond these. Fixing
the leak itself is a separate cleanup slice, not a drive-by.

### Windowed Godot benchmark runs: never pipe stdout through grep/head — write to a file
The first bench run "hung" for 4 minutes: parse errors kept the app alive on an empty scene while
`| grep | head` buffering hid every line. Run windowed benchmarks with `> file 2>&1`, then grep the file.
Also: GDScript strict typing — `Array[float].duplicate()` returns untyped `Array`; `:=` inference fails on
its elements (declare the type explicitly).

## Model / Fable

### Never instruct the model to echo its reasoning into the response (Fable refusal)
"show your thinking / explain your reasoning / think out loud in the response" → `reasoning_extraction`
refusal on Fable 5 → fallback to Opus, losing Fable's edge. Repo docs audited clean 2026-07-01; keep them so.

### On a `stop_reason: "refusal"`, switch that call to Opus 4.8
Fable's safety classifiers (cyber/bio/reasoning-extraction) don't apply to game-building, but if a refusal
ever hits, route that request to Opus 4.8 rather than fighting it.

## Hunyuan3D image→3D: arka planı MUTLAKA kaldır (2026-07-08)

**Sorun:** RGB concept'i (alpha yok) Hunyuan3D'ye verince düz bir KABARTMA (relief) çıktı —
tüm frame'i (arka plan dahil) obje sandı, yassılık oranı 0.11 (Y=0.22m).
**Kök neden:** `Hy3D21LoadImageWithTransparency` node'u alpha bekler; alpha yoksa arka planı
foreground'dan ayıramaz, sahnenin tamamını düz yüzeye bas-relief eder.
**Fix:** rembg ile arka planı kaldır → şeffaf PNG → tekrar üret. Yassılık 0.11 → 0.588
(hacimli 3D). rembg ComfyUI python_embeded'de kurulu:
`D:\AI\SwarmUI\dlbackend\comfy\python_embeded\python.exe -c "from rembg import remove..."`.
**Kural:** image→3D'ye HER ZAMAN şeffaf/cutout PNG ver, düz RGB değil. concept'i üretirken bile
nötr/sade arka plan iste + sonra rembg'den geçir.

## 2026-07-08 — "Mekanik" Blender temizliğini körlemesine devretme
Hero kule GLB temizliğini (decimate/pivot/export) başka chat/Sonnet'e verdim — "mekanik iş"
sandım. Sonnet decimate'i UV-aware yapmadı (silüet düz blob'a ezildi), texture'ı export'ta
kaybetti, re-import doğrulaması yapmadı → **hero çöp çıktı, tam re-do**. Ders: Blender asset
temizliği mekanik GÖRÜNÜR ama değil — decimate oranı + UV koruma + normal yönü + Godot Y-up
export birbirini ezen ince ayarlar. Kaynağı GÖREN (bağlamı taşıyan) yapmalı. Her adımda RENDER
alıp doğrula, export'u MUTLAKA re-import et (Sonnet bunu atladı). Doğru yol: plaka bisect+holes_fill,
UV-aware collapse decimate 200k→44k (30k değil — landmark için silüet > tri sayısı), recalc normals,
base-center pivot, uniform scale, convex collider, Draco OFF + yup + JPEG, re-import verify + render.
İkinci ders: Blender/editor'ın sert directional ışığındaki beyaz specular ≠ oyunun HDRI env'indeki
görünüm. Specular'ı Blender'da kovalama; asıl test oyun sahnesinde (orada biyolüminesan gibi okudu).
