extends Node
## Read-only content registry (autoload `ContentDB`): looks up item and crop definitions by id.
## Content is listed in catalog resources (not found by scanning folders), which works the same
## in the editor and in exported builds. Gameplay code never loads content by path.

const ITEM_CATALOG_PATH := "res://data/items/item_catalog.tres"
const CROP_CATALOG_PATH := "res://data/crops/crop_catalog.tres"

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}


func _init() -> void:
	reload()


func reload() -> void:
	_items.clear()
	_crops.clear()
	var item_catalog := load(ITEM_CATALOG_PATH) as ItemCatalog
	if item_catalog != null:
		for item in item_catalog.items:
			if item != null:
				_items[item.id] = item
	var crop_catalog := load(CROP_CATALOG_PATH) as CropCatalog
	if crop_catalog != null:
		for crop in crop_catalog.crops:
			if crop != null:
				_crops[crop.id] = crop


func get_item(item_id: StringName) -> ItemData:
	return _items.get(item_id)


func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)


func get_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_items.keys())
	return ids


func get_crop(crop_id: StringName) -> CropData:
	return _crops.get(crop_id)


func get_crop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_crops.keys())
	return ids


## The crop grown from a seed item, or null.
func get_crop_for_seed(seed_item_id: StringName) -> CropData:
	for crop: CropData in _crops.values():
		if crop.seed_item_id == seed_item_id:
			return crop
	return null


## Consistency problems in the content (empty = all good). Checked by tests.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var item_catalog := load(ITEM_CATALOG_PATH) as ItemCatalog
	var crop_catalog := load(CROP_CATALOG_PATH) as CropCatalog
	if item_catalog == null or crop_catalog == null:
		problems.append("catalog missing")
		return problems
	if item_catalog.items.size() != _items.size():
		problems.append("duplicate or empty item ids")
	if crop_catalog.crops.size() != _crops.size():
		problems.append("duplicate or empty crop ids")
	for crop: CropData in _crops.values():
		var seed := get_item(crop.seed_item_id)
		if seed == null or not seed.has_tag(&"seed"):
			problems.append("%s: seed item '%s' missing or not tagged seed" % [crop.id, crop.seed_item_id])
		var produce := get_item(crop.harvest_item_id)
		if produce == null or not produce.has_tag(&"crop"):
			problems.append("%s: harvest item '%s' missing or not tagged crop" % [crop.id, crop.harvest_item_id])
		if crop.sprite_sheet == null:
			problems.append("%s: no sprite sheet" % crop.id)
	for item: ItemData in _items.values():
		if item.display_name == "":
			problems.append("%s: no display name" % item.id)
	return problems
