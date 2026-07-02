extends CanvasLayer
## Minimal fixer-job panel for the Month-1 skeleton (P03). Greybox-grade, built in code
## like the HUD; the real UI theme lands in Month 5 (P11/P19). Renders the active job by
## lifecycle stage and forwards choices to JobDirector. Reads state; never owns it.

var _panel: PanelContainer
var _vb: VBoxContainer
var _job: JobData

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -396
	_panel.offset_right = -16
	_panel.offset_top = 16
	add_child(_panel)
	_panel.visible = false

	_vb = VBoxContainer.new()
	_vb.custom_minimum_size = Vector2(360, 0)
	_panel.add_child(_vb)

	JobDirector.job_offered.connect(_on_job_event)
	JobDirector.job_stage_changed.connect(_on_job_event)
	JobDirector.job_resolved.connect(_on_job_event)

func _on_job_event(job: JobData) -> void:
	_job = job
	_panel.visible = true
	_render()

func _render() -> void:
	for child in _vb.get_children():
		child.queue_free()
	if _job == null:
		return

	_title("FIXER JOB — %s" % _job.title)
	match _job.stage:
		BM.JobStage.INTAKE:
			_render_intake()
		BM.JobStage.PREPARATION:
			_render_preparation()
		BM.JobStage.INTERVENTION:
			_render_intervention()
		BM.JobStage.RESOLVED:
			_render_resolved()

func _render_intake() -> void:
	_text("FIRST DECISION — the city is paused. Read the situation, take the job, commit to a path. (SPACE resumes time.)")
	_text(_job.apparent_problem)
	_text("Known evidence:\n  • " + "\n  • ".join(_job.known_evidence))
	_text("Stakes: %s" % _job.visible_stakes)
	_text("Deadline: %d ticks" % _job.ticks_remaining)
	_button("Take the job", func(): JobDirector.begin(_job.id))

func _render_preparation() -> void:
	_text("PREPARATION — pick up to %d actions, then commit to an approach." % BM.JOB_MAX_PREP_ACTIONS)
	for choice in _job.prep_actions:
		var selected := _job.chosen_prep.has(choice.id)
		_button(("[x] " if selected else "[ ] ") + choice.label,
			func(): JobDirector.choose_prep(_job.id, choice.id), choice.description)
	_text("INTERVENTION — one approach. This commits you.")
	for choice in _job.approaches:
		_button("→ " + choice.label,
			func(): JobDirector.choose_approach(_job.id, choice.id), choice.description)

func _render_intervention() -> void:
	var appr := _job.find_choice(_job.approaches, _job.chosen_approach)
	_text("Intervention underway: %s" % (appr.label if appr else "?"))
	_text("COVER-UP — choose the story the city hears.")
	for choice in _job.coverups:
		_button("→ " + choice.label,
			func(): JobDirector.choose_coverup(_job.id, choice.id), choice.description)

func _render_resolved() -> void:
	if _job.chosen_coverup == &"":
		_text("The deadline passed. The problem resolved itself — badly.")
	_text("RESOLVED — consequences:")
	for dim in JobResolution.DIMENSIONS:
		var v: float = _job.outcome.get(dim, 0.0)
		if absf(v) > 0.001:
			_text("  %s: %+.2f" % [String(dim).replace("_", " "), v])
	_button("Dismiss", func():
		_panel.visible = false
		_job = null)

# --- Widget helpers -----------------------------------------------------------

func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	_vb.add_child(l)

func _text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	_vb.add_child(l)

func _button(label: String, on_pressed: Callable, tooltip: String = "") -> void:
	var b := Button.new()
	b.text = label
	b.tooltip_text = tooltip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_pressed)
	_vb.add_child(b)
