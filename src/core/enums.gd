class_name BM
extends RefCounted
## OMNI: BLACK MERIDIAN — shared enums and constants.
## Pure data; no behaviour. Referenced everywhere as `BM.ControlState.CONTROLLED` etc.

## District control states (brief §7.1). "Compromised" is distinct from "lost" —
## the player may still own a venue that has been infiltrated or tied to an evidence case.
enum ControlState {
	UNKNOWN,
	CONTESTED,
	INFLUENCED,
	CONTROLLED,
	FORTIFIED,
	COMPROMISED,
}

## Venue types (brief §7.1).
enum VenueType {
	RACKET,
	FRONT,
	SAFEHOUSE,
	TRANSIT_NODE,
	POLITICAL_OFFICE,
	INTELLIGENCE_NODE,
	NEUTRAL_INSTITUTION,
	STORY_LOCATION,
}

## Racket categories (brief §7.2).
enum RacketKind {
	CONTRABAND_LOGISTICS,
	PROTECTION,
	ILLEGAL_CLINIC,
	IDENTITY_FABRICATION,
	UNDERGROUND_GAMING,
	INFORMATION_BROKERAGE,
}

## Legitimate front kinds (brief §7.2).
enum FrontKind {
	NIGHTCLUB,
	FREIGHT_COMPANY,
	PRIVATE_SECURITY,
	LUXURY_CLINIC,
	PROPERTY_HOLDING,
	MEDIA_EVENT,
}

## Two currencies (brief §7.2).
enum Currency {
	DIRTY,  ## immediately usable, creates exposure
	CLEAN,  ## slow to produce, needed for upgrades / influence / acquisitions
}

## Rival utility-AI action set (brief §7.4).
enum RivalAction {
	EXPAND,
	PROBE,
	SABOTAGE,
	RECRUIT,
	BRIBE,
	RETALIATE,
	NEGOTIATE,
	FRAME,
	REDUCE_HEAT,
	DEFEND,
	EXPLOIT_GRIEVANCE,
}

## Fixer-job lifecycle stages (brief §7.5). The core verb: Intake → Preparation →
## Intervention → Cover-up. RESOLVED is terminal; resolution is multi-dimensional, never binary.
enum JobStage {
	INTAKE,
	PREPARATION,
	INTERVENTION,
	COVER_UP,
	RESOLVED,
}

## Where a fixer job originated (brief §7.5). EVIDENCE_CHAIN (P06b): a job aimed at
## burning down a named evidence case — appended, so saved int values stay stable.
enum JobOrigin {
	FAILED_RACKET,
	WITNESS,
	RIVAL_PROVOCATION,
	INTERNAL_DISPUTE,
	INSTITUTIONAL_PRESSURE,
	EVIDENCE_CHAIN,
}

## Evidence-case kinds (brief §7.3, P06b). Flavour only — mechanics are weight-driven;
## the kind picks the display phrasing and which cover-up reads as eroding it best.
enum EvidenceKind {
	MANIFEST,
	FOOTAGE,
	WITNESS,
	PHYSICAL,
}

## Max preparation actions per job (brief §7.5: Preparation ≤3 actions).
const JOB_MAX_PREP_ACTIONS := 3

## Night Cycle phases (brief §5.2).
enum Phase {
	COUNCIL,    ## 3-5 min: review, priorities, allocate, assign
	OPERATIONS, ## 15-20 min: run rackets / fixer jobs, react
	CRISIS,     ## 5-8 min: state-driven high-cost decision
	RECKONING,  ## 2-3 min: income/laundering resolve, pressure advances
}

## Game speed bands (real-time-with-pause, brief §5.1).
enum Speed {
	PAUSED,
	NORMAL,
	FAST,
	FASTER,
}

## Maps a Speed enum to its strategic-time multiplier.
const SPEED_SCALE := {
	Speed.PAUSED: 0.0,
	Speed.NORMAL: 1.0,
	Speed.FAST: 2.0,
	Speed.FASTER: 4.0,
}

## Strategic tick length in real seconds at NORMAL speed (brief §13.2).
const STRATEGIC_TICK_SECONDS := 1.0

## Rival decision cadence in strategic ticks (~10s, brief §13.2).
const RIVAL_TICK_INTERVAL := 10
