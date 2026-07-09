# P08b Territory-Loss "Contested Ground" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the rival takes the player's ground — by EXPANDing onto a neutral venue, or by a betrayal handing a venue to the rival — offer a "Contested Ground" fixer job to reclaim it, with cost by approach.

**Architecture:** A new `TERRITORY_LOSS` JobOrigin. Two seed changes make territory loss real (a neutral venue the rival can take; betrayal handing a venue to the rival it recruited the lieutenant to). One authored two-variant job template. Two `JobDirector` trigger arms (EXPAND-landed, betrayal-committed) call one generator; one origin-gated resolution branch reclaims the venue. Deterministic, zero-RNG, save-safe — mirrors the shipped P08/P06b/P07c patterns exactly.

**Tech Stack:** Godot 4.7, GDScript, headless unit tests (`SceneTree` runners, exit 0 = pass).

**Key verified facts (Fable trace, read-only):**
- EXPAND eligible venues: `owner_faction != player AND != rival` (`rival_scoring.gd:129`). Seed has all 6 owned → EXPAND never fires today.
- Only runtime `owner_faction` write is EXPAND (`rival_director.gd:76`). Betrayal writes `control_state = CONTESTED` only (`relationship_service.gd:65`), leaves owner = player.
- Betrayal-landed signal exists: `betrayal_committed(character, venue)` (`relationship_service.gd:17`, emit line 68) — but passes NO faction.
- CharacterData has NO rival-identity field; `rival_leverage` is an anonymous float. RECRUIT (`rival_director.gd:57-63`) raises it but discards which rival.
- `betrayal_target` (`loyalty_scoring.gd:112`) = first player RACKET not CONTESTED.
- Single rival = filter `GameState.factions` on `is_player == false` (established ad-hoc pattern, `rival_director.gd:16-17`).
- Enums: `JobOrigin` (enums.gd:82) append-only; `ControlState`: UNKNOWN=0, CONTESTED=1, INFLUENCED=2, CONTROLLED=3, FORTIFIED=4, COMPROMISED=5; `RivalAction.EXPAND=0`; `VenueType.RACKET=0`.

**Test command prefix (all tasks):**
```
GODOT="D:/Godot/Godot_v4.7-stable_win64.exe"
```

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `src/core/enums.gd` | shared enums | append `TERRITORY_LOSS` to `JobOrigin` |
| `src/core/character_data.gd` | character state | add `recruited_by_faction: StringName` |
| `src/ai/rival_director.gd` | rival actions | RECRUIT records `recruited_by_faction` |
| `src/simulation/relationship_service.gd` | betrayal land | hand venue to rival (owner+INFLUENCED); emit rival on `betrayal_committed` |
| `src/core/world_seed.gd` | world seed | add one neutral CONTESTED racket |
| `src/jobs/job_templates.gd` | authored jobs | `contested_ground()` + 2 variants + `CONTESTED_VARIANTS` |
| `src/jobs/job_generator.gd` | sim→job mapping | `contested_ground_job()` + `rebuild` "contested" branch |
| `src/jobs/job_director.gd` | job wiring | EXPAND arm, betrayal arm, resolution branch |
| `src/save/save_codec.gd` | save encode/decode | persist `recruited_by_faction` |
| `tests/unit/test_territory_loss_p08b.gd` (+ `.tscn`) | new tests | generation determinism, rebuild, reclaim |

---

## Task 1: Add `TERRITORY_LOSS` JobOrigin

**Files:**
- Modify: `src/core/enums.gd:82-89`

- [ ] **Step 1: Append the enum value**

Change the `JobOrigin` enum (currently ends at `EVIDENCE_CHAIN,`) to:

```gdscript
enum JobOrigin {
	FAILED_RACKET,
	WITNESS,
	RIVAL_PROVOCATION,
	INTERNAL_DISPUTE,
	INSTITUTIONAL_PRESSURE,
	EVIDENCE_CHAIN,
	TERRITORY_LOSS,
}
```

Appended at the END (save codec persists origin as int; appending is save-safe).

