class_name EvidenceMath
extends RefCounted
## Pure evidence-case math (brief §7.3, P06b) — the EconomyMath discipline: statics on a
## RefCounted, no autoload references, headless unit-testable. Cases give heat ROOTS:
## discrete, persistent weights the player can find and destroy, instead of one timer.
## Fully deterministic — accrual/erosion move by signed evidence flow only, kind
## selection is a hash (never RNG), and the combined-pressure latch is a pure threshold.

## Bounded case count keeps the puzzle legible: past the cap, new trace feeds the
## oldest open case instead of spawning a fifth.
const MAX_CASES := 4

## How hard case pressure leans on the inspection latch. At 0.5, a saturated case list
## (pressure 1.0) contributes 0.5 — alone past the 0.45 inspection threshold, so a couple
## of strong cases keep the sweep coming even as the raw heat flow decays. That is the
## point: heat is the flow, cases are what it left behind.
const CASE_PRESSURE_WEIGHT := 0.5

## Display phrasing per BM.EvidenceKind, in the register of JobData.known_evidence.
const KIND_LABELS := {
	BM.EvidenceKind.MANIFEST: "An unfiled manifest that names the operation",
	BM.EvidenceKind.FOOTAGE: "Camera footage nobody thought to wipe",
	BM.EvidenceKind.WITNESS: "A witness statement, signed and dated",
	BM.EvidenceKind.PHYSICAL: "Physical trace left at the scene",
}

## Sum of a district's case weights, clamped 0..1 — the case side of the latch.
static func case_pressure(cases: Array[EvidenceCaseData]) -> float:
	var total := 0.0
	for c in cases:
		total += c.weight
	return clampf(total, 0.0, 1.0)

## What the inspection latch reads (P06b): raw heat plus the weighted case pressure.
static func combined_pressure(local_heat: float, cases: Array[EvidenceCaseData]) -> float:
	return local_heat + CASE_PRESSURE_WEIGHT * case_pressure(cases)

## Deterministic kind from the source job id — a hash, not a roll (the P07c discipline).
static func kind_for(source_id: StringName) -> int:
	return posmod(hash(String(source_id)), BM.EvidenceKind.size())

## Positive evidence flow lands here (JobLifecycle.apply_outcome): spawn a case while
## under the cap, else grow the OLDEST open case. Same source id + tick touches the same
## case (ids collide by construction). Returns the case touched.
static func deposit(district: DistrictData, amount: float, source_id: StringName,
		tick: int) -> EvidenceCaseData:
	if amount <= 0.0:
		return null
	var kind := kind_for(source_id)
	var cid := StringName("case@%s@%d@%d" % [district.id, kind, tick])
	var existing := find_case(district, cid)
	if existing != null:
		existing.weight = clampf(existing.weight + amount, 0.0, 1.0)
		return existing
	if district.evidence_cases.size() >= MAX_CASES:
		var oldest: EvidenceCaseData = district.evidence_cases[0]
		oldest.weight = clampf(oldest.weight + amount, 0.0, 1.0)
		return oldest
	var c := EvidenceCaseData.new()
	c.id = cid
	c.kind = kind
	c.weight = clampf(amount, 0.0, 1.0)
	c.label = KIND_LABELS[kind]
	district.evidence_cases.append(c)
	return c

## Negative evidence flow lands here (path A, passive): a cover-up's suppression erodes
## the STRONGEST case; a case ground to zero is removed.
static func erode_strongest(district: DistrictData, amount: float) -> void:
	if amount <= 0.0:
		return
	var strongest := strongest_case(district)
	if strongest == null:
		return
	strongest.weight -= amount
	if strongest.weight <= 0.0:
		district.evidence_cases.erase(strongest)

## Path B, the aimed strike: a resolved "Bury the Case" job removes its TARGETED case.
static func remove_case(district: DistrictData, case_id: StringName) -> bool:
	var c := find_case(district, case_id)
	if c == null:
		return false
	district.evidence_cases.erase(c)
	return true

## Highest weight wins; ties break to the earliest (deterministic, like RivalScoring).
static func strongest_case(district: DistrictData) -> EvidenceCaseData:
	var best: EvidenceCaseData = null
	for c in district.evidence_cases:
		if best == null or c.weight > best.weight:
			best = c
	return best

static func find_case(district: DistrictData, case_id: StringName) -> EvidenceCaseData:
	for c in district.evidence_cases:
		if c.id == case_id:
			return c
	return null
