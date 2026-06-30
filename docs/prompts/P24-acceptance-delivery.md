# P24 — Final acceptance pass + delivery package (Month 6 gate)

**Month:** 6 (gate) · **Brief:** §18 (full acceptance criteria), §19 Month 6 gate

## The gate

> No critical defects. The build must launch, save, load, complete a Night Cycle, enter and exit the
> cinematic scene, and reach the ending on a clean machine.

## Scope — verify ALL acceptance criteria (brief §18)

**Gameplay**
- Complete Night Cycle playable; ≥2 viable strategies; rival AI responds to state; one betrayal/loyalty
  crisis causally understandable; economy/heat/evidence interact; ≥6 of 8 fixer jobs complete cleanly.

**Presentation**
- City reads active without menu overlays; rain/traffic/crowds/faction activity respond to state; 4
  character identities stable across portrait/roster/cinematic; splat transition coherent; UI readable
  at 1080p + 1440p.

**Technical**
- Save/load survives all transitions; deterministic systems unit-tested; full Night Cycle passes
  automated smoke; no missing GLB deps; no critical material/skeleton errors; city perf meets target;
  splat meets fallback threshold or switches to mesh; clean Windows build launches without the editor.

**Commercial**
- Store description matches the slice; trailer is real gameplay; all asset licenses recorded; character +
  title similarity review complete; crash reporting + version display present; known limitations documented.

## Deliverable

The **final vertical-slice delivery package** (brief §19 Month 6): the build, exports, smoke suite,
regression checklist, store assets, trailer, demo config, license/provenance manifest, performance report,
QA report, known-limitations record.

## Verify

- Walk the entire §18 checklist; every item passes or is documented as a known limitation.
- `docs/prompts/notes/P24-acceptance.md`: the signed-off checklist + the delivery package contents.
