class_name JobTemplates
extends RefCounted
## Authored job-template layer (brief §7.5, P08 — formerly PlaceholderJobs). Each template
## is a static builder that supplies the AUTHORED JobData fields (text, choices, reward,
## deadline) and leaves runtime state default. Generated jobs = a template + sim-derived
## targeting stamped on by JobGenerator; they never invent content the template didn't
## author. Migrates to data/jobs/ typed resources when the authored roster grows (P16).

## Job registry: rebuild an AUTHORED job definition by id (saves store runtime state only).
## Generated ids (prefix "gen@") are rebuilt by JobGenerator.rebuild instead — SaveService
## tries this registry first, then falls back to the generator.
static func by_id(job_id: StringName) -> JobData:
	match job_id:
		&"job_intercepted_shipment":
			return intercepted_shipment()
		_:
			return null

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

## "Answer in Kind" — generated when a rival SABOTAGE lands on a player venue (P08
## trigger 1). The rival's move is the problem; the player architects the answer.
## Targeting (id, venue_id) is stamped by JobGenerator; text takes the display names.
static func retaliation(venue_name: String, rival_name: String) -> JobData:
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
			{&"objective_achieved": 0.7, &"public_fear": 0.2, &"evidence_generated": 0.1,
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
			{&"evidence_generated": -0.1, &"public_fear": 0.3, &"delayed_consequence": 0.2}),
		JobChoiceData.make(&"cover_broker", "Whisper a truce price",
			"A back-channel note: this is what the next one costs. Signed by no one.",
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
