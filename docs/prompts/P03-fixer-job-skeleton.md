# P03 — Fixer-job lifecycle skeleton + one placeholder job

**Month:** 1 · **Brief:** §7.5 (Fixer Job System), §5.1 (commitment step)

## Why

The fixer job IS the core verb of the game ("problem architect"). Month 1 needs ONE job that runs the
full four-stage lifecycle end to end, even with placeholder content, so the loop has a *decision*, not
just passive income.

## Scope

Model the four-stage structure (brief §7.5) as data + a lightweight director:

1. **Data** (`src/core/job_data.gd`, typed Resource):
   - origin (failed racket / witness / rival provocation / ...), apparent problem, involved character ids,
     deadline (in ticks), known evidence, visible stakes (some info intentionally missing).
   - allowed preparation actions, allowed intervention approaches, allowed cover-up choices (brief §7.5).
2. **`JobDirector`** (`src/jobs/job_director.gd`): holds active jobs, advances stages, resolves outcomes.
   - Stage flow: **Intake → Preparation (≤3 actions) → Intervention (one approach) → Cover-up (one story)**.
   - **Resolution is multi-dimensional**, never binary (brief §7.5): objective achieved, evidence
     generated, collateral damage, operative injury, rival suspicion, public fear, relationship change,
     new leverage, delayed consequence. Apply effects back into GameState (cash, heat, relationships).
3. **One authored placeholder job** in `data/jobs/` (or in code for now): e.g. "Intercepted shipment at
   the Cargo Terminal" tied to `gw_contraband`. Wireable through all four stages.
4. **Minimal job UI**: a panel that shows Intake, lets the player pick prep actions + an approach +
   a cover-up, then shows the resolution dimensions. Greybox-grade; real UI later.

## Out of scope (do NOT build yet)

- Systemic job generation from sim state (that's P08, Month 2).
- The cinematic "personally intervene as Aiko" splat path (that's Month 4 / P17–P18).
- Tactical anything. There is no combat (brief §6 pillar 1).

## Verify

- Unit test: a job advances through all four stages and applies at least two resolution dimensions to
  GameState (e.g. dirty cash change + a relationship change). Headless, exit 0.
- Manual: the placeholder job is completable in-editor and its outcome shows in the HUD.
