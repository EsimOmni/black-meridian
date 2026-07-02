class_name PlaceholderJobs
extends RefCounted
## Month-1 authored placeholder job (brief §7.5, P03). Built in code for now;
## migrates to data/jobs/ typed resources with the P08 job generation work.

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
