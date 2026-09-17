# 02 — Product Contract

**What Black Meridian is, as a product, after the reboot.** This is the design authority for the
Unreal build. Where it differs from the brief PDF, the difference is deliberate and marked.

Tags: `[Verified from repository]` · `[Inferred]` · `[Proposed]` · `[Unverified]`

---

## 1. Player fantasy

`[Verified from repository — brief §3]` Unchanged, and non-negotiable:

> **"I do not command armies. I decide which problem becomes somebody else's war."**

You are **Aiko Velora, the Resolver** — the ruling Meridian Compact's principal fixer in Black
Meridian, a rain-soaked interspecies metropolis. Power comes from information, preparation, leverage,
and knowing which person can safely be sacrificed. You are a **problem architect**, not a general,
not a shooter, not a city painter.

`[Verified]` **Aiko's role is preserved as the playable fixer serving the Regent** — not the dynasty
ruler. Brief §20 #1 lists "should the player eventually overthrow and replace the Regent?" as an open
question; no repository source supersedes the current assumption, so it stands. Tracked as **D-06**.

### 1.1 The genre statement, sharpened by the reboot

`[Proposed]` The Godot build was accurately described as a *"real-time-with-pause mafia empire
management strategy game."* The reboot's positioning is narrower and more honest about what makes it
worth building:

> **A character-driven cinematic crime strategy game.** You run an empire through a management layer,
> and when a decision has a face attached, you walk into the room and look at it.

The strategy layer is the game. The embodied layer is why it *matters*. Neither is a wrapper for the
other.

---

## 2. Core loop

### 2.1 The 30-second loop `[Verified — brief §5.1]`

1. **Detect a change** — patrol enters a district; racket income drops; rival influence rises; a
   lieutenant asks for something; an evidence chain advances; a crisis appears.
2. **Inspect context** — district overlay, involved characters, heat, expected profit, loyalty risk,
   known *and unknown* consequences.
3. **Make one commitment** — assign an operative, fund an operation, choose an approach, delay the
   problem, personally intervene as Aiko, or sacrifice another objective.
4. **Watch the city react** — the proxy city visibly changes state.
5. **Absorb the consequence** — cash, control, evidence, loyalty or narrative state changes, and
   **a new problem is created** rather than every problem simply disappearing.

Point 5 is the design's engine `[Verified]`: the Godot probe recorded 40 jobs offered / 40 resolved in
one cycle, self-feeding from rival sabotage and territory loss. The loop never empties.

### 2.2 The Night Cycle `[Verified — brief §5.2, implemented in `src/simulation/night_cycle.gd`]`

| Phase | Godot budget | Brief target | Content |
|---|---|---|---|
| **COUNCIL** | 240 ticks (4 min) | 3–5 min | Review the night, set priority, inspect relationships, allocate clean capital, pick a district objective |
| **OPERATIONS** | 1080 ticks (18 min) | 15–20 min | Run rackets and fixer jobs, react to rivals, manage heat and evidence |
| **CRISIS** | 360 ticks (6 min) | 5–8 min | A state-driven crisis forces a high-cost decision; **the embodied scene lands here** |
| **RECKONING** | 120 ticks (2 min) | 2–3 min | Income and laundering resolve, pressure advances, loyalty becomes visible, next cycle previewed |

Total 1800 ticks = 30 min at NORMAL speed. `[Proposed]` The reboot's slice compresses this — see §9.

**Phases advance purely on elapsed ticks** `[Verified]` — no gating condition. One behavioral coupling
exists and is preserved: **no new betrayal telegraphs open during COUNCIL** (open ones still advance).

A player must be able to stop after one Night Cycle and feel a **complete dramatic episode** occurred.

---

## 3. Session structure

`[Proposed]` For the reboot's vertical slice (Locked #16, prompt-mandated 20–30 min):

```
Cold open (≤2 min)   The Intercepted Shipment job is on the table before any tutorial.
COUNCIL   (~4 min)   First strategic decision within 3 minutes. Non-negotiable (brief §17.5).
OPERATIONS(~12 min)  First operation ≤8 min. First visible rival response ≤15 min.
CRISIS    (~8 min)   Loyalty consequence; the embodied warehouse scene.
RECKONING (~3 min)   Settlement, consequence readout, ending decision.
```

`[Verified — brief §17.5]` These beats are **refund-risk design**, not pacing preference: Steam refunds
inside 2 hours, so the game must prove itself early. "No 90-minute exposition prologue."

---

## 4. The strategic layer

`[Verified]` Preserved wholesale from the validated Godot systems. Full numbers in
[01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) §7 and [05_DATA_MODEL.md](05_DATA_MODEL.md).

- **Districts and venues** — influence, security, prosperity, fear, visibility, institutional
  presence, faction pressure, local heat. Six control states, of which **COMPROMISED is distinct from
  lost**: you may still own a venue that has been infiltrated or tied to an evidence case.
- **Two currencies** — dirty cash (immediate, creates exposure) and clean capital (slow, required for
  upgrades and influence). **The tension is structural**: you will usually hold more dirty cash than
  you can safely launder. The decision is never "earn more," it is *slow down, tolerate exposure, buy
  a front, pressure a front, bribe, pause a profitable racket, or let a rival operate and tax them.*
