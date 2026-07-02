class_name JobChoiceData
extends Resource
## One selectable option inside a fixer job (a preparation action, an intervention
## approach, or a cover-up story — brief §7.5). Data-only; JobResolution sums the
## effects of every chosen option into the multi-dimensional outcome.

@export var id: StringName
@export var label: String
@export var description: String = ""

## Contributions to the resolution dimensions. Keys must be JobResolution.DIMENSIONS
## StringNames; values are floats accumulated into the outcome (deterministic — no rolls).
@export var effects: Dictionary = {}

static func make(id_: StringName, label_: String, description_: String, effects_: Dictionary) -> JobChoiceData:
	var c := JobChoiceData.new()
	c.id = id_
	c.label = label_
	c.description = description_
	c.effects = effects_
	return c