- [ ] **Step 2: Verify it parses**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
```
Expected: empty (no parse errors).

- [ ] **Step 3: Commit**

```bash
git add src/core/enums.gd
git commit -m "feat(p08b): add TERRITORY_LOSS job origin"
```

---

## Task 2: Record which rival recruited a lieutenant

The betrayal must know which rival to hand the venue to. Add a field to CharacterData, set it when a rival RECRUITs, persist it in saves.

**Files:**
- Modify: `src/core/character_data.gd` (after line 20, the `rival_leverage` field)
- Modify: `src/ai/rival_director.gd:57-63` (RECRUIT branch)
- Modify: `src/save/save_codec.gd` (character encode + decode)

- [ ] **Step 1: Add the field to CharacterData**

After the `rival_leverage` line (`character_data.gd:20`), add:

```gdscript
## Which rival faction last RECRUITed this character (&"" = none). Set by RivalDirector's
## RECRUIT land; read by RelationshipService when the betrayal hands the venue over. Kept
## distinct from rival_leverage (the anonymous strength scalar) so the destination is explicit.
@export var recruited_by_faction: StringName = &""
```

- [ ] **Step 2: Record it in the RECRUIT branch**

In `rival_director.gd`, the RECRUIT branch (lines 57-63) becomes:

```gdscript
	if action == BM.RivalAction.RECRUIT:
		var character := GameState.get_character(target_id)
		if character == null:
			return
		character.rival_leverage = clampf(
			character.rival_leverage + RivalScoring.RECRUIT_LEVERAGE, 0.0, 1.0)
		character.recruited_by_faction = rival.id  # remember the destination for a later betrayal
		rival_action_landed.emit(rival, null, action)
		return
```

- [ ] **Step 3: Persist it in save_codec — find the character encode/decode**

Run:
```
grep -nE "rival_leverage|encode_character|decode_character|betrayal_ticks_until_land" src/save/save_codec.gd
```
Expected: shows the character encode dict and decode function with `rival_leverage` written and read.

- [ ] **Step 4: Add the field to encode + decode**

In the character ENCODE dict (wherever `"rival_leverage": c.rival_leverage` appears), add alongside it:
```gdscript
		"recruited_by_faction": c.recruited_by_faction,
```
In the character DECODE (wherever `c.rival_leverage = d["rival_leverage"]` appears), add alongside it:
```gdscript
	c.recruited_by_faction = StringName(d.get("recruited_by_faction", &""))
```
(Use `.get` with default so older saves without the key load clean.)

- [ ] **Step 5: Verify parse + save round-trip still green**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
"$GODOT" --headless --path . -s tests/integration/save_roundtrip_runner.gd 2>&1 | tail -5
```
Expected: no parse errors; save round-trip prints its PASS line and exits 0.

- [ ] **Step 6: Commit**

```bash
git add src/core/character_data.gd src/ai/rival_director.gd src/save/save_codec.gd
git commit -m "feat(p08b): record recruiting rival on character, persist it"
```

---

## Task 3: Betrayal hands the venue to the rival

Change betrayal `_land` so the defected venue transfers to the rival (owner + INFLUENCED) instead of only going CONTESTED, and carry the rival on the `betrayal_committed` signal so the job trigger knows the new owner.

**Files:**
- Modify: `src/simulation/relationship_service.gd:17` (signal), `:61-68` (`_land`)

- [ ] **Step 1: Widen the betrayal_committed signal**

Change line 17:
```gdscript
signal betrayal_committed(character: CharacterData, venue: VenueData, rival: FactionData)
```

- [ ] **Step 2: Rewrite `_land` to transfer ownership**

Replace the `_land` body (lines 61-68) with:

