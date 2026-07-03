class_name JobGenerator
extends RefCounted
## Pure sim-trigger -> job mapping (brief §7.5, P08) — split from JobDirector so it
## unit-tests headless, like EconomyMath/RivalScoring (tasks/lessons.md). PURELY
## DETERMINISTIC: the same trigger on the same sim state produces the identical job —
## no random number generation or seeded jitter anywhere (P08 house rule, brief §7.6;
## template variety within an origin is P08b, as a deterministic hash — still not
## randomness). Enforced by test_job_generation's source scan.
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
static func retaliation_job(venue: VenueData, rival: FactionData, tick: int) -> JobData:
	var job := JobTemplates.retaliation(venue.display_name, rival.display_name)
	job.id = StringName("gen@retaliation@%s@%s@%d" % [venue.id, rival.id, tick])
	job.venue_id = venue.id
	return job

## Trigger 2 — a resolved job's delayed_consequence crossed FOLLOWUP_THRESHOLD,
## FOLLOWUP_LEAD_TICKS ago (JobDirector holds the window; this just builds the job).
static func followup_job(venue: VenueData, tick: int) -> JobData:
	var job := JobTemplates.followup(venue.display_name)
	job.id = StringName("gen@followup@%s@%d" % [venue.id, tick])
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
		"followup":
			if parts.size() != 4:
				return null
			var venue := _find_venue(districts, StringName(parts[2]))
			if venue == null:
				return null
			return followup_job(venue, int(parts[3]))
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
