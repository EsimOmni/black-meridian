class_name JobData
extends Resource
## A fixer job (brief §7.5) — the core verb of the game. Authored fields describe the
## *apparent* situation; some information is intentionally missing (hidden_stakes).
## Lifecycle state lives here too so save/load can serialize an in-flight job later.

@export var id: StringName
@export var title: String
@export var origin: BM.JobOrigin = BM.JobOrigin.FAILED_RACKET
@export var apparent_problem: String = ""
@export var involved_character_ids: Array[StringName] = []
@export var venue_id: StringName = &""
@export var deadline_ticks: int = 120
@export var known_evidence: Array[String] = []
@export var visible_stakes: String = ""
## Intentionally NOT shown to the player at intake (brief §7.5: some info missing).
@export var hidden_stakes: String = ""
## Dirty-cash reward granted when the resolved objective_achieved dimension is >= 0.5.
@export var reward_dirty: int = 0

@export var prep_actions: Array[JobChoiceData] = []
@export var approaches: Array[JobChoiceData] = []
@export var coverups: Array[JobChoiceData] = []

## --- Lifecycle state (mutated by JobLifecycle) ---
var stage: int = BM.JobStage.INTAKE
var chosen_prep: Array[StringName] = []
var chosen_approach: StringName = &""
var chosen_coverup: StringName = &""
var ticks_remaining: int = 0
## Resolution dimensions (JobResolution.DIMENSIONS -> float) once RESOLVED.
var outcome: Dictionary = {}

func find_choice(pool: Array[JobChoiceData], choice_id: StringName) -> JobChoiceData:
	for c in pool:
		if c.id == choice_id:
			return c
	return null