```gdscript
func _land(c: CharacterData) -> void:
	c.betrayal_ticks_until_land = -1
	var venue := LoyaltyScoring.betrayal_target(GameState.districts, c.faction_id)
	var rival := _defection_rival(c)
	if venue != null and rival != null:
		# The turncoat delivers the venue to the rival they were recruited to — territory changes
		# hands (the one place ownership shifts on betrayal). Was CONTESTED-only; now a real loss.
		venue.owner_faction = rival.id
		venue.control_state = BM.ControlState.INFLUENCED
	c.grievance = 0.0
	c.rival_leverage = 0.0
	c.recruited_by_faction = &""
	betrayal_committed.emit(c, venue, rival)

## The rival a betrayal delivers to: the faction that RECRUITed this lieutenant, or — if the
## betrayal grew from grievance/ambition with no explicit recruiter — the single rival faction
## (the vertical slice has one; filter is_player, first match, the established ad-hoc pattern).
static func _defection_rival(c: CharacterData) -> FactionData:
	if c.recruited_by_faction != &"":
		var f := GameState.get_faction(c.recruited_by_faction)
		if f != null:
			return f
	for faction in GameState.factions:
		if not faction.is_player:
			return faction
	return null
```

- [ ] **Step 3: Update any existing `betrayal_committed` listeners to the new arity**

Run:
```
grep -rn "betrayal_committed" src/ scenes/ tests/
```
Expected: shows the signal decl + emit + any `.connect(...)` handlers. For EACH handler `func _on_betrayal(character, venue):`, add the third param `, rival: FactionData` (a handler ignoring it still needs the parameter to match the signal). If a handler is a lambda or bind, update its signature the same way. If the only occurrences are the decl (line 17) and emit (line 68), there are no listeners yet — nothing else to change.

- [ ] **Step 4: Verify parse + P10 loyalty tests still green**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
"$GODOT" --headless --path . -s tests/unit/test_loyalty.gd 2>&1 | tail -5
"$GODOT" --headless --path . -s tests/unit/test_loyalty_p10b.gd 2>&1 | tail -5
```
Expected: no parse errors; both loyalty tests print PASS and exit 0. (If a loyalty test asserts the betrayed venue is CONTESTED, it must be updated to expect INFLUENCED + rival owner — read the failing assertion and fix the expectation, do not weaken the test.)

- [ ] **Step 5: Commit**

```bash
git add src/simulation/relationship_service.gd
git commit -m "feat(p08b): betrayal hands the venue to the recruiting rival"
```

---

## Task 4: Seed one neutral venue the rival can EXPAND

**Files:**
- Modify: `src/core/world_seed.gd:105-118` (the `d.venues = [ ... ]` literal)

- [ ] **Step 1: Add a neutral CONTESTED racket to the venue literal**

Inside the `d.venues = [ ... ]` array literal (line 105 onward), add one more element after the existing venues (before the closing `]`). Copy the `_racket` pattern with `owner = &""` and `state = CONTESTED`:

```gdscript
	_racket(&"gw_saltworks", "Abandoned Saltworks", BM.RacketKind.CONTRABAND_LOGISTICS,
		&"", BM.ControlState.CONTESTED, 90, 1, Vector2(20, -3.0)),
```

(Neutral, low yield/staff — a marginal lot on the wharf that neither dynasty holds, so the rival's utility AI EXPANDs it and the first Contested-Ground loop fires. `RacketKind.CONTRABAND_LOGISTICS` is a known-valid kind from the existing seed; keep the position clear of other venues.)

- [ ] **Step 2: Verify it parses and the venue exists at boot**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
"$GODOT" --headless --path . --quit-after 40 2>&1 | grep -iE "SCRIPT ERROR|Nonexistent" | grep -v "godot_ai\|_mcp"
```
Expected: both empty (clean parse + boot).

- [ ] **Step 3: Commit**

```bash
git add src/core/world_seed.gd
git commit -m "feat(p08b): seed one neutral contested venue as EXPAND bait"
```

---

## Task 5: Author the "Contested Ground" job template

Two variants sharing one choice-id set, honoring the P06d envelope (loudest full lifecycle ≥ +0.25 evidence, quietest ≤ −0.3). Mirrors `retaliation()` structure exactly.

**Files:**
- Modify: `src/jobs/job_templates.gd` (add const near line 11-12; add functions before the closing of the class)

- [ ] **Step 1: Add the variant count const**

Near the other variant counts (lines 11-12), add:
```gdscript
const CONTESTED_VARIANTS := 2
```

- [ ] **Step 2: Add the dispatcher + both variant builders**

