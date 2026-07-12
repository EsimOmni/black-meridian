# Month-4 gate note — cinematic persistence (closed 2026-07-12, pending Cem feel session)

**Gate condition (brief §19):** "The cinematic **changes persistent strategic state** and
survives save/load. A pretty but non-persistent scene fails."

**Verdict: PASSED on evidence** (feel session with Cem pending — that session judges taste,
not the gate condition, which is proven headless below).

## Evidence

| Claim | Proof |
|---|---|
| The confrontation writes persistent state | `test_reveal_persistence_p17b` — reassure inside the scene raises trust/shared, spends clean capital, flips motive_revealed; walk-away writes nothing |
| The crime-scene writes persistent state | `test_crime_scene_persistence_p17c` — remove-evidence burns the real case via `EvidenceMath.remove_case`; leaving writes nothing |
| Consequences survive save/load AFTER the scene | both suites: save→scramble→load→state intact |
| The sequence survives save/load BEFORE the scene | both suites: save mid-telegraph → load → enter on loaded state → consistent |
| Entering checkpoints the campaign | `test_cinematic_checkpoint_p18` — both `enter()` paths write `user://saves/checkpoint.bmsave`; loading it restores pre-scene cash/tick/narrative flags |
| The authored chain persists across loads | `narrative_probe` — mid-chain + final save/load byte-identical, verdict NARRATIVE CHAIN CLOSES |

## What the world is (ship-first)

`CinematicWorldProvider` seam (the P01 deferred interface, now paid): default =
`MeshWorldProvider` — an $0 8×6 m wharf back-room (primitives + existing CC-BY props, one
shadowed sodium work-lamp). `SplatWorldProvider` keeps the GDGS route (SPLAT_OK, P01) behind
the same contract; a captured splat world later is a one-flag swap. Verified by screenshot
under the real bootstrap lighting (`tools/validation/cinematic_view_probe.tscn`).

## Known trims (ship-first, not gate failures)

- **"Plant an object" verb** (brief §6 pillar 4 lists plant/remove): only *remove* exists
  (crime scene). Plant enters only if a P19 authored beat needs it.
- Actors are greybox proxies (capsule/crate) — by design; characters are 2D portraits.
- One room serves both sequence types (brief §12.3 allows exactly one cinematic space).

## 🎮 Cem feel session (pending)

10–15 min: play until a betrayal telegraph or a crime-scene offer appears → walk in →
inspect/act/leave → confirm the return to the city feels clean and the consequence shows.
