class_name PlayerState
extends RefCounted
## The player's persistent belongings: inventory, money and the selected seed. Pure data + rules
## (no nodes). Owned by Main, shared with the Player node and HUD; save section "player_state".

signal money_changed(money: int)
signal selected_seed_changed(item_id: StringName)

## 1: Phase 3. 2: Phase 4 (Bond Charms granted to older saves via NewGameConfig.upgrade_grants).
const SAVE_VERSION := 2

var inventory: Inventory
var money: int = 0
var selected_seed: StringName = &""
var content: Object
var new_game: NewGameConfig


func _init(config: NewGameConfig = null, content_source: Object = null) -> void:
	new_game = config if config != null else NewGameConfig.new()
	content = content_source
	inventory = Inventory.new(new_game.inventory_slots, content)
	inventory.changed.connect(_on_inventory_changed)
	reset_to_new_game()


func reset_to_new_game() -> void:
	inventory.clear()
	for item_id: Variant in new_game.starting_items:
		inventory.add(StringName(str(item_id)), int(new_game.starting_items[item_id]))
	_set_money(new_game.starting_money)
	selected_seed = &""
	_ensure_valid_seed()


# --- money -----------------------------------------------------------------------------------

func add_money(amount: int) -> void:
	if amount > 0:
		_set_money(money + amount)


## Spends if affordable. Returns false (and changes nothing) otherwise.
func spend_money(amount: int) -> bool:
	if amount < 0 or amount > money:
		return false
	_set_money(money - amount)
	return true


func _set_money(value: int) -> void:
	money = maxi(0, value)
	money_changed.emit(money)


# --- seeds -----------------------------------------------------------------------------------

## Seed item ids currently carried, in inventory order.
func get_seed_ids() -> Array[StringName]:
	var seeds: Array[StringName] = []
	for item_id in inventory.item_ids():
		var item: ItemData = content.get_item(item_id) if content != null else null
		if item != null and item.has_tag(&"seed"):
			seeds.append(item_id)
	return seeds


## Selects the next carried seed (wraps around).
func cycle_seed() -> void:
	var seeds := get_seed_ids()
	if seeds.is_empty():
		_select_seed(&"")
		return
	var index := seeds.find(selected_seed)
	_select_seed(seeds[(index + 1) % seeds.size()])


func _ensure_valid_seed() -> void:
	var seeds := get_seed_ids()
	if not seeds.has(selected_seed):
		_select_seed(seeds[0] if not seeds.is_empty() else &"")


func _select_seed(item_id: StringName) -> void:
	if selected_seed == item_id:
		return
	selected_seed = item_id
	selected_seed_changed.emit(selected_seed)


func _on_inventory_changed() -> void:
	_ensure_valid_seed()


# --- persistence (Saveable contract) ---------------------------------------------------------

func get_save_id() -> StringName:
	return &"player_state"


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"inventory": inventory.to_dict(),
		"selected_seed": String(selected_seed),
	}


## {} (e.g. a save from before Phase 3) gives the new-game belongings.
func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		reset_to_new_game()
		return
	inventory.from_dict(data.get("inventory", {}))
	_set_money(int(data.get("money", 0)))
	selected_seed = StringName(str(data.get("selected_seed", "")))
	_apply_upgrade_grants(int(data.get("version", 1)))
	_ensure_valid_seed()
	selected_seed_changed.emit(selected_seed)


## Gives an older save the items that newer versions start with (once: the next save is current).
func _apply_upgrade_grants(saved_version: int) -> void:
	for key: Variant in new_game.upgrade_grants:
		if int(str(key)) <= saved_version:
			continue
		var grants: Dictionary = new_game.upgrade_grants[key]
		for item_id: Variant in grants:
			var left := inventory.add(StringName(str(item_id)), int(grants[item_id]))
			if left > 0:
				push_warning("PlayerState: no room for %d %s granted by save upgrade" % [left, item_id])