- **Heat, evidence, pressure** — three coupled systems, not one wanted meter. Local heat (visible
  incidents) → inspections with latch/re-arm hysteresis; named evidence cases that accumulate and can
  be eroded or removed; campaign-wide Central Pressure rising on the **mean** of district pressure.
- **Rival utility AI** — scored argmax over a fixed action list, with a **telegraph → land window** so
  the player can see it coming. Fairness rule `[Verified]`: rivals score from *public* character
  fields only (`recruit_susceptibility` reads trust/grievance/ambition, never `rival_leverage` or
  `survival_pressure`). Difficulty must improve planning, never grant invisible multipliers.
- **Fixer jobs** — generated from simulation state, four stages, nine outcome dimensions, max 3
  concurrent. Results are never binary success/failure.
- **Loyalty as a motive network** — trust, ambition, fear, grievance, shared success, leverage,
  secrets, relationship edges. **Betrayal is deterministic, telegraphed and preventable.**
- **Operative pool** — a conserved resource; assigning staff to a venue is a real opportunity cost.

### 4.1 The asymmetry that IS the design `[Verified]`

The roster shows **public** motives only; hidden motives are never rendered. `docs/NOW.md` states this
plainly: *"gizli motiveler ASLA render edilmez, o asimetri tasarımın kendisi"* — hidden motives are
NEVER rendered; that asymmetry is the design itself. The player infers; the game does not tell.
**Preserve this in every UI decision.**

---

## 5. The embodied-consequence layer

`[Proposed]` This is the reboot's reason to exist, so it gets a real specification rather than an
aspiration.

### 5.1 What these scenes are

Small, bounded, high-fidelity, **fully authored dramatic spaces**, entered from the strategic layer
when a decision has a person attached. Scene types (brief §7.7): crime-scene inspection · walk-and-talk
negotiation · private confrontation · dynasty council · aftermath/execution decision.
The slice ships **one location** (the warehouse), used for a confrontation with inspection elements.

### 5.2 What they are not

Not a second game. **No combat, no jumping, no weapons, no free roam, no puzzle-box.** Constrained
walkable area, 3–6 interaction points, 1–3 characters, 5–8 minutes. Simulation is **paused** while
inside.

### 5.3 The verb set `[Proposed]`

Brief §6 pillar 4 defines the vocabulary. The Godot build shipped a subset; the reboot restores it:

| Verb | Godot | Reboot |
|---|---|---|
| Inspect evidence / objects | ✅ `E` | PRESERVE |
| Remove / take an object | ✅ `R` (crime scene) | PRESERVE |
| **Plant / place an object** | ❌ missing | **RESTORE** — named as a known trim in `P18-month4-gate.md` |
| Speak — choose what Aiko reveals | ⚠️ single `R` reassure | **REDESIGN** — real dialogue choices |
| Choose where to stand | ❌ | **RESTORE** — blocking matters in a confrontation |
| Walk away | ✅ `Q` | PRESERVE |

**No verb may exist in an embodied scene that is not backed by a strategic consequence.**

### 5.4 The hard contract

1. Entry **checkpoints** the campaign before any mutation `[Verified — preserved from P18]`.
2. The scene **owns no authoritative state**. Every effect is a call to an existing simulation verb.
3. Every scene changes persistent strategic state — *"a visually attractive but non-persistent scene
   does not pass"* `[Verified — brief §19 Month-4 gate]`.
4. Consequences survive save/load taken **before, during and after**.
5. The city and the embodied level are **never resident simultaneously**.

### 5.5 The quality bar — the thing being bought

`[Proposed]` The scene must make the player feel the weight of a decision they already made in a
spreadsheet. Concretely, the slice's warehouse scene must deliver: **one rigged, animated, lit
character** who performs the confrontation (face, posture, timing), authored camera staging via
Sequencer, and a lighting/atmosphere pass that reads as the brief's "rain-lacquered interspecies
noir." If it lands as "capsules with better shadows," the reboot has failed its own test (S1).

---

## 6. Camera model

### 6.1 Strategic camera `[Verified — brief §9.2]`

Perspective camera that reads **almost orthographically**: 35–45° downward (Godot used −50°,
`[Verified]` `management_camera.gd`), ~55–75 mm equivalent, limited zoom bands, **no camera rotation
in the slice**, no unrestricted street-level view. Pan on WASD/arrows + middle-drag, clamped to the
district. Depth of field only for controlled transitions.

`[Verified]` This is also a **production decision**: a fixed high camera lets us simplify rear façades,
skip undersides, drop street-level texture resolution, and hide LOD transitions in rain and darkness.
Changing it would invalidate the entire environment art budget.

### 6.2 Embodied camera `[Proposed]`

First-person, walk-clamped to a validated volume, no jump, no crouch, mouse-look with sane limits.
Sequencer takes the camera for authored beats and **returns it cleanly**. Godot's provider contract
(`{center, floor_y, bounds_half}`) is preserved in shape — see
[04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md) §7.

