# ADR-0001 — Reboot OMNI: BLACK MERIDIAN in Unreal Engine

- **Status:** Proposed — awaiting Cem's approval
- **Date:** 2026-09-18
- **Deciders:** Cem (authority) · Architect (analysis)
- **Supersedes:** the engine decision in `docs/OMNI-BLACK-MERIDIAN-brief.pdf` §13.1
- **Related:** [00_EXECUTIVE_DECISION.md](00_EXECUTIVE_DECISION.md) · [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) · [10_RISK_REGISTER.md](10_RISK_REGISTER.md)

---

## Context

`[Verified from repository]` The Godot 4.7 implementation of Black Meridian is a working,
gate-passed, deterministic strategy game:

- Four consecutive milestone gates passed, each with a written evidence note.
- 24/24 unit tests pass; both integration runners pass (executed in this session).
- Two independent 1800-tick probe runs produced **byte-identical output** — determinism is measured,
  not asserted.
- The Month-2 feel verdict was *"fun, there's stress, very good."*
- The splat kill-criterion **passed**: 542,246 splats at 483 avg / 420 1%-low fps on the target GPU.

The brief's §13.1 engine decision is unambiguous and was correct on its own terms:

> *"Use Godot 4.7 Forward+. Do not reconsider Unity unless the Gaussian-splat technical spike fails
> and splat-native first-person sequences remain non-negotiable after testing the mesh fallback."*

The spike did not fail. On the brief's logic, the engine question was closed in Godot's favour.

**But the brief's reasoning addressed a question that has since changed.** §13.1 argues the game is
*"primarily UI, simulation logic, data, controlled 3D presentation, GLB assets, scripted cinematic
scenes"* — and for that product, Godot is the right engine. The brief also defines a fourth design
pillar, **"Walk through the consequence"** (§6), which is what makes the game more than a spreadsheet.

`[Verified from repository]` That pillar is the part the Godot build could not deliver. At every gate
it was trimmed:

| Intended (brief) | Shipped (Godot) |
|---|---|
| Constrained first-person dramatic spaces | An 8×6 m box room built from code primitives |
| Characters in the scene | Greybox capsule and crate proxies |
| Four identities stable across portrait, roster and cinematic | A 2D portrait roster; **no 3D cast at all** |
| Verbs: inspect, **plant**, remove, speak, stand, walk away | Inspect, remove, a single reassure, walk away |
| Distinct scene types (crime scene, confrontation, council) | One room serving both |

Each trim was individually correct for a solo studio shipping in Godot. Together they mean the
emotional payload the design exists to deliver is **asserted rather than experienced**.

---

## Decision

**Rebuild Black Meridian as a new Unreal Engine C++ project in a sibling repository
`black-meridian-ue`, as a clean-room re-implementation, treating the Godot repository as an archived
behavioral reference.**

