# P22 — Polished build + Windows export + crash/log + test suite

**Month:** 6 · **Brief:** §18 (technical acceptance), §19 Month 6 deliverables

## Why

Turn the slice into a shippable, robust Windows build with the QA scaffolding a commercial release needs.

## Scope

1. **Polished 45–60 min build** of the vertical slice.
2. **Windows export** (Godot export preset) → a clean build that launches **without the editor installed**.
3. **Crash + log collection** + version display in-game.
4. **Complete smoke-test suite** (`tests/smoke/`): a full Night Cycle passes automated smoke; enter/exit
   the cinematic; save/load across all major transitions; **no missing GLB dependencies**; no critical
   material/skeleton errors.
5. **Regression checklist** (`docs/regression-checklist.md`).
6. Performance: city view hits target; the splat scene meets the fallback threshold or switches to mesh.

## Verify (brief §18 technical criteria)

- Clean Windows build launches, saves, loads, completes a Night Cycle, enters+exits the cinematic, reaches
  the ending — on a machine without Godot installed.
- Smoke suite green; deterministic systems' unit tests green; zero missing-dependency / skeleton errors.
