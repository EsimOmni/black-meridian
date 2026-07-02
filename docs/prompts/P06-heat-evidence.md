# P06 — Heat + Evidence chain prototype + Central Pressure

**Month:** 2 · **Brief:** §7.3 (Heat, Evidence, Institutional Pressure)

## Why

A single wanted-level meter is too shallow (brief §7.3). Three related systems give the player real
problems to architect around.

## Scope

1. **Local Heat** (already on DistrictData): formalize effects — extra patrols, lower customer traffic,
   disrupted operations (raise venue `disruption`), inspections, higher job difficulty. Heat decays slowly.
2. **Evidence Chains** (`src/core/evidence_data.gd` + `EvidenceService`): a named investigation linking
   people / vehicles / venues / incidents as nodes. Example: *Dock Shooting → getaway vehicle → witness
   → weapon supplier → compromised footage*. The player can **remove one link**, redirect the chain,
   discredit a witness, or frame another faction. Merely paying money should rarely delete a whole case.
3. **Central Pressure** (campaign-wide, the Civic Integrity Directorate): a slow-rising meter whose
   thresholds trigger asset freezes, coordinated raids, informant attempts, political defections,
   special investigators, endgame conditions. Must rise slowly enough that causality is legible.

## Design rules

- Pressure rises from accumulated exposure + failed jobs + uncontained evidence — never opaquely.
- Each evidence link should be *manipulable*, not just deletable.
- **Carried in from P04b:** `evidence_generated` and `operative_injury` are currently single *net*
  axes clamped -1..1 (negative = suppressed/mitigated — see `JobResolution.SIGNED_DIMENSIONS`).
  When this slice wires job outcomes into heat/evidence, decide whether to split each into separate
  production vs suppression axes; the net-axis clamp was the minimal Month-1 gate fix, not the model.

## Verify

- Unit test: building an evidence chain, removing a link, and confirming the chain's threat drops but
  isn't erased; central pressure advances from exposure over N ticks.
- Manual: heat visibly disrupts a racket's income; an evidence chain appears and is manipulable.
