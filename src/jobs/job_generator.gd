class_name JobGenerator
extends RefCounted
## Pure sim-trigger -> job mapping (brief §7.5, P08) — split from JobDirector so it
## unit-tests headless, like EconomyMath/RivalScoring (tasks/lessons.md). PURELY
## DETERMINISTIC: the same trigger on the same sim state produces the identical job —
## no random number generation or seeded jitter anywhere (P08 house rule, brief §7.6;
## P08b template variety within an origin is a deterministic hash of the id-encoded
## targeting — still not randomness). Enforced by test_job_generation's source scan.
##
## A generated job = an authored JobTemplates builder + sim-derived targeting. The id
## encodes everything needed to rebuild the content ("gen@<template>@<targeting>@<tick>"),
## so saves keep storing runtime state only (P02 contract) — rebuild() re-runs the same
## builder with the parsed inputs and returns the identical job. The generator READS sim
## objects passed to it; it never recomputes economy/heat/rival state and never writes it.

## Below this, a resolved job's delayed_consequence fades quietly; at or above it, the
## debris surfaces as a follow-up problem. Authored data: rushing (+0.2) alone stays
## under; silencing a witness (+0.3), rush+silence (+0.5) or letting a job expire (0.5)
## all cross it.
const FOLLOWUP_THRESHOLD := 0.25
## Strategic ticks between a heavy resolution and its follow-up surfacing — long enough
## to read as "later", short enough to land inside the same Night Cycle (brief §5.1).
const FOLLOWUP_LEAD_TICKS := 20

const GENERATED_PREFIX := "gen@"

## Trigger 1 — a rival SABOTAGE landed on a player venue (RivalDirector.rival_action_landed).
## P08b: the template variant is a hash of the id string ITSELF — by construction the
## pick derives only from id-encoded inputs, so rebuild() (which re-enters this function
## with the parsed inputs) recomputes the identical index. Never stored, never a counter.
static func retaliation_job(venue: VenueData, rival: FactionData, tick: int) -> JobData:
	var id_str := "gen@retaliation@%s@%s@%d" % [venue.id, rival.id, tick]
	var job := JobTemplates.retaliation(venue.display_name, rival.display_name,
		_variant_index(id_str, JobTemplates.RETALIATION_VARIANTS))
	job.id = StringName(id_str)
	job.venue_id = venue.id
	return job

## Trigger 2 — a resolved job's delayed_consequence crossed FOLLOWUP_THRESHOLD,
## FOLLOWUP_LEAD_TICKS ago (JobDirector holds the window; this just builds the job).
static func followup_job(venue: VenueData, tick: int) -> JobData:
	var job := JobTemplates.followup(venue.display_name)
	job.id = StringName("gen@followup@%s@%d" % [venue.id, tick])
	job.venue_id = venue.id
	return job

## Trigger 3 (P06b) — an inspection landed while evidence cases pin the district
## (JobDirector._on_inspection_started offers a burn against the strongest case).
## venue_id stays empty: the job targets a CASE, and the district is encoded in the id
## (JobDirector._district_of parses it back out).
static func bury_case_job(evidence_case: EvidenceCaseData, district: DistrictData,
		tick: int) -> JobData:
	var id_str := "gen@burycase@%s@%s@%d" % [district.id, evidence_case.id, tick]
	var job := JobTemplates.bury_case(evidence_case.label, district.display_name,
		_variant_index(id_str, JobTemplates.BURY_CASE_VARIANTS))
	job.id = StringName(id_str)
	return job

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

## Rebuild a generated job's authored content from its id (SaveService load path — the
## generated-id counterpart of JobTemplates.by_id). Deterministic: re-runs the same
## builder with the parsed targeting. Returns null for non-generated or unresolvable ids.
static func rebuild(job_id: StringName, districts: Array[DistrictData],
		factions: Array[FactionData]) -> JobData:
	var s := String(job_id)
	if not s.begins_with(GENERATED_PREFIX):
		return null
	var parts := s.split("@")
	match parts[1]:
		"retaliation":
			if parts.size() != 5:
				return null
			var venue := _find_venue(districts, StringName(parts[2]))
			var rival := _find_faction(factions, StringName(parts[3]))
			if venue == null or rival == null:
				return null
			return retaliation_job(venue, rival, int(parts[4]))
		"contested":
			if parts.size() != 5:
				return null
			var venue := _find_venue(districts, StringName(parts[2]))
			var rival := _find_faction(factions, StringName(parts[3]))
			if venue == null or rival == null:
				return null
			return contested_ground_job(venue, rival, int(parts[4]))
		"followup":
			if parts.size() != 4:
				return null
			var venue := _find_venue(districts, StringName(parts[2]))
			if venue == null:
				return null
			return followup_job(venue, int(parts[3]))
		"burycase":
			# gen@burycase@<district>@<case id>@<tick>, where the case id is itself
			# 4 "@"-segments (case@<district>@<kind>@<tick>) -> 8 parts total.
			if parts.size() != 8:
				return null
			var district := _find_district(districts, StringName(parts[2]))
			if district == null:
				return null
			var evidence_case := EvidenceMath.find_case(district,
				StringName("@".join(parts.slice(3, 7))))
			if evidence_case == null:  # the case is gone — the job can't be rebuilt honestly
				return null
			return bury_case_job(evidence_case, district, int(parts[7]))
	return null

## P08b — deterministic variant pick: avalanche of the id-encoded string, non-negative
## modulo variant count (the ((m % n) + n) % n dance because m can be negative). A pure
## function of the id string, so save → load → rebuild lands on the same variant forever.
static func _variant_index(seed_str: String, count: int) -> int:
	var m := _avalanche(seed_str.hash())
	return ((m % count) + count) % count

## splitmix64 finalizer — DELIBERATE 3-line duplicate of RivalScoring._avalanche (P07b,
## proven). String.hash() (DJB2) alone has near-zero avalanche — a +1 tick would barely
## move the bucket and the variant would freeze to one side. rival_scoring.gd is shipped
## and gated; per the P08b spec (option A) we copy rather than reopen a green file for a
## cross-file refactor. Keep the two copies byte-identical if either ever changes.
static func _avalanche(x: int) -> int:
	x = (x ^ (x >> 30)) * -49064778989728563
	x = (x ^ (x >> 27)) * -4265267296055464877
	return x ^ (x >> 31)

static func _find_district(districts: Array[DistrictData], district_id: StringName) -> DistrictData:
	for district in districts:
		if district.id == district_id:
			return district
	return null

static func _find_venue(districts: Array[DistrictData], venue_id: StringName) -> VenueData:
	for district in districts:
		for venue in district.venues:
			if venue.id == venue_id:
				return venue
	return null

static func _find_faction(factions: Array[FactionData], faction_id: StringName) -> FactionData:
	for faction in factions:
		if faction.id == faction_id:
			return faction
	return null
