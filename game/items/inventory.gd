class_name Inventory
extends RefCounted
## Pure slot-based inventory: a fixed number of slots holding stacks of item ids.
## Stack limits come from item data through `content` (anything with get_item(id) -> ItemData).
## This is the single inventory model for the player (and later chests, shops, kith bags).

signal changed

const SAVE_VERSION := 1
const DEFAULT_STACK_MAX := 99

var capacity: int
var content: Object
## Each slot is {} (empty) or {"item_id": StringName, "quantity": int}.
var _slots: Array[Dictionary] = []


func _init(slot_count: int = 24, content_source: Object = null) -> void:
	capacity = slot_count
	content = content_source
	clear()


func clear() -> void:
	_slots.clear()
	for i in capacity:
		_slots.append({})
	changed.emit()


func stack_max(item_id: StringName) -> int:
	if content != null and content.has_method("get_item"):
		var item: ItemData = content.get_item(item_id)
		if item != null:
			return maxi(1, item.stack_max)
	return DEFAULT_STACK_MAX


## Adds up to `quantity` items, filling existing stacks first. Returns how many did NOT fit.
func add(item_id: StringName, quantity: int) -> int:
	if quantity <= 0 or item_id == &"":
		return 0
	var remaining := quantity
	var limit := stack_max(item_id)
	for slot in _slots:
		if remaining == 0:
			break
		if not slot.is_empty() and slot["item_id"] == item_id and slot["quantity"] < limit:
			var moved := mini(limit - int(slot["quantity"]), remaining)
			slot["quantity"] += moved
			remaining -= moved
	for i in _slots.size():
		if remaining == 0:
			break
		if _slots[i].is_empty():
			var moved := mini(limit, remaining)
			_slots[i] = {"item_id": item_id, "quantity": moved}
			remaining -= moved
	if remaining != quantity:
		changed.emit()
	return remaining


## Removes exactly `quantity` items or nothing. Returns true on success.
func remove(item_id: StringName, quantity: int) -> bool:
	if quantity <= 0:
		return true
	if count(item_id) < quantity:
		return false
	var remaining := quantity
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if remaining == 0:
			break
		if not slot.is_empty() and slot["item_id"] == item_id:
			var taken := mini(int(slot["quantity"]), remaining)
			slot["quantity"] -= taken
			remaining -= taken
			if slot["quantity"] <= 0:
				_slots[i] = {}
	changed.emit()
	return true


## How many more of `item_id` would fit.
func space_for(item_id: StringName) -> int:
	var limit := stack_max(item_id)
	var space := 0
	for slot in _slots:
		if slot.is_empty():
			space += limit
		elif slot["item_id"] == item_id:
			space += limit - int(slot["quantity"])
	return space


func count(item_id: StringName) -> int:
	var total := 0
	for slot in _slots:
		if not slot.is_empty() and slot["item_id"] == item_id:
			total += int(slot["quantity"])
	return total


func has(item_id: StringName, quantity: int = 1) -> bool:
	return count(item_id) >= quantity


func is_empty() -> bool:
	for slot in _slots:
		if not slot.is_empty():
			return false
	return true


## Distinct item ids, in slot order.
func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot in _slots:
		if not slot.is_empty() and not ids.has(slot["item_id"]):
			ids.append(slot["item_id"])
	return ids


## Copies of the non-empty slots.
func get_stacks() -> Array[Dictionary]:
	var stacks: Array[Dictionary] = []
	for slot in _slots:
		if not slot.is_empty():
			stacks.append(slot.duplicate())
	return stacks


# --- persistence -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append({} if slot.is_empty() else {"item_id": String(slot["item_id"]), "quantity": slot["quantity"]})
	return {"version": SAVE_VERSION, "capacity": capacity, "slots": slots}


func from_dict(data: Dictionary) -> void:
	clear()
	var slots: Variant = data.get("slots", [])
	if typeof(slots) != TYPE_ARRAY:
		return
	for i in mini(slots.size(), capacity):
		var slot: Variant = slots[i]
		if typeof(slot) != TYPE_DICTIONARY or not slot.has("item_id"):
			continue
		var quantity := int(slot.get("quantity", 0))
		if quantity > 0:
			_slots[i] = {"item_id": StringName(str(slot["item_id"])), "quantity": quantity}
	changed.emit()
