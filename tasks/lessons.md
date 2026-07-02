# Lessons — BLACK MERIDIAN

Cross-run memory (the Fable memory-system pattern, see `docs/FABLE.md`). **Reference this at the start of
each slice.** One lesson per entry: a one-line summary, then why it mattered. Record corrections AND
confirmed approaches. Don't duplicate git history or the brief; update an existing entry rather than adding
a duplicate; delete entries that turn out wrong.

---

## Setup / environment

### Godot 4.7 binary lives at `C:\Users\User\Godot\` — the Downloads copy was broken
The `Downloads\Godot_v4.7-stable_win64.exe` is a *directory* holding only the 198KB console launcher; the
real ~170MB editor was missing. Downloaded 4.7-stable from GitHub, extracted, and moved the real binary to
`C:\Users\User\Godot\Godot_v4.7-stable_win64.exe` (+ `_console.exe`). Use that path for all headless runs.
Desktop shortcut "BLACK MERIDIAN (Godot)" opens the project directly.

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

## Model / Fable

### Never instruct the model to echo its reasoning into the response (Fable refusal)
"show your thinking / explain your reasoning / think out loud in the response" → `reasoning_extraction`
refusal on Fable 5 → fallback to Opus, losing Fable's edge. Repo docs audited clean 2026-07-01; keep them so.

### On a `stop_reason: "refusal"`, switch that call to Opus 4.8
Fable's safety classifiers (cyber/bio/reasoning-extraction) don't apply to game-building, but if a refusal
ever hits, route that request to Opus 4.8 rather than fighting it.
