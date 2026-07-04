class_name EvidenceCaseData
extends Resource
## A discrete root of police attention in a district (brief §7.3, P06b). Heat is the
## flow; a case is the persistent trace it left behind — a thing the player can find
## and destroy. Weights sum into the district's case pressure (EvidenceMath), which
## pins the inspection beat even after the raw heat flow stops.

## Stable, parseable id: "case@<district>@<kind>@<tick>" (the job-id discipline).
@export var id: StringName

## BM.EvidenceKind — flavours the label; mechanics are weight-driven.
@export var kind: int = BM.EvidenceKind.MANIFEST

## How much this case pins the district, 0..1.
@export_range(0.0, 1.0) var weight: float = 0.0

## Human phrasing, in the register of JobData.known_evidence.
@export var label: String
