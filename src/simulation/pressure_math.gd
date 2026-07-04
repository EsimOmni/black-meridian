class_name PressureMath
extends RefCounted
## Pure central-pressure math (brief §7.3, P06c) — the EconomyMath discipline: statics on
## a RefCounted, no autoload references, headless unit-testable. The one scale above the
## districts: heat stops being local and climbs to the Compact. Fully deterministic —
## a pure derivative of district state, a fixed-rate integrator, a threshold latch.
## Sits ON TOP of P06b (reuses EvidenceMath.combined_pressure per district), not beside it.

## City signal must sit at/above this before central pressure rises at all.
const CENTRAL_RISE_FLOOR := 0.35
## Fraction of the (city - current) gap closed per tick while rising — tracking toward
## the map instead of adding raw exposure keeps the ceiling bounded and legible.
const CENTRAL_RISE_SCALE := 0.15
## Slower than district decay (0.0006) — institutional attention has a long memory.
const CENTRAL_DECAY_PER_TICK := 0.01
const CENTRAL_ALERT_THRESHOLD := 0.6   ## crossing fires the city-wide alert (once per excursion)
const CENTRAL_ALERT_REARM := 0.4       ## pressure must fall below this before another can fire
const CENTRAL_ALERT_DURATION_TICKS := 20
## The bite: while an alert is active, every district's inspection latch is tested
## against HEAT_INSPECTION_THRESHOLD minus this — the whole map tightens at once.
const CENTRAL_ALERT_INSPECTION_RELIEF := 0.15

## The consolidated raw signal: the MEAN of each district's combined pressure (heat +
## weighted case pressure), never a raw sum — "the city is broadly hot" reads higher
## than "one district is on fire". One hot district is a district problem; three
## simmering districts are a Compact problem.
static func city_pressure(districts: Array[DistrictData]) -> float:
	if districts.is_empty():
		return 0.0
	var total := 0.0
	for d in districts:
		total += EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases)
	return total / districts.size()

## The rise/decay integrator, mirroring the district heat rule: above the floor the
## pressure tracks toward the city signal; below it, fixed-rate decay. Clamped 0..1.
static func step_central(current: float, city: float) -> float:
	if city >= CENTRAL_RISE_FLOOR:
		return clampf(current + (city - current) * CENTRAL_RISE_SCALE, 0.0, 1.0)
	return clampf(current - CENTRAL_DECAY_PER_TICK, 0.0, 1.0)