Add these functions to the file (after `bury_case` variants, before `followup`):

```gdscript
## "Contested Ground" — generated when the rival takes player-adjacent territory (rival EXPAND
## onto a neutral venue, or a betrayal handing a venue over). The player reclaims it; the cost
## splits by approach. Targeting (venue, rival) stamped by JobGenerator. Two variants share one
## choice-id set and honor the P06d envelope (loudest lifecycle >= +0.25, quietest <= -0.3).
static func contested_ground(venue_name: String, rival_name: String, variant: int = 0) -> JobData:
	if variant == 1:
		return _contested_starve_them_out(venue_name, rival_name)
	return _contested_reclaim_the_wharf(venue_name, rival_name)

## Variant 0 — "Reclaim the Wharf": the flag is planted; take it back before it sets.
static func _contested_reclaim_the_wharf(venue_name: String, rival_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Reclaim the Wharf"
	job.origin = BM.JobOrigin.TERRITORY_LOSS
	job.apparent_problem = "%s planted their flag on the %s while the Compact blinked. Every day it stands, the street reads the ground as theirs." % [rival_name, venue_name]
	job.deadline_ticks = 60
	job.known_evidence = ["A fresh %s crew rota, nailed to the door" % rival_name, "Protection collectors already working the block"]
	job.visible_stakes = "Leave it and the loss becomes a fact. Take it back too loud and the district burns for a lot."
	job.hidden_stakes = "The crew holding it was promised the lot for a reason — someone is testing the Resolver's reach."
	job.reward_dirty = 250

	job.prep_actions = [
		JobChoiceData.make(&"prep_scout", "Scout the holding",
			"Two nights watching who mans the lot and when the collectors come.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_stage", "Stage alibis",
			"Every name of ours is verifiably elsewhere whatever happens tonight.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"prep_move_now", "Move before it sets",
			"Take it back tonight, before the district accepts the new flag.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_evict", "Drive them out",
			"Their crew is put off the lot in front of the block. Loud, certain, watched.",
			{&"objective_achieved": 0.75, &"public_fear": 0.25, &"evidence_generated": 0.35,
				&"rival_suspicion": 0.2}),
		JobChoiceData.make(&"appr_buyback", "Buy back the rent",
			"Match whatever the rival pays the crew, and the lot quietly changes hands again.",
			{&"objective_achieved": 0.55, &"relationship_change": 0.2, &"rival_suspicion": 0.1,
				&"evidence_generated": -0.1}),
		JobChoiceData.make(&"appr_rot", "Rot the operation",
			"Sour their new business from inside until holding the lot costs more than it earns.",
			{&"objective_achieved": 0.5, &"evidence_generated": -0.3, &"new_leverage": 0.2,
				&"delayed_consequence": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_deny", "It was always ours",
			"The paperwork says the lot never left the Compact's books.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_flaunt", "Let the block see",
			"No names, no proof — but everyone watches who took it back and how fast.",
			{&"evidence_generated": -0.05, &"public_fear": 0.25, &"delayed_consequence": 0.2}),
		JobChoiceData.make(&"cover_broker", "Send the price",
			"A back-channel note to the rival: this is what the next lot costs. Unsigned.",
			{&"evidence_generated": -0.2, &"relationship_change": 0.2, &"rival_suspicion": 0.1}),
	]
	return job

## Variant 1 — "Starve Them Out": same ids and axis shape, a colder read — no eviction scene,
## the holding is made worthless until they abandon it. Magnitudes differ, envelope preserved.
static func _contested_starve_them_out(venue_name: String, rival_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Starve Them Out"
	job.origin = BM.JobOrigin.TERRITORY_LOSS
	job.apparent_problem = "%s holds the %s now, and a fight for it is exactly the show they want. The Resolver's answer is to make the ground not worth standing on." % [rival_name, venue_name]
	job.deadline_ticks = 60
	job.known_evidence = ["Supplier invoices redirected to a %s cutout" % rival_name, "The lot's regulars have stopped coming"]
	job.visible_stakes = "A loud reclaim hands them a martyr. A quiet strangling costs time the loss keeps ticking."
	job.hidden_stakes = "One of the crew holding it is ours already, waiting to be told which way to jump."
	job.reward_dirty = 250

	job.prep_actions = [
		JobChoiceData.make(&"prep_scout", "Map the supply",
			"Follow every truck and payment that keeps the lot running.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_stage", "Clear the calendar",
			"By tonight our people are boringly, verifiably elsewhere.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"prep_move_now", "Choke it tonight",
			"Cut the supply before they dig in. No time to be careful about it.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_evict", "Break the crew",
			"The men holding it are made examples of, publicly, until no one else will man it.",
			{&"objective_achieved": 0.75, &"public_fear": 0.25, &"evidence_generated": 0.35,
				&"rival_suspicion": 0.15}),
		JobChoiceData.make(&"appr_buyback", "Turn the inside man",
			"The crew member who is already ours hands the lot back and walks away rich.",
			{&"objective_achieved": 0.55, &"relationship_change": 0.2, &"rival_suspicion": 0.1,
				&"evidence_generated": -0.1}),
		JobChoiceData.make(&"appr_rot", "Cut the supply",
			"No suppliers, no customers, no reason to stay. They leave on their own.",
			{&"objective_achieved": 0.5, &"evidence_generated": -0.3, &"new_leverage": 0.2,
				&"delayed_consequence": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_deny", "A bad investment",
			"The story writes itself: the rival overreached and the lot simply failed.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_flaunt", "Let it be known",
			"No proof — but the district learns holding Compact ground is a way to lose money.",
			{&"evidence_generated": -0.05, &"public_fear": 0.25, &"delayed_consequence": 0.2}),
		JobChoiceData.make(&"cover_broker", "Name the terms",
			"A quiet message: keep to your own lots and this stops happening to you.",
			{&"evidence_generated": -0.2, &"relationship_change": 0.2, &"rival_suspicion": 0.1}),
	]
	return job
```

