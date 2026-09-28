extends TestCase
## Map transitions through the real Main: walking into exits, preserved player/world state,
## saving in another map, curfew away from home.

const MAIN_SCENE := preload("res://game/main/main.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var main: Main


func before_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)


func after_each() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 1.0


func _boot() -> Main:
	var m := MAIN_SCENE.instantiate() as Main
	m.fade_duration = 0.0
	add_to_root(m)
	return m


func _wait_until_settled() -> void:
	for i in 60:
		await tree.process_frame
		if not main.is_transitioning():
			return
	fail("transition did not finish")


func _spawn_position(map_id: StringName, spawn_id: StringName) -> Vector2:
	var map := main.map_catalog.instantiate_map(map_id)
	var pos := (map.get_node(NodePath("SpawnPoints/" + String(spawn_id))) as Marker2D).position
	map.free()
	return pos


func test_new_game_starts_in_the_farmhouse() -> void:
	assert_eq(main.current_map.map_id, &"farm")
	assert_true(main.player.global_position.distance_to(main.current_map.get_spawn_position()) < 1.0)
	assert_true(WorldState.is_discovered(&"farm"))


func test_travel_moves_player_to_target_spawn() -> void:
	var player_before := main.player
	main.player.set_facing(Vector2.LEFT)
	main.travel_to(&"village", &"from_farm")
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, &"village")
	assert_eq(main.player, player_before, "the same Player node is kept")
	assert_eq(main.player.get_parent(), main.current_map.entities)
	assert_eq(main.player.global_position, _spawn_position(&"village", &"from_farm"))
	assert_eq(main.player.facing, Vector2.LEFT, "facing preserved")
	assert_true(main.player.is_control_enabled(), "control restored")
	assert_false(Clock.is_paused(), "clock released")
	assert_true(WorldState.is_discovered(&"village"))
	assert_eq(main.hud.get_location_text(), "Brambleford")
	assert_eq(main.player.camera.limit_right, 54 * 16, "camera limits follow the new map")


func test_old_map_is_freed() -> void:
	var old_map := main.current_map
	main.travel_to(&"forest", &"from_farm")
	await _wait_until_settled()
	await wait_frames(1)
	assert_false(is_instance_valid(old_map))
	assert_eq(main.world.get_child_count(), 1)


func test_walking_into_the_west_exit_goes_to_the_village() -> void:
	var changes: Array[StringName] = []
	EventBus.map_changed.connect(func(id: StringName) -> void: changes.append(id))
	main.player.global_position = _spawn_position(&"farm", &"from_village")
	main.player.camera.reset_smoothing()
	await wait_physics_frames(2)
	Input.action_press(&"move_left")
	for i in 120:
		await tree.physics_frame
		if main.current_map.map_id == &"village":
			break
	Input.action_release(&"move_left")
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, &"village", "walked into the exit")
	assert_eq(main.player.global_position.distance_to(_spawn_position(&"village", &"from_farm")) < 24.0, true,
			"arrived at the matching spawn")
	assert_eq(changes, [&"village"] as Array[StringName], "exactly one map change (regression: trigger loop)")


func test_requests_from_triggers_outside_the_current_map_are_ignored() -> void:
	var stale := MapTransition.new()
	add_to_root(stale)
	EventBus.map_transition_requested.emit(&"village", &"from_farm", stale)
	EventBus.map_transition_requested.emit(&"village", &"from_farm", null)
	await wait_frames(2)
	assert_eq(main.current_map.map_id, &"farm")
	var real := main.current_map.find_children("*", "MapTransition", true, false)[0] as MapTransition
	var target := real.target_map_id
	EventBus.map_transition_requested.emit(target, real.target_spawn_id, real)
	await wait_frames(2)
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, target, "a trigger of the current map works")


func test_round_trip_through_all_areas_keeps_state() -> void:
	WorldState.set_flag(&"carry_me", 5)
	Clock.advance_minutes(90)
	for step in [[&"village", &"from_farm"], [&"farm", &"from_village"], [&"forest", &"from_farm"], [&"farm", &"from_forest"]]:
		main.travel_to(step[0], step[1])
		await _wait_until_settled()
		assert_eq(main.current_map.map_id, step[0])
	assert_eq(WorldState.get_flag(&"carry_me"), 5, "world state untouched by travel")
	assert_eq(Clock.time.minute_of_day, 360 + 90, "no time passes during transitions")
	assert_eq(WorldState.get_discovered_locations().size(), 3)
	assert_eq(main.world.get_child_count(), 1, "only one map loaded")


func test_transition_pauses_time_while_fading() -> void:
	main.fade_duration = 0.05
	main.travel_to(&"village", &"from_farm")
	assert_true(main.is_transitioning())
	assert_true(Clock.get_pause_reasons().has(Main.TRAVEL_MODAL))
	assert_false(main.player.is_control_enabled())
	await _wait_until_settled()
	assert_false(Clock.is_paused())


func test_second_request_during_transition_is_ignored() -> void:
	main.fade_duration = 0.05
	main.travel_to(&"village", &"from_farm")
	main.travel_to(&"forest", &"from_farm")
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, &"village")


func test_unknown_map_is_ignored() -> void:
	main.travel_to(&"atlantis", &"Default")
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, &"farm")


func test_save_in_village_and_restart_continues_there() -> void:
	main.travel_to(&"village", &"from_farm")
	await _wait_until_settled()
	main.player.global_position = Vector2(400, 300)
	assert_eq(SaveService.save_game(main.save_slot), OK)
	assert_eq(SaveService.read_meta(main.save_slot)["summary"]["location"], "Brambleford")
	main.free()
	WorldState.reset()
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)
	assert_eq(main.current_map.map_id, &"village")
	assert_eq(main.player.global_position, Vector2(400, 300))
	assert_true(WorldState.is_discovered(&"village"))


func test_collapsing_in_the_forest_wakes_you_at_home() -> void:
	main.travel_to(&"forest", &"from_farm")
	await _wait_until_settled()
	Clock.advance_minutes(24 * 60)
	await _wait_until_settled()
	assert_eq(main.current_map.map_id, &"farm")
	assert_true(main.player.global_position.distance_to(main.current_map.get_spawn_position(&"Default")) < 1.0)
	assert_eq(Clock.time.day_index, 1)
