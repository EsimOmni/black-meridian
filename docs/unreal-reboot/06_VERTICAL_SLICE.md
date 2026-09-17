# 06 — Vertical Slice: The Intercepted Shipment

The one thing being built (Locked #16). 20–30 minutes, greybox-first, packaged for Windows.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed

---

## 1. Scope and the deliberate narrowing

`[V]` **Source conflict, resolved.** Brief §12.1 specifies a 45–60 minute slice with 8 fixer jobs
(3 authored + 5 systemic), 4 rackets, 2 fronts and 4 hero characters. The task prompt specifies
**20–30 minutes** with a **minimal principal cast**. The prompt outranks the brief.

`[P]` The narrowing is not just arithmetic — it changes what is proven. At 20–30 minutes:

| Brief §12.1 | This slice | Why |
|---|---|---|
| 45–60 min | **20–30 min** | Prompt-mandated |
| 8 jobs (3 authored + 5 systemic) | **4 authored + systemic generation live** | The full narrative spine runs; systemic jobs demonstrate the engine without needing 5 to land |
| 4 hero characters | **1 hero-grade rigged + 3 portrait/voice** | Character production is the top cost risk (R-02). One character *performed well* proves the reboot; four proves the budget can explode |
| Two viable strategies | **Three materially different approaches** | Prompt-mandated; the job system already supports it |
| One splat sequence | **One authored embodied location** | Splats CUT ([00](00_EXECUTIVE_DECISION.md) §5.1) |

**The hero-character decision is the sharpest trade in this package** and is surfaced as **D-02**.

---

## 2. Night Cycle retune

`[V]` Godot budgets total 1800 ticks (30 min). `[P]` For a 20–30 min slice, compressed while keeping
the four-phase shape and the proportions that make each phase read as itself:

| Phase | Godot | Slice | Minutes @ NORMAL | Content |
|---|---|---|---|---|
| COUNCIL | 240 | **180** | 3:00 | Brief, priority, first decision |
| OPERATIONS | 1080 | **660** | 11:00 | Jobs, rackets, rival response |
| CRISIS | 360 | **300** | 5:00 | Loyalty crisis + **embodied scene** |
| RECKONING | 120 | **120** | 2:00 | Settlement, ending decision |
| **Total** | 1800 | **1260** | **21:00** | + pause/read time → 25–30 min real |

`[V]` COUNCIL stays ≥ 180 ticks to satisfy brief §17.5's "first strategic decision within three
minutes." CRISIS keeps 5 minutes because the embodied scene is budgeted at 5–8 minutes (brief §7.7)
and must not feel rushed — *this is the phase the reboot exists for.*

**These values are DataTable-driven** (`DT_BMBalance`), so pacing is tunable without a recompile.

---

## 3. The world

### 3.1 Glass Wharf `[V]` — seeded values preserved verbatim

District: influence 0.4 · security 0.3 · prosperity 0.6 · fear 0.2 · visibility 0.5 ·
institutional presence 0.35 · local heat 0.1 · faction pressure `{Compact 0.4, Corvine 0.3}`.

| Venue | Type | Kind | Owner | Control | Yield / Capacity | Notes |
|---|---|---|---|---|---|---|
| `gw_contraband` | Racket | Contraband logistics | Compact | CONTROLLED | 220, staff 3 | The shipment job's venue |
| `gw_nightclub` | Front | Nightclub | Compact | CONTROLLED | cap 600, eff 0.75, cost 0.18 | |
| `gw_protection` | Racket | Protection | Compact | INFLUENCED | 140, staff 2 | |
| `gw_gaming` | Racket | Underground gaming | Compact | CONTROLLED | 180, staff 2 | |
| `gw_freight` | Front | Freight company | Compact | CONTROLLED | cap 450, eff 0.7, cost 0.2 | |
| `gw_clinic` | Racket | Illegal clinic | **Corvine** | CONTROLLED | 160, staff 2 | Rival foothold |
| `gw_saltworks` | Racket | Contraband logistics | *neutral* | CONTESTED | 90, staff 1 | EXPAND bait |

All rackets `racket_risk = 0.3`. Operative pools = assigned + **2** free reserve.

`[V]` `gw_saltworks` exists specifically as **bait** — a neutral venue that gives the rival's EXPAND
action a legal target, which is what makes territory loss reachable in a single cycle. Do not remove it.

### 3.2 Factions `[V]`

| Faction | Aggression | Caution | Cunning | Dirty | Clean | Accent |
|---|---|---|---|---|---|---|
| Meridian Compact (player) | 0.4 | 0.6 | 0.7 | 5,000 | 1,500 | `#C99140` |
| Corvine Assembly (rival) | 0.7 | 0.3 | 0.8 | 4,000 | 1,000 | `#5973A6` |

### 3.3 Cast `[V]` — all species placeholders pending canon (see [11](11_CANONICAL_REFERENCE_INTAKE.md))

| Id | Role | Start motives | Production tier |
|---|---|---|---|
| `aiko_velora` | Player / Resolver | trust 1.0 | **First-person; hands/voice only** |
| `regent` | Compact Regent | trust 0.7, ambition 0.5 | Portrait + voice |
| `bengal_lt` | Operations lieutenant | trust 0.6, ambition 0.5, grievance 0.3; rel `{regent −0.2, aiko +0.4}` | **HERO — rigged, animated, performed** |
| `raven_boss` | Corvine boss | trust 0.0, ambition 0.9 | Portrait + voice |

`[P]` **`bengal_lt` is the one hero** because he is the subject of the Lieutenant's Debt crisis and
therefore the character the player confronts in the warehouse. The reboot's entire thesis rests on that
one confrontation reading as a *performance*.

---

## 4. Player flow

```
┌─ COLD OPEN (≤2 min) ────────────────────────────────────────────────┐
│ L_GlassWharf_Strategic. Paused. Rain. The city reads as a diorama.  │
│ The Intercepted Shipment job is ALREADY on the table.               │
│ Onboarding nudge: "A shipment was stopped at the gate."             │
└──────────────────────────┬──────────────────────────────────────────┘
┌─ COUNCIL (3 min) ────────▼──────────────────────────────────────────┐
│ Roster (R): four principals, PUBLIC motives only.                   │
│ Bengal's grievance 0.3 is visible — the seed of what comes later.   │
│ Player unpauses. FIRST STRATEGIC DECISION ≤3 min. ✅ brief §17.5    │
└──────────────────────────┬──────────────────────────────────────────┘
┌─ OPERATIONS (11 min) ────▼──────────────────────────────────────────┐
│ Job stage 1 INTAKE → 2 PREPARATION (≤3 of 4) → 3 INTERVENTION       │
│   (THE THREE APPROACHES — §5) → 4 COVER-UP.                         │
│ Economy runs: dirty climbs faster than laundering. Overflow → heat.  │
│ Player must choose: pause a racket · pressure a front · tolerate it. │
│ FIRST OPERATION ≤8 min ✅                                            │
│ Rival telegraphs (~30 s warning) then lands. FIRST RIVAL ≤15 min ✅  │
│ Systemic job spawns from the rival action (retaliation/contested).   │
│ Beat 1 fires 30 ticks after the shipment resolves:                   │
│   THE INSPECTOR'S LEDGER — a loud shipment plants a REAL case.       │
└──────────────────────────┬──────────────────────────────────────────┘
┌─ CRISIS (5 min) ─────────▼──────────────────────────────────────────┐
│ Beat 2: THE LIEUTENANT'S DEBT. Leverage/survival floors raised.      │
│ Betrayal telegraph opens — 6 rival ticks (~60 s) to act.             │
│ HUD offers: "Confront Bengal (walk the floor)"                       │
│                                                                      │
│   ══ THE EMBODIED SCENE ══  L_Warehouse_Embodied                     │
│   Sim PAUSES → checkpoint written → level swap                       │
│   First-person. Rain on the roof. One sodium lamp. Bengal is there.  │
│   Verbs: inspect · plant · take · choose where to stand · speak ·    │
│          walk away                                                   │
│   Outcome writes REAL state via the same verbs the HUD uses.         │
│   Return to city → consequence visible in the HUD                    │
└──────────────────────────┬──────────────────────────────────────────┘
┌─ RECKONING (2 min) ──────▼──────────────────────────────────────────┐
│ Beat 3: MERIDIAN ACCORD → stance truce / leverage / war.             │
│ Settlement. Ending 120 ticks later:                                  │
│   ending_accord · ending_armed_peace · ending_war                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. The three operational approaches

`[V]` Already authored in `job_templates.gd::intercepted_shipment` — these are not invented here:

| Approach | Effects | Consequence chain |
|---|---|---|
| **Quiet re-route** (`appr_quiet`) | objective 0.7, evidence **+0.1** | Low trace. Cases stay small, inspection unlikely. Less money, fewer problems |
| **Armed recovery** (`appr_force`) | objective 0.95, evidence **+0.2**, public_fear 0.3, collateral 0.2, injury 0.3 | Best objective, **worst trace** → real evidence case → Inspector's Ledger becomes a genuine investigation; `public_fear` raises district fear; injury raises lieutenant **grievance** → feeds the betrayal gate |
| **Cut the inspector in** (`appr_deal`) | objective 0.5, relationship **+0.3**, leverage 0.2, suspicion 0.1 | Weakest outcome, but buys **trust** (defusing betrayal later) and leverage; raises rival suspicion → grudge |

Plus ≤3 of 4 prep actions and 3 cover-ups, each shifting the outcome. `[V]` The balance envelope is
already test-enforced: loudest approach+coverup nets ≥ +0.25 evidence, quietest ≤ −0.3.

**This is the "materially different" requirement satisfied by existing, tested content** — the three
paths differ in money, heat, evidence, loyalty *and* rival response, not in flavour text.

---

## 6. Consequence matrix

| Decision | Economy | Heat / evidence | Loyalty | Rival | Narrative |
|---|---|---|---|---|---|
| Armed recovery | +400 dirty (high objective) | **+0.2 evidence** → case deposited → heat → inspection likely | injury 0.3 → **grievance ↑** | suspicion → grudge ↑ | Ledger beat becomes a real case |
| Quiet re-route | +400 dirty | +0.1 evidence, small | neutral | minimal | Ledger beat is lighter |
| Cut inspector in | +400 dirty at objective 0.5 | −0.05 net with cover | **trust +0.3** → betrayal harder | suspicion 0.1 | Leverage available later |
| Silence the witness (cover-up) | — | evidence **−0.5** (best cover) | — | — | `delayed_consequence 0.3` → **follow-up job** |
| Pause a racket | income → 0 | exposure stops | — | venue looks weak → rival interest ↑ | — |
| Pressure a front | −400 clean, +100 capacity | overflow ↓ → heat ↓ | — | — | — |
| Reassure Bengal | −200 clean | — | **+0.15 trust, +0.15 shared** → may defuse | — | motive revealed |
| Ignore the telegraph | — | — | **Betrayal lands** — venue flips to Corvine as INFLUENCED | rival gains ground | Territory-loss job spawns |
| Enter the warehouse | — | can remove a case | can defuse | — | scene outcome recorded |
| Walk away in-scene | — | nothing written | nothing written | — | `[V]` verified: walk-away writes nothing |

`[V]` Every row is backed by implemented, tested behavior.

---

## 7. Required UI

| Widget | Purpose | Source |
|---|---|---|
| `WBP_HUD` | Cash (dirty/clean), **unlaundered overflow**, heat + combined pressure, phase clock, speed, inspection warning, rival telegraph, selected venue + verbs, betrayal tell, "walk the floor" affordance | `[V]` `hud.gd` |
| `WBP_JobPanel` | Four-stage job flow: intake → prep (≤3 of 4) → approach → cover-up → outcome | `[V]` `job_panel.gd` |
| `WBP_Roster` | Four principals, **public motives only**, relationship edges, betrayal tell | `[V]` `roster_panel.gd` |
| `WBP_Ending` | The three endings + a tally | `[V]` `ending_panel.gd` |
| `WBP_Settings` | Rebinding, text size, performance tier, audio | `[V]` uncommitted P20 |
| `WBP_Nudges` | Five first-occurrence onboarding toasts | `[V]` uncommitted P20 |
| `WBP_Interact` | Embodied-scene prompts + dialogue choices | `[P]` new |

**UI hard rule `[V]`:** hidden motives (`RivalLeverage`, `SurvivalPressure`) are **never** rendered.

---

## 8. Required environments

| Level | Content | Fidelity |
|---|---|---|
| `L_BM_Persistent` | GameMode, subsystems, persistent audio | n/a |
| `L_GlassWharf_Strategic` | 7 venue buildings from the modular kit, wharf silhouette, rain, traffic/crowd proxies, water | **Greybox → kit** |
| `L_Warehouse_Embodied` | ~10×8 m interior: crates, workbench, hanging lamp, rain on a skylight, one door, 4–6 interaction points | **HERO — the one high-fidelity space** |
| `L_Council_Embodied` | Compact council chamber for the COUNCIL phase | **Lower fidelity** — may ship as a framed static view (D-03) |

`[V]` Asset targets from brief §11 for one district: 12 modular kits, ~40 building instances,
50–70 props. The Godot build already produced 10 validated kit GLBs + 5 props under CC-BY — those
source assets can be re-imported (licenses carry over, see [09](09_ASSET_AND_CHARACTER_PIPELINE.md) §10).

---

## 9. Performance budgets

`[P]` Target machine `[V]`: Ryzen 7 8700F (8C/16T) · 64 GB DDR5-6000 · **RTX 5060 Ti 16 GB, 128-bit** ·
Win 11 · NVMe.

| Metric | Target | Floor |
|---|---|---|
| City view, packaged, 1080p High | **60 fps** | 45 |
| Embodied scene, packaged, 1080p High | **60 fps** | 45 |
| City view, editor PIE | 30 fps | 20 |
| Strategic tick CPU | ≤ 2.0 ms | 4.0 |
| City → warehouse transition | ≤ 3.0 s | 5.0 |
| Save write / load | ≤ 250 ms / ≤ 1.5 s | 500 ms / 3 s |
| **VRAM, embodied scene** | **≤ 10 GB** | 13 GB |
| VRAM, city view | ≤ 8 GB | 11 GB |
| Package size | ≤ 8 GB | 15 GB |
| Cold shader compile (editor) | ≤ 20 min | 45 min |

**Rationale `[P]`:** 16 GB VRAM on a 128-bit bus is the binding constraint on this machine — the user's
own hardware record names VRAM as the ceiling for local work. Budgeting ≤ 10 GB leaves editor and OS
headroom and keeps a margin for a mid-range consumer target. Lumen + VSM in a *small interior* is
affordable; the same settings across an open city would not be, which is another reason the city stays
a bounded diorama.

`[P]` **Settings tiers** (brief §19 Month 5): Low / Medium / High / Ultra, with Lumen and VSM quality,
shadow distance, and proxy crowd density as the main levers.

---

## 10. Acceptance criteria

The slice is done when **all** hold. Derived from brief §18 + the prompt's seven proof requirements.

### Gameplay
- [ ] A complete Night Cycle is playable start to finish without developer instruction.
- [ ] **Three materially different approaches** to the shipment reach measurably different states.
- [ ] Rival AI responds to district and character state, with a visible telegraph before every action.
- [ ] The loyalty crisis is **causally understandable** and **preventable**.
- [ ] Economy, heat and evidence **interact** — not three independent meters.
- [ ] The authored chain completes: Shipment → Ledger → Debt → Accord → an ending.
- [ ] No job stage can deadlock.

### The embodied layer — *the reboot's reason to exist*
- [ ] The warehouse scene **adds value unavailable in the Godot presentation.**
      Judged by direct comparison against `mesh_world_provider.gd`'s box room. **If this fails, SC-1 fires.**
- [ ] One rigged character performs the confrontation — face, posture, timing.
- [ ] All six verbs work, including **plant** (the Godot build's known missing verb).
- [ ] The scene changes persistent state; walking away changes nothing.
- [ ] Return to the city is clean; the consequence is visible in the HUD.

### Technical
- [ ] Save/load survives before, during and after the transition.
- [ ] Restart/recovery: the checkpoint restores pre-scene state.
- [ ] **Behavioral equivalence** with the Godot golden vectors on all preserved systems ([08](08_TEST_STRATEGY.md)).
- [ ] Deterministic replay: same inputs → same state.
- [ ] Content is data-driven — zero authored operations in C++ or Blueprints.
- [ ] No authoritative state in any Blueprint or Level Blueprint.
- [ ] City and embodied level never co-resident.
- [ ] Performance budgets met (§9).
- [ ] A packaged Windows build runs on a machine without the editor.
- [ ] Crash reporting + version display present.

### Legibility — the sharpest test `[V]` brief §19 Month-5 gate
- [ ] A player who has never seen the game can explain afterwards: **how money is cleaned · why heat
      rose · why the rival acted · why the loyalty crisis happened.**

---

## 11. Cut list

Explicitly **not** in the slice — cut now so they cannot creep in later:

| Cut | Why |
|---|---|
| Districts 2–5 | One district (brief §12.1) |
| Rival factions 2–3 | One rival |
| Hero rigs for Regent / Raven / Aiko | Cost control (R-02); portraits + voice suffice |
| Third-person Aiko | First-person only; no full-body rig, no traversal animation set |
| Gaussian splats | CUT ([00](00_EXECUTIVE_DECISION.md) §5.1) |
| Rival actions 6–10 | 5 scored actions ship; the rest are DEFER |
| Evidence-chain graph | Flat weighted cases ship |
| Rival memory beyond `grudge` | DEFER |
| Difficulty levels | DEFER |
| Loss/failure state | DEFER ([02](02_PRODUCT_CONTRACT.md) §10) |
| Full voice acting | Key lines only; D-04 |
| Second embodied location at hero fidelity | Council may be a framed static view (D-03) |
| Steam store page, trailer, demo | Brief Month 6; out of slice |
| Localization | Post-slice |
| Achievements, cloud saves | Post-slice |

---

## 12. What the slice proves

| Prompt requirement | Proven by |
|---|---|
| 1. Strategic loop is enjoyable | Full cycle playable; `[V]` the Godot loop already earned "fun, stress, very good" |
| 2. Embodied scene adds value | Direct A/B against the Godot box room |
| 3. State stays synchronized | Consequence visible in the HUD on return; functional tests |
| 4. Save/load survives transitions | Checkpoint + round-trip tests at every boundary |
| 5. Content is data-driven | `Test_Content_NoHardcodedJobs`; all content in Data Assets |
| 6. Architecture scales without open-world | Level Streaming, no World Partition; district count is a data change |
| 7. Runs on the target machine | §9 budgets measured on the packaged build |

---

**Next:** [07_IMPLEMENTATION_ROADMAP.md](07_IMPLEMENTATION_ROADMAP.md)