- [ ] **Step 3: Verify parse**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
```
Expected: empty.

- [ ] **Step 4: Commit**

```bash
git add src/jobs/job_templates.gd
git commit -m "feat(p08b): author Contested Ground job (2 variants)"
```

---

## Task 6: Generator — build + rebuild the contested job

**Files:**
- Modify: `src/jobs/job_generator.gd` (add builder after `bury_case_job`; add `rebuild` branch)

- [ ] **Step 1: Add the builder function**

After `bury_case_job` (line 57), add:

```gdscript
## Trigger (P08b territory) — the rival took ground: a landed EXPAND onto a neutral venue, or a
## betrayal handing a venue over (JobDirector wires both arms to this). The variant is a hash of
## the id string, recomputed identically by rebuild — never stored, never a counter.
static func contested_ground_job(venue: VenueData, rival: FactionData, tick: int) -> JobData:
	var id_str := "gen@contested@%s@%s@%d" % [venue.id, rival.id, tick]
	var job := JobTemplates.contested_ground(venue.display_name, rival.display_name,
		_variant_index(id_str, JobTemplates.CONTESTED_VARIANTS))
	job.id = StringName(id_str)
	job.venue_id = venue.id
	return job
```

- [ ] **Step 2: Add the rebuild branch**

In `rebuild`, add a `"contested"` case alongside `"retaliation"` (same 5-part shape):

```gdscript
		"contested":
			if parts.size() != 5:
				return null
			var venue := _find_venue(districts, StringName(parts[2]))
			var rival := _find_faction(factions, StringName(parts[3]))
			if venue == null or rival == null:
				return null
			return contested_ground_job(venue, rival, int(parts[4]))
```

- [ ] **Step 3: Verify parse + existing job-generation test green**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
"$GODOT" --headless --path . -s tests/unit/test_job_generation.gd 2>&1 | tail -5
```
Expected: no parse errors; test_job_generation prints PASS and exits 0 (the source-scan RNG guard still passes — `contested_ground_job` uses only `_variant_index`, no RNG).

- [ ] **Step 4: Commit**

```bash
git add src/jobs/job_generator.gd
git commit -m "feat(p08b): generate + rebuild Contested Ground job"
```

---

