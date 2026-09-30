class_name FarmState
extends RefCounted
## All farm plots and the farming rules. Pure: no nodes, no clock of its own. Time moves only
## through advance_day(), which the day transition calls (the existing daily tick).
## Crop rules are read from CropData through `content` (anything with get_crop(id)).
## Save section "farm".

signal plot_changed(plot_id: StringName)

const SAVE_VERSION := 1

var content: Object
var _plots: Dictionary[StringName, PlotState] = {}


func _init(content_source: Object = null) -> void:
	content = content_source


func reset() -> void:
	var ids := _plots.keys()
	_plots.clear()
	for id: StringName in ids:
		plot_changed.emit(id)


## Plots are created the first time a map with that plot is shown.
func ensure_plot(plot_id: StringName) -> PlotState:
	if not _plots.has(plot_id):
		_plots[plot_id] = PlotState.new(plot_id)
	return _plots[plot_id]


func get_plot(plot_id: StringName) -> PlotState:
	return _plots.get(plot_id)


func get_plot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_plots.keys())
	return ids


func get_crop_data(plot: PlotState) -> CropData:
	if plot == null or plot.crop == null or content == null:
		return null
	return content.get_crop(plot.crop.crop_id)


# --- actions ---------------------------------------------------------------------------------

func till(plot_id: StringName) -> bool:
	var plot := ensure_plot(plot_id)
	if plot.tilled:
		return false
	plot.tilled = true
	plot_changed.emit(plot_id)
	return true


func can_plant(plot_id: StringName) -> bool:
	var plot := get_plot(plot_id)
	return plot != null and plot.tilled and not plot.has_crop()


func plant(plot_id: StringName, crop: CropData) -> bool:
	if crop == null or not can_plant(plot_id):
		return false
	get_plot(plot_id).crop = CropState.new(crop.id)
	plot_changed.emit(plot_id)
	return true


func water(plot_id: StringName) -> bool:
	var plot := get_plot(plot_id)
	if plot == null or not plot.tilled or plot.watered:
		return false
	plot.watered = true
	plot_changed.emit(plot_id)
	return true


func is_mature(plot_id: StringName) -> bool:
	var plot := get_plot(plot_id)
	var crop := get_crop_data(plot)
	return crop != null and plot.crop.is_mature(crop)


## Harvests a mature crop. Returns {"item_id", "quantity"} or {} if nothing to harvest.
## Single-harvest crops leave tilled soil; regrowing crops go back regrow_days before maturity.
func harvest(plot_id: StringName) -> Dictionary:
	if not is_mature(plot_id):
		return {}
	var plot := get_plot(plot_id)
	var crop := get_crop_data(plot)
	var produce := {"item_id": crop.harvest_item_id, "quantity": crop.harvest_quantity}
	if crop.regrows():
		plot.crop.days_grown = crop.growth_days - crop.regrow_days
		plot.crop.times_harvested += 1
	else:
		plot.crop = null
	plot_changed.emit(plot_id)
	return produce


# --- daily tick ------------------------------------------------------------------------------

## End of day: watered, growing crops gain a day; then all soil dries. Returns a summary
## {"grown": int, "matured": int} for messages and tests.
func advance_day() -> Dictionary:
	var grown := 0
	var matured := 0
	for plot: PlotState in _plots.values():
		var crop := get_crop_data(plot)
		if crop != null and plot.watered and not plot.crop.is_mature(crop):
			plot.crop.days_grown += 1
			grown += 1
			if plot.crop.is_mature(crop):
				matured += 1
		if plot.watered or crop != null:
			plot.watered = false
			plot_changed.emit(plot.plot_id)
	return {"grown": grown, "matured": matured}


# --- persistence (Saveable contract) ---------------------------------------------------------

func get_save_id() -> StringName:
	return &"farm"


func to_save_data() -> Dictionary:
	var plots := {}
	for id: StringName in _plots:
		plots[String(id)] = _plots[id].to_dict()
	return {"version": SAVE_VERSION, "plots": plots}


func load_save_data(data: Dictionary) -> void:
	reset()
	var plots: Variant = data.get("plots", {})
	if typeof(plots) != TYPE_DICTIONARY:
		return
	for key: String in plots:
		if typeof(plots[key]) != TYPE_DICTIONARY:
			continue
		var plot := PlotState.from_dict(StringName(key), plots[key])
		if plot.crop != null and content != null and content.get_crop(plot.crop.crop_id) == null:
			push_warning("Farm plot %s had unknown crop '%s'; removed." % [key, plot.crop.crop_id])
			plot.crop = null
		_plots[plot.plot_id] = plot
		plot_changed.emit(plot.plot_id)
