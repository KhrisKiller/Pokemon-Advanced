extends TestCase
## WorldState: flags, locations and persistence (own instance, not the autoload).

const WorldStateScript := preload("res://game/core/world_state.gd")

var world: Node


func before_each() -> void:
	world = WorldStateScript.new()  # not added to the tree, so it does not register with SaveService


func after_each() -> void:
	world.free()


func test_flags_default_and_set() -> void:
	assert_false(world.has_flag(&"met_reeve"))
	assert_eq(world.get_flag(&"met_reeve", "none"), "none")
	world.set_flag(&"met_reeve")
	assert_true(world.has_flag(&"met_reeve"))
	world.set_flag(&"met_reeve", false)
	assert_false(world.has_flag(&"met_reeve"), "false flags are not 'set'")


func test_flag_changed_emits_only_on_change() -> void:
	var changes: Array = []
	world.flag_changed.connect(func(f: StringName, v: Variant) -> void: changes.append([f, v]))
	world.set_flag(&"a", 1)
	world.set_flag(&"a", 1)
	world.set_flag(&"a", true)  # different type → change
	assert_eq(changes.size(), 2)


func test_increment() -> void:
	assert_eq(world.increment(&"visits"), 1)
	assert_eq(world.increment(&"visits", 4), 5)
	assert_eq(world.get_flag(&"visits"), 5)


func test_clear_flag() -> void:
	world.set_flag(&"x")
	world.clear_flag(&"x")
	assert_eq(world.get_flag(&"x"), null)


func test_discover_location_once() -> void:
	assert_true(world.discover_location(&"farm"))
	assert_false(world.discover_location(&"farm"))
	assert_true(world.is_discovered(&"farm"))
	assert_false(world.is_discovered(&"forest"))


func test_round_trip_through_json() -> void:
	world.set_flag(&"met_reeve")
	world.set_flag(&"visits", 7)
	world.set_flag(&"rival_name", "Wren")
	world.discover_location(&"village")
	world.discover_location(&"farm")
	var json := JSON.stringify(world.to_save_data())
	var restored: Node = WorldStateScript.new()
	restored.load_save_data(JSON.parse_string(json))
	assert_eq(restored.get_flag(&"met_reeve"), true)
	assert_eq(typeof(restored.get_flag(&"visits")), TYPE_INT, "JSON floats come back as ints")
	assert_eq(restored.get_flag(&"visits"), 7)
	assert_eq(restored.get_flag(&"rival_name"), "Wren")
	assert_eq(restored.get_discovered_locations().size(), 2)
	assert_true(restored.is_discovered(&"village"))
	restored.free()


func test_load_replaces_previous_state() -> void:
	world.set_flag(&"old")
	world.load_save_data({"flags": {"new": true}})
	assert_false(world.has_flag(&"old"))
	assert_true(world.has_flag(&"new"))


func test_load_empty_resets() -> void:
	world.set_flag(&"old")
	world.discover_location(&"farm")
	world.load_save_data({})
	assert_false(world.has_flag(&"old"))
	assert_false(world.is_discovered(&"farm"))


func test_load_ignores_malformed_data() -> void:
	world.load_save_data({"flags": "nope", "discovered": 12})
	assert_eq(world.get_discovered_locations().size(), 0)
