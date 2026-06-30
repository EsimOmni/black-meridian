# P09 — Night Cycle phase machine

**Month:** 2 · **Brief:** §5.2 (the 30-minute loop)

## Why

The 30-minute loop is one **Night Cycle** of four phases. This is the dramatic container that makes a
single session feel like a complete episode (brief §5.2).

## Scope

A phase machine (`src/simulation/night_cycle.gd`) advancing through:

1. **Council** (3–5 min): review previous night, select a strategic priority, inspect family relationships,
   allocate clean cash, assign lieutenants, choose one district objective.
2. **Operations** (15–20 min): run 4–6 rackets/jobs (P08), react to rival moves (P07), manage heat/evidence
   (P06), secure/lose/destabilize venues, decide whether Aiko personally intervenes.
3. **Crisis** (5–8 min): a state-driven crisis forces a high-cost decision; possible transition to a
   cinematic splat scene (Month 4); one relationship changes materially; the city enters a new strategic state.
4. **Reckoning** (2–3 min): income + laundering resolve, institutional pressure advances, loyalty changes
   become visible, rival intentions update, next Night Cycle previewed.

## Design rules

- Phase transitions emit signals the HUD + city react to.
- After one Night Cycle the player should feel a complete dramatic episode occurred.
- Economic settlement happens at the phase boundary (brief §13.2 tick model), not only per-tick.

## Verify

- Integration test: a full Night Cycle runs through all four phases headless, settling economy at the
  Reckoning boundary and advancing the cycle counter.
- Manual: the four phases are legible and paced; the HUD shows the current phase.
