class_name JobTemplates
extends RefCounted
## Authored job-template layer (brief §7.5, P08 — formerly PlaceholderJobs). Each template
## is a static builder that supplies the AUTHORED JobData fields (text, choices, reward,
## deadline) and leaves runtime state default. Generated jobs = a template + sim-derived
## targeting stamped on by JobGenerator; they never invent content the template didn't
## author. Migrates to data/jobs/ typed resources when the authored roster grows (P16).

## P08b: variant counts per origin. JobGenerator picks an index deterministically
## (avalanche of the id string, mod count) — never stored, always recomputed.
const RETALIATION_VARIANTS := 2
const BURY_CASE_VARIANTS := 2
const CONTESTED_VARIANTS := 2

## Job registry: rebuild an AUTHORED job definition by id (saves store runtime state only).
## Generated ids (prefix "gen@") are rebuilt by JobGenerator.rebuild instead — SaveService
## tries this registry first, then falls back to the generator.
static func by_id(job_id: StringName) -> JobData:
	match job_id:
		&"job_intercepted_shipment":
			return intercepted_shipment()
		_:
			return NarrativeJobs.by_id(job_id)  # P16 authored chain, same registry contract

## "Intercepted shipment at the Cargo Terminal" — tied to gw_contraband (WorldSeed).
## Apparent problem: a contraband run got stopped at the wharf gates and a dock
## inspector is sitting on the manifest. Some stakes are deliberately hidden.
static func intercepted_shipment() -> JobData:
	var job := JobData.new()
	job.id = &"job_intercepted_shipment"
	job.title = "Intercepted Shipment"
	job.origin = BM.JobOrigin.FAILED_RACKET
	job.apparent_problem = "A contraband run out of the Cargo Terminal was flagged at the wharf gates. A dock inspector holds the manifest and hasn't filed it yet."
	job.involved_character_ids = [&"bengal_lt"]
	job.venue_id = &"gw_contraband"
	job.deadline_ticks = 90
	job.known_evidence = ["Unfiled cargo manifest (inspector's desk)", "Gate camera footage, 02:14"]
	job.visible_stakes = "If the manifest is filed, the Cargo Terminal racket takes a named investigation."
	job.hidden_stakes = "The inspector is already feeding the Corvine Assembly."  # not shown at intake
	job.reward_dirty = 400

	job.prep_actions = [
		JobChoiceData.make(&"prep_scout", "Scout the inspector",
			"A day of eyes on his routine — where he eats, who he calls.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_bribe_clerk", "Buy the gate clerk",
			"The clerk misplaces tonight's gate log. Costs favors; someone notices.",
			{&"evidence_generated": -0.2, &"rival_suspicion": 0.1}),
		JobChoiceData.make(&"prep_lookouts", "Post lookouts",
			"Two of ours watching approach routes during the intervention.",
			{&"operative_injury": -0.2}),
		JobChoiceData.make(&"prep_rush", "Move tonight",
			"No time to prepare properly — beat the filing deadline instead.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_quiet", "Quiet re-route",
			"Slip the cargo out through the maintenance dock; the inspector finds an empty hold.",
			{&"objective_achieved": 0.7, &"evidence_generated": 0.1}),
		JobChoiceData.make(&"appr_force", "Armed recovery",
			"Take the manifest and the cargo back at gunpoint. Loud, fast, certain.",
			{&"objective_achieved": 0.95, &"public_fear": 0.3, &"collateral_damage": 0.2,
				&"operative_injury": 0.3, &"evidence_generated": 0.2}),
		JobChoiceData.make(&"appr_deal", "Cut the inspector in",
			"Offer him a monthly retainer to lose the manifest and stay lost.",
			{&"objective_achieved": 0.5, &"relationship_change": 0.3, &"new_leverage": 0.2,
				&"rival_suspicion": 0.1}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_paper", "Paper it over",
			"A corrected manifest, a backdated transfer order. Clean, slow, deniable.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_scapegoat", "Blame a dockhand",
			"A loyal nobody takes the fall. Your people remember what loyalty bought him.",
			{&"evidence_generated": -0.4, &"relationship_change": -0.4, &"collateral_damage": 0.2}),
		JobChoiceData.make(&"cover_silence", "Silence the witness",
			"The inspector stops being a problem. Permanently. The wharf notices.",
			{&"evidence_generated": -0.5, &"public_fear": 0.3, &"collateral_damage": 0.3,
				&"delayed_consequence": 0.3}),
	]
	return job

