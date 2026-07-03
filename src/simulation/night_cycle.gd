class_name NightCycle
extends Node
## Night Cycle phase machine (brief §5.2, P09) — turns the flat tick stream into a
## bounded dramatic episode: COUNCIL → OPERATIONS → CRISIS → RECKONING → next cycle.
## Wired at bootstrap (NOT an autoload) so unit-test scenes of other systems never
## have phases advancing underneath them. PURELY DETERMINISTIC: a phase advances when
## its elapsed ticks reach its fixed budget — same tick count → same phase, no random
## number generation anywhere (house style, enforced by test_night_cycle's source scan).
##
## The one architectural rule (P09, decided 2026-07-03): per-tick settlement is
## UNTOUCHED. Economy/heat/rival/jobs keep running every tick exactly as calibrated in
## P05–P08; phases only MODULATE them via minimal guards keyed on GameState.phase
## (Council gates new rival telegraphs — see RivalDirector) and FRAME them (the
## Reckoning summary reads already-settled state; it relocates no math).

## Tick budgets per phase (1 strategic tick = 1s at NORMAL speed): the mid-range of
## brief §5.2's phase minutes — 4 + 18 + 6 + 2 = 30 min/cycle, inside the 25–35 window.
const PHASE_BUDGET_TICKS := {
	BM.Phase.COUNCIL: 240,
	BM.Phase.OPERATIONS: 1080,
	BM.Phase.CRISIS: 360,
	BM.Phase.RECKONING: 120,
}
const PHASE_ORDER: Array[int] = [
	BM.Phase.COUNCIL, BM.Phase.OPERATIONS, BM.Phase.CRISIS, BM.Phase.RECKONING,
]

## Cycle-summary accumulators for the Reckoning framing beat (presentation-read only —
## not authoritative sim state, not saved; a mid-cycle load restarts the tally).
var _cycle_dirty_earned: int = 0
var _cycle_clean_earned: int = 0
var _cycle_start_heat: float = 0.0

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)
	EconomyService.economy_settled.connect(_on_economy_settled)
	# A fresh campaign starts its first cycle at COUNCIL (brief §5.2 — the setup beat;
	# GameState's default is OPERATIONS, so set it explicitly). A loaded save overwrites
	# phase/night_cycle/phase_ticks afterwards and the machine continues from there.
	start_cycle()

## Begin the current night_cycle at COUNCIL and reset the summary tally.
func start_cycle() -> void:
	GameState.phase = BM.Phase.COUNCIL
	GameState.phase_ticks = 0
	_reset_summary()
	GameState.night_cycle_advanced.emit(GameState.night_cycle, GameState.phase)

func _on_strategic_tick(_tick: int) -> void:
	GameState.phase_ticks += 1
	if GameState.phase_ticks >= phase_budget(GameState.phase):
		_advance()

func _advance() -> void:
	var next_idx := (PHASE_ORDER.find(GameState.phase) + 1) % PHASE_ORDER.size()
	if next_idx == 0:  # RECKONING closed — the episode ends, a new cycle convenes
		GameState.night_cycle += 1
		_reset_summary()
	GameState.phase = PHASE_ORDER[next_idx]
	GameState.phase_ticks = 0
	GameState.night_cycle_advanced.emit(GameState.night_cycle, GameState.phase)

func _on_economy_settled(faction_id: StringName, dirty_delta: int, clean_delta: int,
		_exposure_delta: float) -> void:
	if faction_id != GameState.player_faction_id:
		return
	_cycle_dirty_earned += dirty_delta
	_cycle_clean_earned += clean_delta

func _reset_summary() -> void:
	_cycle_dirty_earned = 0
	_cycle_clean_earned = 0
	var d := GameState.get_district(&"glass_wharf")
	_cycle_start_heat = d.local_heat if d else 0.0

## What this cycle has settled so far — the Reckoning beat's framing data (HUD reads it).
func summary() -> Dictionary:
	var d := GameState.get_district(&"glass_wharf")
	return {
		"dirty_earned": _cycle_dirty_earned,
		"clean_earned": _cycle_clean_earned,
		"heat_delta": (d.local_heat - _cycle_start_heat) if d else 0.0,
	}

static func phase_budget(phase: int) -> int:
	return PHASE_BUDGET_TICKS.get(phase, 1080)

static func phase_name(phase: int) -> String:
	match phase:
		BM.Phase.COUNCIL: return "COUNCIL"
		BM.Phase.OPERATIONS: return "OPERATIONS"
		BM.Phase.CRISIS: return "CRISIS"
		BM.Phase.RECKONING: return "RECKONING"
		_: return "?"
