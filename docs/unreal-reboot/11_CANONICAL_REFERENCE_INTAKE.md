# 11 — Canonical Reference Intake

**What this document is:** a list of external inputs required before canonical asset production can
begin. It records **gaps**, and deliberately **does not fill them**.

> **Standing rule for this package:** do not invent facial anatomy, body architecture, species rules,
> wardrobe, logos or relationships. Where the repository is silent, that silence is recorded as a gap.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed · `[MISSING]` = required input not present

---

## 1. Why this exists

`[V]` Three repository sources agree that the cast is **not yet canon**:

1. **Brief §4:** *"Names other than Aiko Velora are role placeholders until canonical names and visual
   masters are approved."*
2. **Brief §20 #5:** *"Canonical names, faction identities, immutable visual properties and
   relationship histories must be approved before hero-character production."*
3. **`docs/NOW.md`:** the four shipped portraits are *"swappable placeholders pending the world-bible
   identity lock (brief §20)."*

`[V]` And `docs/prompts/P14b-characters-roster.md` states the character slice *"requires the canonical
character names + visual masters approved (brief §20 #5). Lock the world bible…"*

**The repository may not contain the latest external canonical character packages.** Nothing in this
package assumes it does.

---

## 2. Cast currently present in the repository

`[V]` This is the complete, factual inventory — simulation identity only, no appearance data.

| Id | Display name | Faction | Role | Start motives | Art present |
|---|---|---|---|---|---|
| `aiko_velora` | Aiko Velora | `compact` | Playable fixer / Resolver | `public_trust 1.0` | `assets/characters/portraits/aiko_velora.png` |
| `regent` | *(Regent)* | `compact` | Compact Regent | `public_trust 0.7`, `ambition 0.5` | `regent.png` |
| `bengal_lt` | *(Bengal lieutenant)* | `compact` | Operations lieutenant | `public_trust 0.6`, `ambition 0.5`, `grievance 0.3`; relationships `{regent −0.2, aiko_velora +0.4}` | `bengal_lt.png` |
| `raven_boss` | *(Raven boss)* | `corvine` | Corvine Assembly boss | `public_trust 0.0`, `ambition 0.9` | `raven_boss.png` |

`[V]` Source: `src/core/world_seed.gd::_build_characters`. The display names in code are placeholders
matching the brief's role labels.

### 2.1 The wider cast named in the brief (not implemented)

`[V]` Brief §4 defines seven OMNI characters. Only four are in the build. The other three —
a **Lyrian Humanoid** diplomatic lieutenant/heir, a **Grey-Alien** intelligence lieutenant, and a
**Peregrine-Avian** boss of a neutral logistics power — are `[V]` explicitly *"portraits or narrative
references"* only, with *"no full production models during the first six months."*

They are **out of scope for the slice** and need no intake now.

### 2.2 Factions present

| Id | Display | Role | Accent `[V]` |
|---|---|---|---|
| `compact` | Meridian Compact | Player dynasty | `Color(0.79, 0.57, 0.25)` — sodium amber |
| `corvine` | Corvine Assembly | Primary rival | `Color(0.35, 0.45, 0.60)` — cold petrol blue |

---

## 3. Where canon is incomplete, placeholder or conflicting

### 3.1 Species labels are placeholders — and they are load-bearing in the code

`[V]` **Finding:** the brief uses species descriptors (*Nordic-Alien Regent*, *Bengal-Felid
lieutenant*, *Raven-Woman rival boss*, *Lyrian Humanoid*, *Grey-Alien*, *Peregrine-Avian*) as
**role placeholders**. But those placeholders have leaked into **identifiers**: `bengal_lt`,
`raven_boss`.

`[P]` **Implication for the port:** ids are save-critical strings. If canon renames the Bengal-Felid
lieutenant, changing `bengal_lt` would invalidate saves and every id-encoded generated job that
references the venue/character. **Recommendation:** treat simulation ids as **opaque and permanent**,
and carry the canonical name only in `DisplayName` on the Data Asset. Establish this convention in S0,
before content exists — retrofitting it later is expensive.

### 3.2 Aiko is the only named character

`[V]` Aiko Velora is the only canonical name in the brief. Every other character has **no name**. The
build's `display_name` values for the other three are role labels, not names.

**[MISSING]** Canonical names for the Regent, the operations lieutenant, and the rival boss.

### 3.3 No visual canon exists in the repository

`[V]` **Nothing** in the repository defines: facial structure, body architecture, species anatomical
rules, wardrobe, faction insignia/logos, colour rules beyond the two accent colours, height/build
relationships, or age/era markers.

`[V]` The four existing portraits were produced via a ChatGPT runner at $0 and triaged for
set-coherence (9/10) — explicitly as **placeholders**, and `docs/NOW.md` notes the roster falls back to
a monogram when a portrait is absent, which is the correct behavior for placeholder art.

**[MISSING]** Everything in §5.

### 3.4 Relationship history is mechanical, not narrative

`[V]` The build encodes relationship *values* (`bengal_lt → regent −0.2`, `bengal_lt → aiko +0.4`) but
no **history** explaining them. Brief §20 #5 requires *"relationship histories"* to be approved.

**[MISSING]** The narrative history behind the seeded relationship values. `[P]` This matters directly
for the slice: the warehouse confrontation is *about* the lieutenant's grievance, and an actor
(or a writer) cannot perform a grievance with no cause.

### 3.5 The OMNI Sapient question

`[P]` The task prompt warns: *"Do not silently replace the existing game cast or merge it with later
OMNI Sapient characters."*

`[V]` **Finding:** the repository contains **no reference to OMNI Sapient characters** — searches
across `docs/`, `tasks/` and `src/` return nothing. The only cast is the four above.

**Therefore:** no merge has occurred and none is proposed. If an external OMNI Sapient character
package exists, it is **not in this repository**, and whether it relates to Black Meridian's cast is a
question only Cem can answer — **D-10**.

### 3.6 Aiko's role — not conflicting, and unchanged

`[V]` Brief §20 #1 asks whether the player stays a constrained operator or eventually replaces the
Regent. The current assumption — *"Aiko is the playable fixer serving the Regent, not the dynasty
ruler"* — is implemented (`is_player = true`, faction `compact`, `public_trust 1.0`) and **no
higher-authority repository source supersedes it**. It stands. (D-06 covers the long-term question,
which does not block the slice.)

---

## 4. Intake manifest — required before canonical production

`[P]` Per character promoted to hero. **For the slice this is `bengal_lt` only** ([06](06_VERTICAL_SLICE.md) §3.3).

### 4.1 Blocking for S12 (hero character production)

| # | Input | Status | Blocks |
|---|---|---|---|
| **I-01** | **Canonical name** for the operations lieutenant | **[MISSING]** | Display name, dialogue, credits |
| **I-02** | **Front / side / three-quarter** canonical reference images at consistent scale | **[MISSING]** | Base mesh generation (brief §10.4 step 1) |
| **I-03** | **Immutable property sheet** — facial structure, body architecture, species anatomical rules, proportions | **[MISSING]** | Retopology, face rebuild, identity QA |
| **I-04** | **Wardrobe definition** — silhouette, materials, faction markings, state variants if any | **[MISSING]** | Texturing, material setup |
| **I-05** | **Species skeleton constraints** — does anatomy permit the standard UE5 humanoid skeleton, or are extensions required? | **[MISSING]** | Rig decision (brief §10.4 steps 6–7) |
| **I-06** | **Relationship history** with the Regent and Aiko — why grievance 0.3, why `regent −0.2`, why `aiko +0.4` | **[MISSING]** | Dialogue, performance direction |
| **I-07** | **Voice direction** — register, cadence, accent/species inflection | **[MISSING]** | Casting / VO (D-04) |
| **I-08** | **Written approval** of I-01…I-07, dated | **[MISSING]** | Promotion to canonical |

### 4.2 Blocking for full character presentation (not the slice)

| # | Input | Status |
|---|---|---|
| I-09 | Canonical names for the Regent and the rival boss | **[MISSING]** |
| I-10 | Reference images for the Regent and rival boss (portrait-grade sufficient for the slice) | **[MISSING]** — placeholders in use |
| I-11 | Aiko's canonical appearance (hands/arms visible in first person; portrait) | **[MISSING]** |
| I-12 | Faction insignia / logos for Compact and Corvine | **[MISSING]** |
| I-13 | Species roster rules for the wider world | **[MISSING]** |

### 4.3 Blocking for public release (not the slice)

| # | Input | Status | Source |
|---|---|---|---|
| I-14 | **Trademark search on the final title** | **[MISSING]** | `[V]` brief §2 |
| I-15 | **IP review** of title, character bible and first trailer | **[MISSING]** | `[V]` brief §2 — *"before announcement"* |
| I-16 | Character-and-title similarity review | **[MISSING]** | `[V]` brief §18 Commercial |

`[V]` Brief §2 is explicit that the original-IP strategy *"materially reduces rights exposure but
cannot guarantee zero risk"* — these reviews are not optional for a commercial release.

---

## 5. Keeping identities modular until canon arrives

`[P]` The architecture must let canon land **late** without a rewrite. Three mechanisms:

1. **Simulation uses ids, never appearance.** `[V]` Already true in the Godot build — no simulation
   code reads a portrait, mesh or name. Preserve this absolutely.
2. **Art is referenced by soft pointer** on `UBMCharacterDefinition`
   (`TSoftObjectPtr<UTexture2D> Portrait`, `TSoftClassPtr<ABMCharacter> EmbodiedActorClass`).
   Swapping identity is a **data change**, not a code change.
3. **Display names come from the Data Asset**, never from code or an id.

`[P]` **Consequence:** development proceeds with placeholder art through S13 if necessary. The
fallback in R-17 — a deliberately non-identity-revealing character (masked, backlit, silhouetted) —
lets even **Gate B** be attempted before canon lands, and would also de-risk R-02 and R-14.

---

## 6. What this package explicitly did not do

- ❌ Did not invent names for the Regent, lieutenant or rival boss.
- ❌ Did not define facial anatomy, body architecture or species rules.
- ❌ Did not design wardrobe, insignia or logos.
- ❌ Did not write relationship histories.
- ❌ Did not merge any external character set into this cast.
- ❌ Did not change Aiko's role.
- ❌ Did not alter the existing portraits or their placeholder status.

---

## 7. Request to Cem

To unblock S12 ([07](07_IMPLEMENTATION_ROADMAP.md)), supply **I-01 through I-08** for the operations
lieutenant — or confirm the R-17 fallback (a non-identity-revealing hero character) so production can
start regardless.

Everything else in §4.2 and §4.3 can follow later without blocking the slice.

---

**Next:** [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md)
