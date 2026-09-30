extends TestCase
## Inventory: stacking, limits, removal, capacity, persistence.


class FakeContent:
	extends RefCounted
	func get_item(id: StringName) -> ItemData:
		var item := ItemData.new()
		item.id = id
		item.stack_max = 5 if id == &"small" else 99
		return item


var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(3, FakeContent.new())


func test_starts_empty() -> void:
	assert_true(inv.is_empty())
	assert_eq(inv.count(&"pipweed"), 0)
	assert_eq(inv.get_stacks().size(), 0)


func test_add_stacks_into_one_slot() -> void:
	assert_eq(inv.add(&"pipweed", 3), 0)
	assert_eq(inv.add(&"pipweed", 4), 0)
	assert_eq(inv.count(&"pipweed"), 7)
	assert_eq(inv.get_stacks().size(), 1)


func test_stack_limit_spills_into_new_slots() -> void:
	assert_eq(inv.add(&"small", 12), 0)
	assert_eq(inv.get_stacks().size(), 3)
	assert_eq(inv.count(&"small"), 12)


func test_overflow_is_returned_when_full() -> void:
	assert_eq(inv.add(&"small", 20), 5, "3 slots × 5 = 15 fit")
	assert_eq(inv.count(&"small"), 15)
	assert_eq(inv.add(&"pipweed", 1), 1, "no free slot left")


func test_space_for() -> void:
	inv.add(&"small", 3)
	assert_eq(inv.space_for(&"small"), 2 + 5 + 5)
	assert_eq(inv.space_for(&"pipweed"), 99 * 2)


func test_remove_is_all_or_nothing() -> void:
	inv.add(&"pipweed", 4)
	assert_false(inv.remove(&"pipweed", 5))
	assert_eq(inv.count(&"pipweed"), 4)
	assert_true(inv.remove(&"pipweed", 4))
	assert_true(inv.is_empty(), "empty slots are freed")


func test_remove_across_stacks() -> void:
	inv.add(&"small", 8)
	assert_true(inv.remove(&"small", 6))
	assert_eq(inv.count(&"small"), 2)


func test_invalid_quantities_are_ignored() -> void:
	assert_eq(inv.add(&"pipweed", 0), 0)
	assert_eq(inv.add(&"pipweed", -3), 0)
	assert_true(inv.is_empty())


func test_changed_signal() -> void:
	var count := [0]
	inv.changed.connect(func() -> void: count[0] += 1)
	inv.add(&"pipweed", 1)
	inv.remove(&"pipweed", 1)
	assert_eq(count[0], 2)


func test_item_ids_in_slot_order() -> void:
	inv.add(&"b", 1)
	inv.add(&"a", 1)
	assert_eq(inv.item_ids(), [&"b", &"a"] as Array[StringName])


func test_round_trip_through_json() -> void:
	inv.add(&"pipweed", 7)
	inv.add(&"small", 6)
	var restored := Inventory.new(3, FakeContent.new())
	restored.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_eq(restored.count(&"pipweed"), 7)
	assert_eq(restored.count(&"small"), 6)
	assert_eq(restored.get_stacks().size(), 3)
	assert_eq(typeof(restored.get_stacks()[0]["quantity"]), TYPE_INT)


func test_from_dict_ignores_bad_slots() -> void:
	inv.from_dict({"slots": [{"item_id": "x", "quantity": 0}, "junk", {"item_id": "y", "quantity": 2}, {"item_id": "z", "quantity": 1}, {"item_id": "overflow", "quantity": 1}]})
	assert_eq(inv.count(&"x"), 0)
	assert_eq(inv.count(&"y"), 2)
	assert_eq(inv.count(&"overflow"), 0, "slots beyond capacity dropped")