The reboot is justified **only** by the embodied-consequence layer. Reproducing the same management UI
in a heavier engine is, explicitly, failure (Locked Decision #17).

### Scope of the decision

1. Unreal Engine **5.8.2** `[Verified]` installed locally, C++ project.
2. Authoritative simulation and deterministic rules in C++; Blueprints own presentation only.
3. The Godot repository is **preserved, archived, never deleted**, and kept runnable.
4. Behavior is ported as **specification with golden vectors**, not as translated code.
5. Windows PC first, Steam the distribution target.
6. First deliverable: the **Intercepted Shipment** vertical slice, 20–30 minutes.
7. **Gaussian splats are cut**; embodied scenes are authored 3D environments.

---

## Consequences

### Positive

- The product's differentiator becomes **buildable**: Sequencer, Control Rig, Animation Blueprints,
  Lumen and a real character pipeline make a *performed* confrontation achievable.
- The simulation is re-implemented against a **passing oracle** — 24 tests, byte-identical probe
  trajectories, and every balancing constant extracted — rather than from a design document.
- Known debt is paid on the way through: content becomes data-driven (TD-02, TD-03), the duplicated
  hash becomes one utility (TD-05), the hardcoded district id is generalized (TD-06), implicit tick
  ordering becomes explicit and asserted.
- Packaging, crash reporting and test tooling are first-class rather than hand-rolled.

### Negative — stated plainly

- **Six months of working software is set aside.** The Godot build is not thrown away, but it stops
  being the product.
- **Iteration speed regresses.** GDScript hot-reload becomes C++ compile cycles (R-09). This was one of
  the brief's strongest pro-Godot arguments and it remains true.
- **Source control gets worse.** Readable `.gd`/`.tres` diffs become binary `.uasset` files; LFS
  discipline becomes mandatory from commit #1 (R-07).
- **The splat investment is stranded.** GDGS v2.2.0 plus the bespoke Godot-4.7 push-constant patch and
  the benchmark work do not transfer.
- **Six months of tooling must be rebuilt** — the godot-ai authoring rail, `GLBValidator`, and every
  probe harness.
- **Determinism must be re-earned.** The hash port is the single highest technical risk (R-03), and
  its failure mode is silent: a different but still-deterministic game.
- **Character production cost is re-opened** — the exact cost the Godot project chose to avoid
  (R-02, rated High/High).

### Neutral

- Total external asset spend is unlikely to change materially; the local generation pipeline is
  engine-agnostic, and cutting splats removes the Marble Pro line item.
- The IP boundary, scope cuts and design pillars are unchanged.

---

## Alternatives considered

### A1 — Stay in Godot; improve the cinematic layer there
**Rejected.** `[Inferred]` The gap is not one missing feature but a stack: no Sequencer-equivalent, no
Control Rig, no mature animation tooling, no facial pipeline. Closing it means building that stack —
years of work orthogonal to making a game. Godot's cinematic tooling is improving, but not on this
project's timeline.

**Strongest argument for it, acknowledged:** the Godot build *works*, its loop is proven fun, and this
alternative carries zero determinism risk, zero re-implementation cost and zero stranded tooling.
If Gate B fails, **this is the fallback we return to.**

### A2 — Godot for strategy + Unreal for cinematics
**Rejected.** `[Verified]` Brief §12.3 explicitly cuts *"separate Unity executable for cinematic
scenes"*; the same reasoning applies to any two-engine split. Shared state across processes,
double the pipelines, double the builds, and a seam the player would feel at exactly the moment the
game most needs to be seamless.

### A3 — Unity
**Rejected.** `[Verified]` Brief §13.1 already analysed Unity and found its ecosystem advantage
insufficient. Nothing has changed, and Unity's cinematic tooling is not decisively better than
Unreal's for this use.

### A4 — Ship the Godot slice first, then decide
**Seriously considered, rejected on sequencing.** `[Verified]` The Godot build is close to a packaged
slice — `docs/NOW.md` shows P19 shipped and P20 complete-but-uncommitted, with only packaging (P22/P24)
outstanding.

Rejected because the embodied layer is the thing in question, and shipping a slice whose cinematic
scene is a capsule in a box room would test everything *except* the open question. `[Proposed]`
However, the option is preserved in a useful form: **the Godot build stays runnable, and Gate B is an
explicit A/B against it.** If the Unreal scene does not beat it, A1 is where we go.

### A5 — Keep Gaussian splats in the Unreal build
**Rejected for the slice, deferred as a question (D-07).** `[Verified]` Brief §7.7 lists what a splat
cannot supply — characters, moving doors, handheld objects, evidence items, collision, navigation —
which is most of what a performed dramatic scene needs. The `IBMCinematicWorldProvider` seam is
preserved so a splat provider remains an addition rather than a rewrite.

---

## Compliance and constraints

Unchanged and carried forward: the IP boundary (brief §2), the explicit scope cuts (§12.3), the
design pillars (§6), the gate discipline (§12, §19), and the authority invariant — *the strategic
simulation is authoritative; presentation visualizes it but does not own it.*

---

## Rollback boundary

**This decision is reversible until Gate B** ([07_IMPLEMENTATION_ROADMAP.md](07_IMPLEMENTATION_ROADMAP.md) S13).

| Point | Reversibility |
|---|---|
| Through S10 (Gate A) | **Fully reversible.** The Godot build is untouched and further along; nothing is lost but the time spent |
| S11–S13 (to Gate B) | **Reversible at cost.** Character and scene work would be set aside |
| After Gate B passes | **Effectively committed.** Content production is under way in Unreal |

**The rollback trigger is Gate B itself:** if the Unreal embodied scene does not deliver something the
Godot version could not, stop and return to the Godot build (stop condition SC-1). That gate must remain
a genuine question with a genuine possible "no" — otherwise the reboot's central premise was never
tested at all.

**Preconditions for rollback to stay available:**
1. The Godot repository is never deleted or force-pushed (Locked #1).
2. It stays buildable and runnable — Godot 4.7 binary retained at `D:\Godot\`.
3. Its uncommitted P20 work is committed before archiving (D-08), so the archive is a clean snapshot.

---

## Notes on this ADR

This ADR records a decision that **contradicts the project's own authoritative brief.** That is
legitimate — the brief is a 2026-07 document, the locked decisions supersede it, and §13.1's reasoning
addressed a narrower product than the one now intended. But the contradiction is recorded rather than
smoothed over, because a future reader finding brief §13.1 deserves to know it was overridden
deliberately, by whom, and on what grounds.

`[Verified from repository]` The brief's engine analysis was sound for the product it described. The
product changed. That is the whole argument, and it should be held to honestly: if the embodied layer
does not materialize, the brief was right and this ADR was wrong.
