class_name CropState
extends RefCounted
## One planted crop (the instance). Its rules come from CropData, looked up by `crop_id`.

var crop_id: StringName
## Watered days of growth so far.
var days_grown: int = 0
var times_harvested: int = 0


func _init(id: StringName = &"") -> void:
	crop_id = id


func is_mature(crop: CropData) -> bool:
	return days_grown >= crop.growth_days


## Visual stage 0 … stage_count - 1 (the last one is mature).
func get_stage(crop: CropData) -> int:
	if is_mature(crop):
		return crop.stage_count - 1
	return mini(days_grown * (crop.stage_count - 1) / crop.growth_days, crop.stage_count - 2)


func days_left(crop: CropData) -> int:
	return maxi(0, crop.growth_days - days_grown)


func to_dict() -> Dictionary:
	return {"crop_id": String(crop_id), "days_grown": days_grown, "times_harvested": times_harvested}


static func from_dict(data: Dictionary) -> CropState:
	var state := CropState.new(StringName(str(data.get("crop_id", ""))))
	state.days_grown = maxi(0, int(data.get("days_grown", 0)))
	state.times_harvested = maxi(0, int(data.get("times_harvested", 0)))
	return state
