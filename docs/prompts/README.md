# Build Prompt Series — OMNI: BLACK MERIDIAN

This is the ordered list of **scoped delivery slices** for building the game, derived from the brief's
6-month roadmap (`../OMNI-BLACK-MERIDIAN-brief.pdf` §19). Each prompt is self-contained: hand it to
Claude Code (or Codex) and it knows exactly what to build, what's in scope, and how to verify.

## How to use

- Work them **in order**. Each assumes the previous slices are merged and green.
- Treat each as one deliverable. Don't skip ahead into a later month's automation.
- **Honor the gates.** The whole point is to prove the mechanic before producing assets.
- After each slice: run the headless checks in `CLAUDE.md` ("Verify before done"), then commit.
- Naming: `PNN-short-title.md`, two-digit, sequential.

## The roadmap gates (do not bypass)

| Gate | Condition |
|------|-----------|
| Month 1 | A 15-minute greybox loop is playable. **Kill criterion:** if 500k splats can't run on target, switch to mesh provider — decide now, don't postpone. |
| Month 2 | A full 25–30 min Night Cycle is **fun with cubes**. If not fun without final art, do NOT enter asset production. |
| Month 3 | Repeatable asset delivery proven (1 building, 1 prop, 1 vehicle, 1 char anim) without reinventing the pipeline each time. |
| Month 4 | The splat cinematic **changes persistent strategic state** and survives save/load. A pretty but non-persistent scene fails. |
| Month 5 | 3 external players finish the slice unaided and can explain how money is cleaned, why heat rose, why the rival acted, why the loyalty crisis happened. |
| Month 6 | Steam-quality vertical slice; clean Windows build launches, saves, loads, completes a Night Cycle, enters/exits the cinematic, reaches an ending, no critical defects. |

## Status legend

- ✅ done · 🔨 in progress · ⬜ not started

## Series

### Month 1 — Architecture & risk spikes
- ✅ **P00** — Repo + data model + GameState + TimeService + EconomyService + greybox + camera + HUD (done; the initial commit)
- ⬜ **P01** — GDGS splat technical spike + `CinematicWorldProvider` interface + mesh fallback (the kill criterion)
- ⬜ **P02** — SaveService: save/load the full GameState across transitions
- ⬜ **P03** — Fixer-job lifecycle skeleton (Intake → Preparation → Intervention → Cover-up), one placeholder job
- ⬜ **P04** — Month-1 gate: a 15-minute greybox loop, end to end

### Month 2 — Complete core loop
- ⬜ **P05** — Rackets/fronts/laundering UI + assign operatives + fund operations
- ⬜ **P06** — Heat + Evidence chain prototype (named investigations, removable links)
- ⬜ **P07** — RivalDirector: utility AI (action scoring, imperfect info, memory)
- ⬜ **P08** — JobDirector: systemic fixer jobs generated from sim state + resolution dimensions
- ⬜ **P09** — Night Cycle phase machine (Council → Operations → Crisis → Reckoning)
- ⬜ **P10** — RelationshipService: motive network + telegraphed betrayal
- ⬜ **P11** — First-pass UI theme + month-2 gate (fun with cubes)

### Month 3 — Art pipeline & character proof
- ⬜ **P12** — Glass Wharf art-direction master + modular building kit pipeline (Blender→GLB→Godot)
- ⬜ **P13** — Rain/wet-surface VFX + traffic + crowd proxy (MultiMesh, spline traffic)
- ⬜ **P14** — Aiko canonical references + 4 character base models + shared animation prototype + roster screen
- ⬜ **P15** — GLB import-validation tooling + asset naming/folder standard

### Month 4 — Narrative & cinematic integration
- ⬜ **P16** — NarrativeDirector + 3 authored jobs + complete evidence chain + first loyalty crisis
- ⬜ **P17** — Final Marble cinematic world + collider + anchors.json + Aiko first-person controller
- ⬜ **P18** — Splat sequence wiring: pause→checkpoint→load→interact→write consequences→resume (must persist)

### Month 5 — Content completion & polish
- ⬜ **P19** — Complete vertical-slice narrative + final rival behavior + city-state visual variations
- ⬜ **P20** — Onboarding, settings, rebinding, subtitles/text-size, performance tiers, 500k/2M toggle, sound mix
- ⬜ **P21** — Playtest gate: 3 external players explain the systems unaided

### Month 6 — Steam-quality vertical slice
- ⬜ **P22** — Polished 45–60 min build + Windows export + crash/log + smoke-test suite + regression checklist
- ⬜ **P23** — Steam store assets + honest gameplay trailer + public demo config + license/provenance manifest
- ⬜ **P24** — Final acceptance pass (brief §18 criteria) + delivery package
