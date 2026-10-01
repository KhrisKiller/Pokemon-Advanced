extends Node
## Read-only content registry (autoload `ContentDB`): items, crops, kith species and shops by id.
## Content is listed in catalog resources (not found by scanning folders), which works the same
## in the editor and in exported builds. Gameplay code never loads content by path.

const ITEM_CATALOG_PATH := "res://data/items/item_catalog.tres"
const CROP_CATALOG_PATH := "res://data/crops/crop_catalog.tres"
const KITH_CATALOG_PATH := "res://data/kith/kith_catalog.tres"
const SHOP_CATALOG_PATH := "res://data/shops/shop_catalog.tres"
## Helper abilities the game implements (see KithHelpers).
const KNOWN_ABILITIES: Array[StringName] = [&"water"]

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}
var _kith: Dictionary[StringName, KithData] = {}
var _shops: Dictionary[StringName, ShopData] = {}


func _init() -> void:
	reload()


func reload() -> void:
	_items.clear()
	_crops.clear()
	_kith.clear()
	_shops.clear()
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
	var kith_catalog := load(KITH_CATALOG_PATH) as KithCatalog
	if kith_catalog != null:
		for species in kith_catalog.species:
			if species != null:
				_kith[species.id] = species
	var shop_catalog := load(SHOP_CATALOG_PATH) as ShopCatalog
	if shop_catalog != null:
		for shop in shop_catalog.shops:
			if shop != null:
				_shops[shop.id] = shop


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


func get_kith(species_id: StringName) -> KithData:
	return _kith.get(species_id)


func get_kith_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_kith.keys())
	return ids


func get_shop(shop_id: StringName) -> ShopData:
	return _shops.get(shop_id)


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
	problems.append_array(validate_kith(load(KITH_CATALOG_PATH) as KithCatalog))
	problems.append_array(validate_shops(load(SHOP_CATALOG_PATH) as ShopCatalog))
	return problems


## Kith species problems: ids, presentation, diets that match no food item, unknown abilities.
func validate_kith(catalog: KithCatalog) -> PackedStringArray:
	var problems := PackedStringArray()
	if catalog == null:
		return PackedStringArray(["kith catalog missing"])
	var seen := {}
	for species in catalog.species:
		if species == null or species.id == &"":
			problems.append("kith with an empty id")
			continue
		if seen.has(species.id):
			problems.append("duplicate kith id '%s'" % species.id)
		seen[species.id] = true
		if species.display_name == "" or species.sprite == null:
			problems.append("%s: missing name or sprite" % species.id)
		var eats_something := false
		for item: ItemData in _items.values():
			if species.will_eat(item):
				eats_something = true
		if not eats_something:
			problems.append("%s: its diet matches no food item" % species.id)
		for ability in species.helper_abilities:
			if not KNOWN_ABILITIES.has(ability):
				problems.append("%s: unknown helper ability '%s'" % [species.id, ability])
	return problems


## Shop problems: offers for unknown items, negative prices, duplicate ids.
func validate_shops(catalog: ShopCatalog) -> PackedStringArray:
	var problems := PackedStringArray()
	if catalog == null:
		return PackedStringArray(["shop catalog missing"])
	var seen := {}
	for shop in catalog.shops:
		if shop == null or shop.id == &"" or seen.has(shop.id):
			problems.append("shop with an empty or duplicate id")
			continue
		seen[shop.id] = true
		for offer in shop.offers:
			if offer == null or get_item(offer.item_id) == null:
				problems.append("%s: offer for unknown item '%s'" % [shop.id, offer.item_id if offer else &""])
			elif offer.price <= 0:
				problems.append("%s: %s has no price" % [shop.id, offer.item_id])
	return problems