## Task 7: JobDirector — trigger arms + reclaim resolution

**Files:**
- Modify: `src/jobs/job_director.gd:27-38` (wire betrayal + EXPAND arm), `:132-166` (resolution branch)

- [ ] **Step 1: Subscribe to the betrayal-committed signal**

In `_connect_triggers` (lines 27-30), add the RelationshipService subscription. RelationshipService is an autoload; confirm its name first:
```
grep -n "RelationshipService" project.godot
```
Then `_connect_triggers` becomes:
```gdscript
func _connect_triggers() -> void:
	RivalDirector.rival_action_landed.connect(_on_rival_action_landed)
	EconomyService.inspection_started.connect(_on_inspection_started)
	RelationshipService.betrayal_committed.connect(_on_betrayal_committed)
```

- [ ] **Step 2: Add the EXPAND arm to `_on_rival_action_landed`**

Replace `_on_rival_action_landed` (lines 33-38) with:
```gdscript
func _on_rival_action_landed(rival: FactionData, venue: VenueData, action: int) -> void:
	# SABOTAGE on a player venue → retaliation (P08). A PROBE is pressure, not a provocation.
	if action == BM.RivalAction.SABOTAGE:
		if venue == null or venue.owner_faction != GameState.player_faction_id:
			return
		_try_offer(JobGenerator.retaliation_job(venue, rival, TimeService.tick_index))
	# EXPAND onto neutral ground (venue is now the rival's) → Contested Ground (P08b territory).
	elif action == BM.RivalAction.EXPAND:
		if venue == null:
			return
		_try_offer(JobGenerator.contested_ground_job(venue, rival, TimeService.tick_index))
```

- [ ] **Step 3: Add the betrayal arm**

Add this handler (near `_on_inspection_started`):
```gdscript
## P08b territory arm: a betrayal handed a venue to the rival (RelationshipService._land set
## owner + INFLUENCED). Same job as an EXPAND loss — reclaim it. venue/rival may be null if the
## betrayal found no target; guard both.
func _on_betrayal_committed(_character: CharacterData, venue: VenueData, rival: FactionData) -> void:
	if venue == null or rival == null:
		return
	_try_offer(JobGenerator.contested_ground_job(venue, rival, TimeService.tick_index))
```

- [ ] **Step 4: Add the reclaim branch to `_apply_and_emit`**

In `_apply_and_emit`, after the RIVAL_PROVOCATION grudge block (around line 159, before the delayed_consequence block), add:
```gdscript
	# P08b: a resolved Contested Ground job with a real objective reclaims the venue — back to the
	# player, but CONTESTED (disputed, not fully controlled), so the loop stays alive. Origin-gated
	# single write, mirroring the EVIDENCE_CHAIN/RIVAL_PROVOCATION post-outcome branches.
	if job.origin == BM.JobOrigin.TERRITORY_LOSS \
			and job.outcome.get(&"objective_achieved", 0.0) >= 0.5:
		var venue := _find_venue(job.venue_id)
		if venue != null:
			venue.owner_faction = GameState.player_faction_id
			venue.control_state = BM.ControlState.CONTESTED
```

- [ ] **Step 5: Verify parse + boot smoke**

Run:
```
"$GODOT" --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v "godot_ai\|_mcp"
"$GODOT" --headless --path . --quit-after 60 2>&1 | grep -iE "SCRIPT ERROR|Nonexistent" | grep -v "godot_ai\|_mcp"
```
Expected: both empty.

- [ ] **Step 6: Commit**

```bash
git add src/jobs/job_director.gd
git commit -m "feat(p08b): wire EXPAND + betrayal arms, reclaim on resolution"
```

---

## Task 8: Unit test — generation determinism, rebuild, reclaim

**Files:**
- Create: `tests/unit/test_territory_loss_p08b.gd`
- Create: `tests/unit/test_territory_loss_p08b.tscn`

- [ ] **Step 1: Write the test scene file**

