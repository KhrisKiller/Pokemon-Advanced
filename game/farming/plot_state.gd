class_name PlotState
extends RefCounted
## One farm plot: soil state plus an optional crop.

var plot_id: StringName
## Prepared (tilled) soil. Only tilled plots can be planted and watered.
var tilled: bool = false
## Watered today. Reset every morning by FarmState.advance_day().
var watered: bool = false
var crop: CropState = null


func _init(id: StringName = &"") -> void:
	plot_id = id


func has_crop() -> bool:
	return crop != null


func to_dict() -> Dictionary:
	return {"tilled": tilled, "watered": watered, "crop": crop.to_dict() if crop != null else null}


static func from_dict(id: StringName, data: Dictionary) -> PlotState:
	var plot := PlotState.new(id)
	plot.tilled = bool(data.get("tilled", false))
	plot.watered = bool(data.get("watered", false))
	var crop_data: Variant = data.get("crop")
	if typeof(crop_data) == TYPE_DICTIONARY and str(crop_data.get("crop_id", "")) != "":
		plot.crop = CropState.from_dict(crop_data)
		plot.tilled = true
	return plot
