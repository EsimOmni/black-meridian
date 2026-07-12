class_name NarrativeDirector
extends Node
## NarrativeDirector (P16, brief §13.2) — fires the authored beat chain on top of the
## systemic engine. Bootstrap-wired node, NOT an autoload (the P09 lesson: a driver that
## mutates shared state must not run under other systems' test scenes). Stateless: all
## beat progress lives in GameState.narrative_flags (save-additive via SaveService meta);
## after a load this node just reads the restored flags. Pure logic: NarrativeBeats.

signal beat_fired(beat: StringName, job: JobData)

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)
	JobDirector.job_resolved.connect(_on_job_resolved)

func _on_strategic_tick(tick: int) -> void:
	var beat := NarrativeBeats.ready_beat(GameState.narrative_flags, tick)
	if beat == &"":
		return
	# Never let an authored beat die to the cadence cap: hold until a slot frees —
	# the gate stays true, so the beat fires on the first tick with room.
	if JobDirector.unresolved_count() >= JobDirector.MAX_CONCURRENT_JOBS:
		return
	var job := NarrativeBeats.job_for_beat(beat)
	if job == null:
		return
	NarrativeBeats.apply_fire(beat, GameState.characters)
	GameState.narrative_flags[StringName("fired@" + String(beat))] = true
	JobDirector.offer(job)
	beat_fired.emit(beat, job)

## The chain's clock + the authored consequences. Recording the resolution tick and
## applying the consequence happen in the same call stack as the resolution itself,
## so a save can never split them.
func _on_job_resolved(job: JobData) -> void:
	if job.id in NarrativeBeats.TRACKED_JOB_IDS:
		GameState.narrative_flags[StringName("resolved@" + String(job.id))] = \
			TimeService.tick_index
	NarrativeBeats.apply_resolution(job, GameState.characters, GameState.narrative_flags)