Create `tests/unit/test_territory_loss_p08b.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/unit/test_territory_loss_p08b.gd" id="1"]

[node name="TestTerritoryLossP08b" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_territory_loss_p08b.gd`:
```gdscript
extends SceneTree
## P08b territory-loss: Contested Ground generation is deterministic, rebuild round-trips,
## and the origin/variant contract holds. Pure JobGenerator/JobTemplates — no autoloads needed.

func _init() -> void:
	var failures := 0
	failures += _test_deterministic()
	failures += _test_rebuild_roundtrip()
	failures += _test_variant_in_range()
	failures += _test_origin()
	if failures == 0:
		print("test_territory_loss_p08b: PASS")
		quit(0)
	else:
		print("test_territory_loss_p08b: FAIL (%d)" % failures)
		quit(1)

func _make_venue() -> VenueData:
	var v := VenueData.new()
	v.id = &"gw_saltworks"
	v.display_name = "Abandoned Saltworks"
	return v

func _make_rival() -> FactionData:
	var f := FactionData.new()
	f.id = &"corvine"
	f.display_name = "Corvine Assembly"
	return f

func _test_deterministic() -> int:
	var a := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 42)
	var b := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 42)
	if a.id != b.id or a.title != b.title or a.origin != b.origin:
		print("  deterministic FAIL: %s vs %s" % [a.id, b.id]); return 1
	if a.id != &"gen@contested@gw_saltworks@corvine@42":
		print("  id format FAIL: %s" % a.id); return 1
	return 0

func _test_rebuild_roundtrip() -> int:
	var venue := _make_venue()
	var rival := _make_rival()
	var district := DistrictData.new()
	district.venues = [venue]
	var orig := JobGenerator.contested_ground_job(venue, rival, 7)
	var rebuilt := JobGenerator.rebuild(orig.id, [district], [rival])
	if rebuilt == null:
		print("  rebuild returned null"); return 1
	if rebuilt.id != orig.id or rebuilt.title != orig.title:
		print("  rebuild mismatch: %s/%s vs %s/%s" % [rebuilt.id, rebuilt.title, orig.id, orig.title]); return 1
	return 0

func _test_variant_in_range() -> int:
	# Both variants must be reachable and share the choice-id set; sample a spread of ticks.
	var titles := {}
	for t in range(20):
		var j := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), t)
		titles[j.title] = true
		# choice-id contract: approaches always carry the shared ids
		var ids := []
		for a in j.approaches:
			ids.append(a.id)
		if not (&"appr_evict" in ids and &"appr_buyback" in ids and &"appr_rot" in ids):
			print("  choice-id set FAIL at t=%d: %s" % [t, ids]); return 1
	if titles.size() < 2:
		print("  variant coverage FAIL: only %s reached" % [titles.keys()]); return 1
	return 0

func _test_origin() -> int:
	var j := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 1)
	if j.origin != BM.JobOrigin.TERRITORY_LOSS:
		print("  origin FAIL: %d" % j.origin); return 1
	return 0
```

- [ ] **Step 3: Run to verify it passes**

Run:
```
"$GODOT" --headless --path . -s tests/unit/test_territory_loss_p08b.gd 2>&1 | tail -5
```
Expected: `test_territory_loss_p08b: PASS`, exit 0. (If FAIL, read the specific `  ... FAIL` line — it names the broken invariant.)

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_territory_loss_p08b.gd tests/unit/test_territory_loss_p08b.tscn
git commit -m "test(p08b): Contested Ground generation determinism + rebuild"
```

---

## Task 9: Full-suite regression + full-cycle probe

- [ ] **Step 1: Run every unit test — none regressed**

Run each and confirm PASS + exit 0:
```
for t in test_economy test_evidence test_heat_consequence test_job_generation test_job_variety_p08b test_loyalty test_loyalty_p10b test_night_cycle test_rival_ai test_rival_ai_p07b test_central_pressure test_territory_loss_p08b; do
  echo "=== $t ==="
  "$GODOT" --headless --path . -s tests/unit/$t.gd 2>&1 | tail -2
