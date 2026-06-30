# P05 — Rackets / fronts / laundering UI + operative assignment + funding

**Month:** 2 · **Brief:** §5.1 (commitment step), §7.2 (economy)

## Why

The economy already settles (P00). Month 2 turns it into a set of **decisions**: where to staff, what
to fund, what to launder, what to pause. This is the player's hand on the economic squeeze.

## Scope

1. **Operative pool**: the player faction has a finite operative count. Assigning operatives to a racket
   raises its `operational_staff` (→ more dirty income) but ties them up.
2. **Assignment UI** on the venue panel: +/- operatives, fund/upgrade an operation, pause a racket
   (temporarily stop earning to cut exposure — brief §7.2 economic-tension choices).
3. **Front control UI**: see laundering capacity vs current dirty overflow; buy/pressure a front.
4. **The squeeze, surfaced**: show the player when dirty cash exceeds safe laundering capacity (the
   intended tension, brief §7.2) — a clear "unlaundered overflow" indicator.
5. Spending uses the two currencies correctly (dirty for criminal ops, clean for upgrades/acquisitions).

## Out of scope

- Systemic job generation (P08). Rival reactions (P07). Real art (Month 3).

## Verify

- Unit test: assigning operatives raises dirty income next tick; pausing a racket zeroes its yield.
- Manual: a player can shift operatives, fund a front, and watch the overflow indicator respond.
