class_name DistrictData
extends Resource
## A city district (brief §7.1). Not simply owned/unowned — it tracks seven dimensions
## and contains venues. The vertical slice ships one district: Glass Wharf (brief §12.1).

@export var id: StringName
@export var display_name: String

## The seven tracked dimensions (brief §7.1), 0..1 normalized.
@export_range(0.0, 1.0) var influence: float = 0.0        ## social / political control
@export_range(0.0, 1.0) var security: float = 0.0         ## ability to defend operations
@export_range(0.0, 1.0) var prosperity: float = 0.5       ## economic potential -> DistrictDemand
@export_range(0.0, 1.0) var fear: float = 0.0             ## willingness of locals to cooperate
@export_range(0.0, 1.0) var visibility: float = 0.5       ## how exposed criminal activity is
@export_range(0.0, 1.0) var institutional_presence: float = 0.3  ## police / inspectors / civic

## Local heat (brief §7.3) — per-district police attention, 0..1.
@export_range(0.0, 1.0) var local_heat: float = 0.0

## P06 inspection beat state (deterministic + telegraphed, brief §7.6 — no rolls).
## inspection_ticks > 0 = an inspection is active (counts down each strategic tick);
## inspection_armed re-arms only after heat falls below the re-arm level, so the
## threshold fires once per excursion, not every tick above it.
@export var inspection_ticks: int = 0
@export var inspection_armed: bool = true

## P06b evidence cases — the discrete, persistent roots of police attention here.
## Their summed weight (EvidenceMath.case_pressure) pins the inspection latch alongside
## raw heat; jobs deposit/erode them through JobLifecycle.apply_outcome.
@export var evidence_cases: Array[EvidenceCaseData] = []

## Faction pressure: influence each dynasty exerts here. Keyed by faction id -> 0..1.
@export var faction_pressure: Dictionary = {}

## Venues in this district (Array[VenueData]).
@export var venues: Array[VenueData] = []

## Economic demand multiplier derived from prosperity (brief §7.2 DistrictDemand).
func district_demand() -> float:
	return 0.5 + prosperity  # 0.5..1.5