---

## 7. Interaction model

**Strategic:** click a venue to select; act through explicit verbs (pause racket, assign/recall
operatives, pressure a front, reassure a lieutenant, take a job stage decision). Pause and three
speeds. Everything reachable by keyboard.

**Embodied:** WASD + mouse-look; a single context-sensitive interact; explicit dialogue selection;
leave. Simulation paused throughout.

`[Verified]` Key bindings from the Godot build (rebindable, defaults): SPACE pause · X cycle speed ·
C camera · R roster · F9 save · L load · ESC settings. **F8/F10 are poisoned under the editor
debugger** (`tasks/lessons.md` — F8 stops the process outright); the reboot should not inherit that
constraint, but should not blindly reuse F-keys for game verbs either.

---

## 8. Narrative model

`[Verified]` A **thin authored spine over a systemic engine** — the structure to preserve exactly.

- **Systemic jobs** emerge from state (failed rackets, rival provocation, inspections, territory loss).
- **Authored beats** fire on gates (previous beat resolved + lead ticks), and **defer politely** to the
  job cadence cap rather than dying — *"never let an authored beat die to the cadence cap."*
- **Beats set up conditions; the player's choices decide outcomes.** The Lieutenant's Debt beat raises
  leverage/survival floors that alone do **not** open the crisis — the player's approach decides
  whether the bar is crossed. This is the model for all authored content: **authored setup, systemic
  resolution.**
- **Endings** derive from an accumulated stance (truce / leverage / war), not a final menu choice.

### 8.1 IP boundary — hard, carried forward unchanged `[Verified — brief §2]`

No character names, biographies, relationships, dialogue patterns, plot beats, episode structures,
geography, estates, costumes or production design from any existing series. No marketing as an
adaptation or analogue. No third-party series imagery in mood boards, store assets or trailers.
Structural comparison tables stay in internal docs only. Only abstract genre structures are retained.
**Title, character bible and first trailer require IP review before any public announcement.**

---

## 9. Progression

**Within a cycle:** Council priority → operations → crisis → reckoning.
**Across cycles** (full game, out of slice scope): district control, front capacity, evidence-case
accumulation, Central Pressure, rival grudge and memory, character motive drift.
**The slice** delivers one cycle and one ending decision.

---

## 10. Loss and failure conditions

`[Verified]` The Godot build has **no explicit loss state** — Central Pressure has an alert but no
terminal condition wired. Brief §7.3 says pressure thresholds should eventually trigger asset freezes,
coordinated raids, informant attempts, political defections and *"endgame conditions."*

`[Proposed]` **For the slice: no loss state.** The slice ends at the ending decision regardless. A
real failure condition is full-game design work and inventing one now would be speculative. Explicitly
flagged so it is not mistaken for an oversight — full-game loss design is **out of scope** and noted
in [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md) as a non-blocking future decision.

Failure is expressed **locally** instead: jobs expire with real consequences
(`{evidence 0.3, public_fear 0.1, delayed_consequence 0.5}`), betrayals land and cost a venue,
inspections disrupt income, territory is lost.

---

## 11. Scope boundaries

### In scope for the slice
One district (Glass Wharf) · one command/council location · one warehouse consequence location ·
one player faction (Meridian Compact) · one rival (Corvine Assembly) · minimal principal cast ·
one complete Night Cycle · the shipment crisis · **three materially different operational approaches** ·
economy / heat / loyalty / rival consequences · the embodied scene and a clean return ·
save/load · restart/recovery · a packaged Windows build.

### Explicitly excluded `[Verified — brief §12.3 + locked decisions]`
Character combat · tactical maps · drivable vehicles · open-world exploration · entering arbitrary
buildings · city construction · citizen schedules · destructible environments · multiplayer · co-op ·
runtime procedural dialogue · runtime AI generation (image, mesh, video, LLM) · seven independent
character rigs · a fully voiced branching screenplay · a second engine for cinematics · Steam Workshop
at launch · console ports before PC validation · more than one embodied location in the slice.

### 11.1 The failure mode this exists to prevent `[Verified — brief §12]`

> *"The biggest risk for a tiny AI-assisted studio is producing assets before the mechanic is proven."*

Locked #15 restates it: **no final art before the Unreal greybox vertical slice passes its gates.**
The Godot project honoured this at four consecutive gates. The reboot inherits the discipline, and it
is the single most likely thing to be quietly abandoned once Unreal's renderer starts looking good.

---

## 12. What "done" means for the slice

The acceptance criteria are in [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md) §10 and the success
definition in [00_EXECUTIVE_DECISION.md](00_EXECUTIVE_DECISION.md) §6. The one-line version:

> A player who has never seen the game completes one Night Cycle, walks into the warehouse once,
> comes out changed, reaches an ending — and can correctly explain **how money is cleaned, why heat
> rose, why the rival acted, and why the loyalty crisis happened.**

`[Verified]` That last clause is the brief's own Month-5 gate (§19), and it is the sharpest test in
the document: it measures whether the simulation is *legible*, not merely correct.

---

**Next:** [03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md)
