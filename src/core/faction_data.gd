class_name FactionData
extends Resource
## A dynasty / faction. The player runs the Meridian Compact; rivals are AI-driven
## (brief §4, §7.4). Data-only Resource — behaviour lives in RivalDirector.

@export var id: StringName
@export var display_name: String
@export var is_player: bool = false

## Accent color used to mark controlled districts / signage in the city proxy (brief §9.1).
@export var accent_color: Color = Color(0.79, 0.57, 0.25)

## Leader personality knobs feeding the rival utility AI (brief §7.4).
## 0..1 each. Aggression raises sabotage/retaliate; caution raises defend/reduce_heat.
@export_range(0.0, 1.0) var aggression: float = 0.5
@export_range(0.0, 1.0) var caution: float = 0.5
@export_range(0.0, 1.0) var cunning: float = 0.5  ## bias toward frame/bribe/negotiate over direct force

## Resources the faction can spend on actions.
@export var dirty_cash: int = 0
@export var clean_capital: int = 0

## P07 rival intent — the telegraph→land window survives ticks and saves (additive
## save fields). intent_action is a BM.RivalAction, or -1 when the rival has no plan.
## Since P07b intent_venue_id is a generic target id: a venue id, or a character id
## when intent_action == RECRUIT (field name kept for save-schema stability).
@export var intent_action: int = -1
@export var intent_venue_id: StringName = &""
@export var intent_ticks_until_land: int = 0  ## in rival-ticks (~10 strategic each)

## P07b: how many intents this faction has ever committed. The tie-break jitter salt
## (persisted, so save→load→replay reproduces the same picks) + telemetry.
@export var intents_committed: int = 0

## P07c rival memory — grudge toward the player, 0..1. Rises when the player resolves the
## retaliation this rival provoked (the feud closes); decays each rival tick (a grudge cools
## if left alone). Biases RivalScoring toward the player. Deterministic, save-additive.
@export_range(0.0, 1.0) var grudge: float = 0.0
