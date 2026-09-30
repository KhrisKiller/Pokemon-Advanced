class_name FarmPlot
extends Interactable
## A farm plot in the world. Presentation only: it draws its PlotState (soil, water, crop stage)
## and forwards the interact button to FarmActions. State lives in the session's FarmState, so
## crops keep growing while this map is unloaded.

enum SoilFrame { DRY, WET }

## "<map_id>:<x>,<y>" — set by the map builder. Stable id used in saves.
@export var plot_id: StringName = &""

var _farm: FarmState
var _player: PlayerState

@onready var _soil: Sprite2D = $Soil
@onready var _crop: Sprite2D = $Crop


func _init() -> void:
	super()
	add_to_group(GameSession.SESSION_AWARE_GROUP)


func bind_session(session: GameSession) -> void:
	_farm = session.farm
	_player = session.player
	_farm.ensure_plot(plot_id)
	_farm.plot_changed.connect(_on_plot_changed)
	_player.selected_seed_changed.connect(_on_selected_seed_changed)
	refresh()


func can_interact(actor: Node) -> bool:
	return super(actor) and _farm != null


func get_prompt() -> String:
	return FarmActions.prompt_for(_farm, _player, plot_id) if _farm != null else ""


func get_plot() -> PlotState:
	return _farm.ensure_plot(plot_id) if _farm != null else null


func _on_interact(_actor: Node) -> void:
	var result := FarmActions.perform(_farm, _player, plot_id)
	if result["message"] != "":
		EventBus.dialogue_requested.emit(PackedStringArray([result["message"]]))
	refresh()


func _on_selected_seed_changed(_item_id: StringName) -> void:
	prompt_changed.emit()


func _on_plot_changed(changed_id: StringName) -> void:
	if changed_id == plot_id:
		refresh()


## Redraws soil and crop from state.
func refresh() -> void:
	if _farm == null or not is_node_ready():
		return
	var plot := _farm.ensure_plot(plot_id)
	_soil.visible = plot.tilled
	_soil.frame = SoilFrame.WET if plot.watered else SoilFrame.DRY
	var crop := _farm.get_crop_data(plot)
	_crop.visible = crop != null and crop.sprite_sheet != null
	if _crop.visible:
		_crop.texture = crop.sprite_sheet
		_crop.hframes = crop.stage_count
		_crop.frame = plot.crop.get_stage(crop)
	prompt_changed.emit()
