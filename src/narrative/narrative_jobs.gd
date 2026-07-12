class_name NarrativeJobs
extends RefCounted
## P16 authored narrative jobs — the vertical slice's spine (brief §12.1, §13.2). Three
## hand-written fixer jobs woven into the Glass Wharf situation, chained by the
## NarrativeDirector: the cold open's hidden stakes ("the inspector is already feeding
## the Corvine Assembly") pull through the ledger, the lieutenant's debt, and the accord.
## Code-as-data like JobTemplates (authored content never lives in a UI scene); the
## registry route is JobTemplates.by_id -> NarrativeJobs.by_id, so saves rebuild these
## like any authored job. Runtime state stays default here — the save overlays it.

static func by_id(job_id: StringName) -> JobData:
	match job_id:
		&"job_inspectors_ledger":
			return inspectors_ledger()
		&"job_lieutenants_debt":
			return lieutenants_debt()
		&"job_meridian_accord":
			return meridian_accord()
		_:
			return null

## Beat 1 — "The Inspector's Ledger". The cold open's thread pulled: the dock inspector
## kept a private ledger of every favor bought on the wharf — Compact names on every
## page, and on the last page, the Corvine paymaster who owns him. The authored evidence
## chain beat (P06/P06b): the loud route leaves a named case in the district; the quiet
## route suppresses. Envelope (test_narrative guards it): loudest lifecycle nets
## >= +0.25 evidence, quietest <= -0.3.
static func inspectors_ledger() -> JobData:
	var job := JobData.new()
	job.id = &"job_inspectors_ledger"
	job.title = "The Inspector's Ledger"
	job.origin = BM.JobOrigin.WITNESS
	job.apparent_problem = "The dock inspector from the manifest affair kept insurance: a private ledger of every favor bought on the wharf. Compact names on every page — and on the last page, the hand that pays him. He is shopping it."
	job.venue_id = &"gw_contraband"
	job.deadline_ticks = 90
	job.known_evidence = ["A photographed ledger page, sold as a sample", "The inspector's sudden taste for expensive rooms"]
	job.visible_stakes = "Whoever buys that ledger owns half the wharf's secrets — the Compact's included."
	job.hidden_stakes = "The last page names the Corvine paymaster. The ledger cuts both ways, if you can read it first."
	job.reward_dirty = 300

	job.prep_actions = [
		JobChoiceData.make(&"prep_tail_inspector", "Tail the inspector",
			"Two days of watching who he meets and where the ledger sleeps.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
		JobChoiceData.make(&"prep_alibis", "Stage alibis",
			"Every name of ours is verifiably elsewhere the night it happens.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"prep_before_sale", "Move before the sale",
			"He meets a buyer at the week's end. Beat the appointment, skip the homework.",
			{&"delayed_consequence": 0.2, &"objective_achieved": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_quiet_lift", "Lift it quietly",
			"A hotel room, forty unwatched minutes, a ledger that was never there.",
			{&"objective_achieved": 0.65, &"evidence_generated": -0.25}),
		JobChoiceData.make(&"appr_buy_courier", "Buy the courier",
			"The go-between sells you the ledger instead — and keeps working for its old owner.",
			{&"objective_achieved": 0.55, &"relationship_change": 0.2, &"new_leverage": 0.2,
				&"evidence_generated": -0.05}),
		JobChoiceData.make(&"appr_smash_grab", "Take it loud",
			"Kick the door, take the book, let the wharf see what shopping secrets costs.",
			{&"objective_achieved": 0.8, &"evidence_generated": 0.4, &"public_fear": 0.2,
				&"collateral_damage": 0.15}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_paper_trail", "Paper over the gap",
			"The hotel register loses a night; the inspector remembers a different week.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"cover_burn_office", "Burn his office",
			"If there was ever a copy, it's ash. Ash draws attention.",
			{&"evidence_generated": 0.05, &"public_fear": 0.15, &"delayed_consequence": 0.1}),
		JobChoiceData.make(&"cover_walk", "Walk away clean",
			"Touch nothing else. A missing book should look like a nervous man's cold feet.",
			{}),
	]
	return job

## Beat 2 — "The Lieutenant's Debt". The ledger's last pages named more than the
## paymaster: the Operations Lieutenant's gambling marker was bought by a Corvine
## cutout months ago. The first loyalty crisis (P10, brief §7.6) — telegraphed here,
## caused legibly (the NarrativeDirector sets rival_leverage at beat fire), and
## PREVENTABLE: the approach decides whether the leverage dies or festers.
static func lieutenants_debt() -> JobData:
	var job := JobData.new()
	job.id = &"job_lieutenants_debt"
	job.title = "The Lieutenant's Debt"
	job.origin = BM.JobOrigin.INTERNAL_DISPUTE
	job.apparent_problem = "The ledger's arithmetic reaches inside the house: the Operations Lieutenant's old gambling marker was quietly bought by a Corvine cutout. They own his debt — which means they are holding a knife to someone the Compact trusts with territory."
	job.venue_id = &"gw_protection"
	job.involved_character_ids = [&"bengal_lt"]
	job.deadline_ticks = 75
	job.known_evidence = ["The marker, photographed in the ledger", "A cutout's collection schedule"]
	job.visible_stakes = "A lieutenant with a bought debt is a door the rival can open any night they choose."
	job.hidden_stakes = "He knows they own it. The shame is why he never came to you — and the shame is the real lever."
	job.reward_dirty = 250

	job.prep_actions = [
		JobChoiceData.make(&"prep_price_marker", "Price the marker",
			"Find the cutout and what the debt would cost to move, before anyone knows you're asking.",
			{&"new_leverage": 0.15, &"evidence_generated": -0.1}),
		JobChoiceData.make(&"prep_sound_him", "Sound him out",
			"A quiet drink, no accusations. Read how deep the water is from how he holds the glass.",
			{&"relationship_change": 0.1, &"evidence_generated": -0.1}),
		JobChoiceData.make(&"prep_watch_cutout", "Watch the cutout",
			"If the Corvine call the marker early, you want an hour's warning.",
			{&"evidence_generated": -0.1, &"new_leverage": 0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_pay_it", "Pay it off, no strings",
			"The Compact settles the marker and burns it in front of him. Nothing owed, nothing said.",
			{&"objective_achieved": 0.65, &"relationship_change": 0.35, &"evidence_generated": -0.15}),
		JobChoiceData.make(&"appr_buy_marker", "Buy the debt yourself",
			"The marker changes hands: the Corvine lose the knife, and the Compact keeps it — in a drawer he knows about.",
			{&"objective_achieved": 0.7, &"new_leverage": 0.25, &"relationship_change": -0.2,
				&"evidence_generated": -0.1}),
		JobChoiceData.make(&"appr_bait", "Leave it, and watch",
			"The debt stays theirs; the lieutenant becomes bait. Whatever they ask of him, you'll know first.",
			{&"objective_achieved": 0.4, &"relationship_change": -0.35, &"new_leverage": 0.2,
				&"evidence_generated": -0.05}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_quiet_books", "Keep it off the books",
			"No entry, no witnesses, no one else in the Compact ever hears the word 'marker'.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"cover_let_slip", "Let the street hear",
			"The district learns the Compact settles its people's debts. Loyalty advertises; so does money.",
			{&"evidence_generated": 0.05, &"public_fear": 0.1, &"delayed_consequence": 0.1}),
		JobChoiceData.make(&"cover_walk", "Walk away clean",
			"Handled is handled. The less shape this has, the less it can be used.",
			{}),
	]
	return job

## Beat 3 — "The Meridian Accord". The feud has grown expensive on both sides of the
## wharf; the Corvine Boss requests a sit-down at the Meridian Club. The approach sets
## the accord stance (truce / leverage / war) — the NarrativeDirector records it and
## the P19 endings grow from it. No territory changes hands here; the summit changes
## what the endgame is ABOUT.
static func meridian_accord() -> JobData:
	var job := JobData.new()
	job.id = &"job_meridian_accord"
	job.title = "The Meridian Accord"
	job.origin = BM.JobOrigin.RIVAL_PROVOCATION
	job.apparent_problem = "A courier in Corvine colors delivers a single card to the Meridian Club: the Boss of the Corvine Assembly will sit down — one night, neutral table, principals only. The feud has a price now, and both ledgers are paying it."
	job.venue_id = &"gw_nightclub"
	job.deadline_ticks = 90
	job.known_evidence = ["The invitation card, unsigned", "Corvine collectors pulled off two blocks this morning"]
	job.visible_stakes = "Refuse and the war resumes at full price. Sit down and the wharf watches who leaves the table taller."
	job.hidden_stakes = "She isn't offering peace. She is measuring whether the Resolver can afford to want it."
	job.reward_dirty = 400

	job.prep_actions = [
		JobChoiceData.make(&"prep_sweep_club", "Sweep the club",
			"Every room, every staffer, every sightline — the table is only neutral if you made it neutral.",
			{&"evidence_generated": -0.1, &"operative_injury": -0.2}),
		JobChoiceData.make(&"prep_read_books", "Read their books first",
			"What the feud costs THEM decides what their signature is worth.",
			{&"new_leverage": 0.15}),
		JobChoiceData.make(&"prep_council_word", "Take the Regent's word",
			"The Compact speaks with one voice at that table, or it doesn't speak.",
			{&"relationship_change": 0.1, &"evidence_generated": -0.1}),
	]

	job.approaches = [
		JobChoiceData.make(&"appr_good_faith", "Deal in good faith",
			"Split the disputed blocks, name the lines, shake on it where the street can see.",
			{&"objective_achieved": 0.6, &"relationship_change": 0.2, &"evidence_generated": -0.2}),
		JobChoiceData.make(&"appr_from_strength", "Deal from strength",
			"Lay the ledger's last page on the table and let her read her paymaster's name in your handwriting.",
			{&"objective_achieved": 0.7, &"new_leverage": 0.2, &"rival_suspicion": 0.2,
				&"evidence_generated": -0.1}),
		JobChoiceData.make(&"appr_walk_out", "Walk out",
			"Stand, button the coat, leave the card on the table. Some wars are cheaper than the peace.",
			{&"objective_achieved": 0.3, &"public_fear": 0.1, &"rival_suspicion": 0.3}),
	]

	job.coverups = [
		JobChoiceData.make(&"cover_joint_word", "A joint communiqué",
			"Both houses tell the district the same quiet sentence. Whatever was agreed, it sounds settled.",
			{&"evidence_generated": -0.2}),
		JobChoiceData.make(&"cover_own_version", "Tell it your way",
			"The wharf hears the Compact's version first and loudest.",
			{&"evidence_generated": -0.05, &"public_fear": 0.1, &"rival_suspicion": 0.1}),
		JobChoiceData.make(&"cover_say_nothing", "Say nothing",
			"No statement. Let the silence do the pricing.",
			{}),
	]
	return job