## Retaliation — generated when a rival SABOTAGE lands on a player venue (P08 trigger 1).
## The rival's move is the problem; the player architects the answer. Targeting (id,
## venue_id) is stamped by JobGenerator; text takes the display names.
## P08b: two authored variants — 0 = "Answer in Kind" (the street expects symmetry),
## 1 = "The Message" (a colder, surgical demonstration). The index is a deterministic
## hash of the id-encoded targeting, computed by JobGenerator — never stored.
## Variant contract: BOTH variants share the same choice-id set (saved chosen_* ids and
## id-referencing tests stay valid whichever variant the hash lands on) and BOTH honor
## the P06d balance envelope (test_evidence guards it): the loudest route must net
## >= +0.25 evidence (a visible reprisal leaves a trail — the feud feeds the police
## line) while the quietest stays <= -0.3 (a careful answer keeps you clean).
static func retaliation(venue_name: String, rival_name: String, variant: int = 0) -> JobData:
	if variant == 1:
		return _retaliation_the_message(venue_name, rival_name)
	return _retaliation_answer_in_kind(venue_name, rival_name)

## Variant 0 — "Answer in Kind": the hit was public, the street expects symmetry.
static func _retaliation_answer_in_kind(venue_name: String, rival_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Answer in Kind"
	job.origin = BM.JobOrigin.RIVAL_PROVOCATION
	job.apparent_problem = "%s crews hit the %s — machinery fouled, a shift boss beaten in front of his people. The street is watching how the Compact answers." % [rival_name, venue_name]
	job.deadline_ticks = 60
	job.known_evidence = ["A wrecker's pry-bar, no serial", "The shift boss saw the crew's colors"]
	job.visible_stakes = "Answer too soft and every rival reads the Wharf as open. Answer too loud and the city answers back."
	job.hidden_stakes = "The crew was paid through a cutout — the trail doesn't end where it seems to."
	job.reward_dirty = 250

	job.prep_actions = [
		JobChoiceData.make(&"prep_trace_crew", "Trace the crew",
			"Follow the pry-bar back through the pawnshops to whoever handed it out.",
			{&"new_leverage": 0.15, &"evidence_generated": -0.1}),
		JobChoiceData.make(&"prep_stage_alibis", "Stage alibis",
			"Every name of ours has a paid witness for tonight, whatever happens.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"prep_answer_tonight", "Answer tonight",
			"Before the story sets. No time to check whose story it is.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_mirror", "Mirror the damage",
			"Their nearest operation loses exactly what yours did. Symmetry is the message.",
			{&"objective_achieved": 0.7, &"public_fear": 0.2, &"evidence_generated": 0.35,
				&"rival_suspicion": 0.2}),
		JobChoiceData.make(&"appr_feed_inspectors", "Feed them to the inspectors",
			"A tidy dossier on the crew lands on an honest desk. The law does your hitting.",
			{&"objective_achieved": 0.6, &"new_leverage": 0.2, &"evidence_generated": 0.1,
				&"rival_suspicion": 0.1}),
		JobChoiceData.make(&"appr_absorb", "Absorb the hit",
			"Rebuild fast, pay the shift boss triple, and let the calm read as strength.",
			{&"objective_achieved": 0.4, &"relationship_change": 0.3, &"new_leverage": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_deny", "Deny everything",
			"The Compact heard about the unpleasantness and hopes the district stays safe.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_flaunt", "Let the street know",
			"No names, no proof — but everyone hears who answered and how fast.",
			{&"evidence_generated": -0.05, &"public_fear": 0.3, &"delayed_consequence": 0.2}),
		JobChoiceData.make(&"cover_broker", "Whisper a truce price",
			"A back-channel note: this is what the next one costs. Signed by no one.",
			{&"evidence_generated": -0.2, &"relationship_change": 0.2, &"rival_suspicion": 0.1}),
	]
	return job

## Variant 1 — "The Message": no symmetry, no heat-of-the-moment. One precise,
## unmistakable demonstration aimed at whoever gave the order, not the crew who obeyed
## it. Same choice-id set and outcome-axis shape as variant 0; effect magnitudes differ
## but stay inside the P06d envelope (loudest lifecycle >= +0.25, quietest <= -0.3).
static func _retaliation_the_message(venue_name: String, rival_name: String) -> JobData:
	var job := JobData.new()
	job.title = "The Message"
	job.origin = BM.JobOrigin.RIVAL_PROVOCATION
	job.apparent_problem = "%s put a wrecking crew through the %s and made sure it was watched. Symmetry is what they expect. The Resolver's answer should be read twice: once by the street, once by the man who signed the order." % [rival_name, venue_name]
	job.deadline_ticks = 60
	job.known_evidence = ["A payout envelope, wrong district's paper", "The crew drank two blocks east before the hit"]
	job.visible_stakes = "An answer aimed at the crew punishes the gloves, not the hand. Miss the hand and this happens again, cheaper."
	job.hidden_stakes = "The order was signed by someone auditioning for a bigger chair — the reprisal is their references."
	job.reward_dirty = 250

	job.prep_actions = [
		JobChoiceData.make(&"prep_trace_crew", "Name the paymaster",
			"Follow the envelope, not the pry-bar — find who paid, not who swung.",
			{&"new_leverage": 0.2, &"evidence_generated": -0.05}),
		JobChoiceData.make(&"prep_stage_alibis", "Clear the calendar",
			"By tonight every name of ours is verifiably, boringly elsewhere.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"prep_answer_tonight", "Send it before dawn",
			"A message loses its meaning if it arrives late. Skip the homework.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_mirror", "Make an example",
			"Their captain's car burns at noon, in front of his crew. Nobody touched; everybody schooled.",
			{&"objective_achieved": 0.7, &"public_fear": 0.3, &"evidence_generated": 0.35,
				&"rival_suspicion": 0.15}),
		JobChoiceData.make(&"appr_feed_inspectors", "Post the ledger",
			"The paymaster's private accounts, photographed page by page, reach an honest desk.",
			{&"objective_achieved": 0.6, &"new_leverage": 0.2, &"evidence_generated": 0.1,
				&"rival_suspicion": 0.1}),
		JobChoiceData.make(&"appr_absorb", "The open window",
			"The man who signed the order wakes to an open bedroom window and nothing taken. Nothing needs to be.",
			{&"objective_achieved": 0.45, &"new_leverage": 0.25, &"relationship_change": 0.1,
				&"evidence_generated": -0.05}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_deny", "We were never there",
			"Every hand involved is out of the district by morning; the Compact expresses concern.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_flaunt", "Sign the work",
			"No proof, no names — but the craftsmanship is unmistakably yours, and meant to be.",
			{&"evidence_generated": -0.05, &"public_fear": 0.3, &"delayed_consequence": 0.2}),
		JobChoiceData.make(&"cover_broker", "Send the invoice",
			"A courier delivers an itemized bill for the damage, payable in territory. No signature.",
			{&"evidence_generated": -0.2, &"relationship_change": 0.2, &"rival_suspicion": 0.1}),
	]
	return job

## "Bury the Case" — generated when an inspection lands while a named evidence case
## pins the district (P06b trigger). The job targets ONE case: a clean resolution nets
## strongly negative evidence (the targeted case burns — JobDirector removes it); the
## clumsy route nets POSITIVE evidence on every cover-up (a botched burn leaves more
## trace than it removes, and the case stands). Targeting is stamped by JobGenerator.
## P08b: two authored variants — 0 = "Bury the Case" (attack the paper), 1 = "Break the
## Chain" (attack the people who vouch for the paper). Index chosen deterministically by
## JobGenerator. Variant contract: same choice-id set AND byte-identical effects — the
## burn/botch math (test_evidence) reads exact per-choice numbers, so variant 1 differs
## in reading experience only; the mechanics are the shared spine.
static func bury_case(case_label: String, district_name: String, variant: int = 0) -> JobData:
	if variant == 1:
		return _bury_case_break_the_chain(case_label, district_name)
	return _bury_case_bury_the_case(case_label, district_name)

## Variant 0 — "Bury the Case": the case is paper in a room; make the paper stop existing.
static func _bury_case_bury_the_case(case_label: String, district_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Bury the Case"
	job.origin = BM.JobOrigin.EVIDENCE_CHAIN
	job.apparent_problem = "The sweep in %s is standing on one thing: %s. It sits in an evidence room tonight and in a prosecutor's opening statement next month." % [district_name, case_label.to_lower()]
	job.deadline_ticks = 60
	job.known_evidence = [case_label]
	job.visible_stakes = "While that case stands, the inspectors keep coming back — cooling the street buys nothing."
	job.hidden_stakes = "Someone inside the evidence room has been photographing intake logs."  # not shown at intake
	job.reward_dirty = 200

	job.prep_actions = [
		JobChoiceData.make(&"prep_case_room", "Case the records room",
			"Two nights of watching shift changes and door codes. Quiet feet, short list.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_learn_names", "Learn who signed it",
			"Every case has custodians. Custodians have rents, debts, daughters in school.",
			{&"new_leverage": 0.15}),
		JobChoiceData.make(&"prep_go_early", "Go before the transfer",
			"The file moves to Central soon. Beat the truck instead of the locks.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_torch", "Torch the archive",
			"A small electrical fire, a crowded night. The case dies with a shelf of others.",
			{&"objective_achieved": 0.75, &"evidence_generated": -0.45, &"public_fear": 0.2,
				&"collateral_damage": 0.2}),
		JobChoiceData.make(&"appr_custodian", "Buy the custodian",
			"The intake clerk re-labels one box. Nothing burns; something is simply never found.",
			{&"objective_achieved": 0.6, &"evidence_generated": -0.4, &"relationship_change": 0.2,
				&"rival_suspicion": 0.1}),
		JobChoiceData.make(&"appr_snatch", "Snatch it tonight",
			"Crowbar, window, forty seconds. Fast, loud, and everything you touch remembers you.",
			{&"objective_achieved": 0.5, &"evidence_generated": 0.2, &"delayed_consequence": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_never_was", "It never existed",
			"The intake ledger loses a line; the docket number was always a clerical error.",
			{&"evidence_generated": -0.15}),
		JobChoiceData.make(&"cover_misfile", "Misfile the duplicate",
			"The backup copy goes to a basement in the wrong precinct, addressed to no one.",
			{&"evidence_generated": -0.1, &"delayed_consequence": 0.1}),
		JobChoiceData.make(&"cover_walk", "Walk away clean",
			"Touch nothing else. The absence should look like bureaucracy, not intent.",
			{}),
	]
	return job

## Variant 1 — "Break the Chain": a case is only as strong as the people who swear to
## it. Same ids, same effect dicts as variant 0 (the burn math is shared); the read is
## a different job — custody signatures instead of archive shelves.
static func _bury_case_break_the_chain(case_label: String, district_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Break the Chain"
	job.origin = BM.JobOrigin.EVIDENCE_CHAIN
	job.apparent_problem = "The sweep in %s stands on people, not paper: %s is only as strong as the three signatures on its chain of custody — and signatures belong to people with rents, debts and reasons." % [district_name, case_label.to_lower()]
	job.deadline_ticks = 60
	job.known_evidence = [case_label]
	job.visible_stakes = "Every custodian who stands behind that case keeps the inspectors coming. Break one link and the whole chain reads as hearsay."
	job.hidden_stakes = "One of the signatories has quietly asked for protection — from you or from his own side, unclear."  # not shown at intake
	job.reward_dirty = 200

	job.prep_actions = [
		JobChoiceData.make(&"prep_case_room", "Map the chain",
			"Every hand that touched the case, intake to vault. Names, shifts, walking routes.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_learn_names", "Price the weakest link",
			"Of the three custodians, one gambles, one grieves, one wants a transfer. Pick the lever.",
			{&"new_leverage": 0.15}),
		JobChoiceData.make(&"prep_go_early", "Move before the deposition",
			"The custodians are scheduled to swear their signatures next week. Beat the calendar.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_torch", "Ruin the signatory",
			"The intake officer's debts surface loudly and publicly. A compromised chain is no chain.",
			{&"objective_achieved": 0.75, &"evidence_generated": -0.45, &"public_fear": 0.2,
				&"collateral_damage": 0.2}),
		JobChoiceData.make(&"appr_custodian", "Buy a recantation",
			"One custodian comes to remember signing a different box on a different night.",
			{&"objective_achieved": 0.6, &"evidence_generated": -0.4, &"relationship_change": 0.2,
				&"rival_suspicion": 0.1}),
		JobChoiceData.make(&"appr_snatch", "Lean on him tonight",
			"A late knock, two large silhouettes, one short sentence. Fast, crude, remembered.",
			{&"objective_achieved": 0.5, &"evidence_generated": 0.2, &"delayed_consequence": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_never_was", "A paperwork mix-up",
			"The recantation gets filed as a routine correction; the docket quietly loses its spine.",
			{&"evidence_generated": -0.15}),
		JobChoiceData.make(&"cover_misfile", "Transfer the man",
			"The bought custodian gets the posting he always wanted, two districts away, effective now.",
			{&"evidence_generated": -0.1, &"delayed_consequence": 0.1}),
		JobChoiceData.make(&"cover_walk", "Walk away clean",
			"No follow-up, no favors called in. A weak witness should look like a weak witness.",
			{}),
	]
	return job

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

## "Loose Ends" — generated K ticks after a job resolves with heavy delayed_consequence
## (P08 trigger 2). The earlier intervention's debris surfaces as a new problem.
static func followup(venue_name: String) -> JobData:
	var job := JobData.new()
	job.title = "Loose Ends"
	job.origin = BM.JobOrigin.FAILED_RACKET
	job.apparent_problem = "The dust from the %s affair never settled. A name you thought buried is being asked about — by someone with either a badge or a grudge." % venue_name
	job.deadline_ticks = 75
	job.known_evidence = ["A pawned item that should not have surfaced", "A bar tab paid with marked bills"]
	job.visible_stakes = "Left alone, the loose end unspools into a named case against the venue."
	job.hidden_stakes = "Whoever is pulling the thread already knows more than they let on."
	job.reward_dirty = 300

	job.prep_actions = [
		JobChoiceData.make(&"prep_ears", "Put ears on it",
			"Find out who is asking, and whether they drink alone.",
			{&"new_leverage": 0.1, &"evidence_generated": -0.1}),
		JobChoiceData.make(&"prep_move_stash", "Move the stash",
			"Everything connected to the old job changes address tonight.",
			{&"evidence_generated": -0.2, &"delayed_consequence": 0.1}),
		JobChoiceData.make(&"prep_hush_fund", "Ready hush money",
			"A clean envelope, thick enough that nobody counts it twice.",
			{&"relationship_change": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_buy_silence", "Buy the silence",
			"Whatever they think they know becomes something they were paid to forget.",
			{&"objective_achieved": 0.6, &"relationship_change": 0.2, &"rival_suspicion": 0.1}),
		JobChoiceData.make(&"appr_burn_trail", "Burn the trail",
			"The pawnshop has a fire. The bar changes owners. Fast, loud, final.",
			{&"objective_achieved": 0.75, &"evidence_generated": 0.15, &"collateral_damage": 0.2,
				&"public_fear": 0.1}),
		JobChoiceData.make(&"appr_smaller_truth", "Feed them a smaller truth",
			"Hand over a real, minor sin — enough to close the question without opening the case.",
			{&"objective_achieved": 0.5, &"evidence_generated": 0.1, &"new_leverage": 0.2}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_ledger", "Rewrite the ledger",
			"By morning the paper trail agrees with the story you prefer.",
			{&"evidence_generated": -0.3}),
		JobChoiceData.make(&"cover_rumor", "Start a better rumor",
			"The district gets a juicier story to chew on than yours.",
			{&"evidence_generated": -0.2, &"public_fear": 0.1}),
		JobChoiceData.make(&"cover_walk_away", "Walk away clean",
			"Touch nothing else. Sometimes the smart cover-up is no cover-up at all.",
			{&"delayed_consequence": 0.2}),
	]
	return job
