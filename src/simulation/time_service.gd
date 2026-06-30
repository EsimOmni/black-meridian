extends Node
## TimeService (autoload) — drives the strategic tick (brief §13.2).
## Real-time-with-pause: accumulates real delta * speed_scale, fires a 1-second
## strategic tick that the rest of the simulation listens to. Decisions are discrete
## and readable; this is NOT turn-based but the tick gives deterministic settlement points.

signal strategic_tick(tick_index: int)
signal rival_tick(tick_index: int)   ## fires every BM.RIVAL_TICK_INTERVAL strategic ticks
signal speed_changed(speed: int)

var speed: int = BM.Speed.PAUSED
var tick_index: int = 0

var _accumulator: float = 0.0

func _process(delta: float) -> void:
	var scale: float = BM.SPEED_SCALE.get(speed, 0.0)
	if scale <= 0.0:
		return
	_accumulator += delta * scale
	while _accumulator >= BM.STRATEGIC_TICK_SECONDS:
		_accumulator -= BM.STRATEGIC_TICK_SECONDS
		_do_tick()

func _do_tick() -> void:
	tick_index += 1
	strategic_tick.emit(tick_index)
	if tick_index % BM.RIVAL_TICK_INTERVAL == 0:
		rival_tick.emit(tick_index)

# --- Speed control (brief §5.1: pause + three speeds) ------------------------

func set_speed(new_speed: int) -> void:
	if new_speed == speed:
		return
	speed = new_speed
	speed_changed.emit(speed)

func toggle_pause() -> void:
	set_speed(BM.Speed.PAUSED if speed != BM.Speed.PAUSED else BM.Speed.NORMAL)

func cycle_speed() -> void:
	## NORMAL -> FAST -> FASTER -> NORMAL (pause is a separate toggle).
	match speed:
		BM.Speed.PAUSED, BM.Speed.FASTER:
			set_speed(BM.Speed.NORMAL)
		BM.Speed.NORMAL:
			set_speed(BM.Speed.FAST)
		BM.Speed.FAST:
			set_speed(BM.Speed.FASTER)

func is_paused() -> bool:
	return speed == BM.Speed.PAUSED
