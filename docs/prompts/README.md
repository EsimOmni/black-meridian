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
- 🔨 [**P01**](P01-splat-spike.md) — GDGS splat technical spike + `CinematicWorldProvider` interface + mesh fallback (the kill criterion) — **benchmark DONE, verdict SPLAT_OK** (542k @ 483 fps avg on 5060 Ti, see [notes/P01-splat-benchmark.md](notes/P01-splat-benchmark.md)); provider interface + fallback flag deferred to Month 4 (build with P17)
- ✅ [**P02**](P02-save-load.md) — SaveService: save/load the full GameState across transitions (done 2026-07-02; SaveCodec var_to_str format, version gate, F9/L quick keys, deterministic round-trip proven by `tests/integration/save_roundtrip_runner`)
- ✅ [**P03**](P03-fixer-job-skeleton.md) — Fixer-job lifecycle skeleton (Intake → Preparation → Intervention → Cover-up), one placeholder job (done 2026-07-02; JobData/JobLifecycle/JobResolution/JobDirector + "Intercepted Shipment" + job panel, unit-tested + played end-to-end via godot-ai MCP)
- 🔨 [**P04**](P04-month1-gate.md) — Month-1 gate: a 15-minute greybox loop, end to end (prepared 2026-07-02 — tuning + nudge + smoke test done; awaiting Cem's 15-min gate session, see [notes/P04-month1-gate.md](notes/P04-month1-gate.md))

### Month 2 — Complete core loop
- ✅ [**P05**](P05-rackets-fronts-ui.md) — Rackets/fronts/laundering UI: squeeze surfaced on HUD (overflow indicator), pause-a-racket + pressure-a-front verbs, interactive venue panel (done 2026-07-02; operative pool + buy-front → P05b)
- ✅ [**P06**](P06-heat-evidence.md) — Heat consequence loop closed: heat→disruption→income, slow decay, deterministic inspection beat @0.45 (done 2026-07-03; P04b net-axis debt resolved — no split; evidence chains → P06b, Central Pressure → P06c)
- ✅ [**P07**](P07-rival-ai.md) — RivalDirector: deterministic utility AI, PROBE/SABOTAGE, telegraph→land window (done 2026-07-03; noise/tie-break → P07b, other 9 actions → P07b+, memory → P07c)
- ✅ [**P08**](P08-job-director.md) — JobDirector: systemic fixer jobs generated from sim state — JobTemplates layer + pure JobGenerator, two deterministic triggers (rival sabotage → retaliation, delayed_consequence → follow-up), cadence gate ≤3 (done 2026-07-03; remaining 8 origins + template variety → P08b)
- ⬜ [**P09**](P09-night-cycle.md) — Night Cycle phase machine (Council → Operations → Crisis → Reckoning)
- ⬜ [**P10**](P10-loyalty-betrayal.md) — RelationshipService: motive network + telegraphed betrayal
- ⬜ [**P11**](P11-first-ui-month2-gate.md) — First-pass UI theme + month-2 gate (fun with cubes)

### Month 3 — Art pipeline & character proof
- ⬜ [**P12**](P12-building-pipeline.md) — Glass Wharf art-direction master + modular building kit pipeline (Blender→GLB→Godot)
- ⬜ [**P13**](P13-city-life-vfx.md) — Rain/wet-surface VFX + traffic + crowd proxy (MultiMesh, spline traffic)
- ⬜ [**P14**](P14-characters-roster.md) — Aiko canonical references + 4 character base models + shared animation prototype + roster screen
- ⬜ [**P15**](P15-asset-validation.md) — GLB import-validation tooling + asset naming/folder standard

### Month 4 — Narrative & cinematic integration
- ⬜ [**P16**](P16-narrative-authored-jobs.md) — NarrativeDirector + 3 authored jobs + complete evidence chain + first loyalty crisis
- ⬜ [**P17**](P17-cinematic-world.md) — Final Marble cinematic world + collider + anchors.json + Aiko first-person controller
- ⬜ [**P18**](P18-cinematic-integration.md) — Splat sequence wiring: pause→checkpoint→load→interact→write consequences→resume (must persist)

### Month 5 — Content completion & polish
- ⬜ [**P19**](P19-content-polish.md) — Complete vertical-slice narrative + final rival behavior + city-state visual variations
- ⬜ [**P20**](P20-onboarding-settings.md) — Onboarding, settings, rebinding, subtitles/text-size, performance tiers, 500k/2M toggle, sound mix
- ⬜ [**P21**](P21-playtest-gate.md) — Playtest gate: 3 external players explain the systems unaided

### Month 6 — Steam-quality vertical slice
- ⬜ [**P22**](P22-build-qa.md) — Polished 45–60 min build + Windows export + crash/log + smoke-test suite + regression checklist
- ⬜ [**P23**](P23-steam-store-demo.md) — Steam store assets + honest gameplay trailer + public demo config + license/provenance manifest
- ⬜ [**P24**](P24-acceptance-delivery.md) — Final acceptance pass (brief §18 criteria) + delivery package
