class_name CharacterData
extends Resource
## A hero-grade character (brief §4). Loyalty is a network of motives, not one number
## (brief §7.6). Names other than Aiko are role placeholders until the world bible locks.

@export var id: StringName
@export var display_name: String
@export var faction_id: StringName        ## which dynasty they belong to
@export var role: String = ""             ## "Resolver", "Regent", "Operations lieutenant", "Rival boss"...
@export var is_player: bool = false       ## true only for Aiko

## --- Public motive network (visible to the player, brief §7.6) ---
@export_range(0.0, 1.0) var public_trust: float = 0.5
@export_range(0.0, 1.0) var ambition: float = 0.3
@export_range(0.0, 1.0) var fear: float = 0.2
@export_range(0.0, 1.0) var grievance: float = 0.0
@export_range(0.0, 1.0) var shared_success: float = 0.0

## --- Hidden motive network (player must infer, brief §7.6) ---
@export_range(0.0, 1.0) var rival_leverage: float = 0.0
@export_range(0.0, 1.0) var survival_pressure: float = 0.0
## Per-character betrayal threshold — pressure must exceed this AND an opportunity must exist.
@export_range(0.0, 1.0) var betrayal_threshold: float = 0.7

## Relationship edges to other characters: target id -> affinity (-1..1).
@export var relationships: Dictionary = {}

## Open betrayal intent (P10, like FactionData's rival intent): rival ticks until the
## betrayal lands; -1 = none. While ≥ 0 the tells are visible and the player can defuse.
@export var betrayal_ticks_until_land: int = -1

## P10b hidden motives: the single largest contributor to betrayal_pressure(), captured
## at telegraph time (the motive that drove THIS intent); &"" = none. Starts hidden —
## the reassure verb reveals it (a deterministic player-driven transition, never a roll).
@export var betrayal_driving_motive: StringName = &""
@export var motive_revealed: bool = false

## BetrayalPressure (brief §7.6). Betrayal also requires a viable opportunity, evaluated elsewhere.
## Telegraphed + deterministic — never an untelegraphed random roll.
func betrayal_pressure() -> float:
	var p := ambition + grievance + rival_leverage + survival_pressure \
		- public_trust - shared_success - fear  # fear here = fear of consequences
	return clampf(p, 0.0, 4.0)

func pressure_exceeds_threshold() -> bool:
	# Normalize the (roughly 0..4) pressure against a 0..1 threshold scaled to the same band.
	return betrayal_pressure() >= (betrayal_threshold * 2.0)
