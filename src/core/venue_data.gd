class_name VenueData
extends Resource
## A strategic venue inside a district (brief §7.1). The authoritative simulation runs on
## venue + district data; the city scene only spawns visuals from it.

@export var id: StringName
@export var display_name: String
@export var type: BM.VenueType = BM.VenueType.RACKET

## Which faction currently holds this venue (StringName id, &"" = none).
@export var owner_faction: StringName = &""
@export var control_state: BM.ControlState = BM.ControlState.UNKNOWN

## For RACKET venues: which racket runs here and its base yield (brief §7.2).
@export var racket_kind: BM.RacketKind = BM.RacketKind.PROTECTION
@export var base_yield: int = 0

## For FRONT venues: laundering capacity + efficiency (brief §7.2).
@export var front_kind: BM.FrontKind = BM.FrontKind.NIGHTCLUB
@export var laundering_capacity: int = 0
@export_range(0.0, 1.0) var front_efficiency: float = 0.7
@export_range(0.0, 1.0) var operating_cost: float = 0.15

## How many operatives are staffed here (scales dirty income).
@export var operational_staff: int = 0

## Player verb (brief §7.2 "temporarily stop a profitable racket"): a paused racket
## yields 0 dirty income — the direct lever on laundering overflow. RACKET venues only.
@export var paused: bool = false

## Disruption 0..1 — heat/raids/rival sabotage reduce yield (brief §7.2 DisruptionModifier).
## Written each tick by EconomyService (heat base + inspection floor + sabotage component).
@export_range(0.0, 1.0) var disruption: float = 0.0

## P07 rival-hit component: composed on top of the heat-driven disruption by the
## economy's single-writer pass, decaying over sabotage_ticks. Additive save fields.
@export var sabotage_disruption: float = 0.0
@export var sabotage_ticks: int = 0

## Per-venue risk feeding ExposureGain (brief §7.2). Higher = more exposure per unlaundered cash.
@export_range(0.0, 1.0) var racket_risk: float = 0.3

## Position in the greybox city (set per-district later; presentation only).
@export var map_position: Vector2 = Vector2.ZERO