done
```
Expected: every block ends in a `PASS` line. Any FAIL → read that test's assertion and reconcile (do not weaken a test; fix the code or the expectation if behavior legitimately changed, e.g. betrayal now INFLUENCED not CONTESTED).

- [ ] **Step 2: Save round-trip green**

Run:
```
"$GODOT" --headless --path . -s tests/integration/save_roundtrip_runner.gd 2>&1 | tail -3
```
Expected: PASS, exit 0 (a Contested Ground job + `recruited_by_faction` survive save/load).

- [ ] **Step 3: Boot smoke clean**

Run:
```
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent" | grep -v "godot_ai\|_mcp\|leaked at exit\|RID alloc\|Pages in use\|PagedAllocator"
```
Expected: empty.

- [ ] **Step 4: Write the full-cycle probe note**

Create `docs/prompts/notes/P08b-territory-loss-probe.md` documenting a headless observation that the chain closes: seed neutral `gw_saltworks` → rival EXPANDs it → JobDirector offers a TERRITORY_LOSS job → resolving loud (`appr_evict`) returns the venue to the player as CONTESTED. If a probe runner is needed, model it on an existing `tests/unit/test_*` that drives TimeService ticks (e.g. `test_rival_ai.gd`), asserting: (a) after enough rival ticks `gw_saltworks.owner_faction == corvine`, (b) a job with origin TERRITORY_LOSS is in `JobDirector.active_jobs`, (c) after resolving it loud, `gw_saltworks.owner_faction == player_faction_id and control_state == CONTESTED`. Record the verdict line.

- [ ] **Step 5: Commit**

```bash
git add docs/prompts/notes/P08b-territory-loss-probe.md
git commit -m "docs(p08b): territory-loss full-cycle probe note"
```

---

## Task 10: Update NOW.md + README

- [ ] **Step 1: Mark P08b territory branch done in README**

In `docs/prompts/README.md`, the P08 line notes "remaining 8 origins ... → P08b". Append that the territory-loss origin is now shipped (EXPAND + betrayal → Contested Ground, venue reclaim, deterministic + save-safe).

- [ ] **Step 2: Update NOW.md**

Add a "Bitti" bullet: P08b territory-loss origin shipped — rival takes ground (EXPAND on seed neutral venue, or betrayal handing a venue to the rival) → Contested Ground fixer job → reclaim to CONTESTED. Note betrayal now transfers ownership (was CONTESTED-only) and CharacterData carries `recruited_by_faction`.

- [ ] **Step 3: Commit**

```bash
git add docs/prompts/README.md docs/NOW.md
git commit -m "docs(p08b): mark territory-loss origin shipped in NOW + README"
```

---

## Self-Review Notes

- **Spec coverage:** seed bait (Task 4) ✓, betrayal→rival bait (Tasks 2-3) ✓, EXPAND arm (Task 7 s2) ✓, betrayal arm (Task 7 s3) ✓, two-variant template + envelope (Task 5) ✓, reclaim to CONTESTED (Task 7 s4) ✓, new origin (Task 1) ✓, determinism/rebuild/save-safety (Tasks 6, 8, 9) ✓, P10 regression guard (Task 3 s4, Task 9 s1) ✓.
- **Type consistency:** `contested_ground_job` / `contested_ground` / `CONTESTED_VARIANTS` / `recruited_by_faction` / `_defection_rival` used identically across tasks. Signal arity change (`betrayal_committed` +rival) propagated to its handler (Task 7 s3) and existing-listener sweep (Task 3 s3).
- **Envelope risk (flagged for executor):** Task 5 per-choice numbers target the P06d envelope but the FULL-lifecycle sum (prep+approach+coverup) is what `test_evidence` guards. If `test_evidence` has a Contested-Ground assertion it will catch a violation; if it does NOT yet cover this origin, Task 9 s1 will pass vacuously — the executor should add a Contested-Ground envelope assertion to `test_evidence` mirroring the retaliation one, or confirm the loudest path (prep_move_now + appr_evict + cover_flaunt = +0.1 +0.35 −0.05 = +0.40 ≥ +0.25 ✓) and quietest (prep_stage + appr_rot + cover_deny = −0.2 −0.3 −0.3 = −0.80 ≤ −0.3 ✓) by hand. Both hold by construction; the assertion makes it permanent.
