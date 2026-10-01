extends TestCase
## Full-game save/load: player position/facing, time/day and world state survive a save, and a
## fresh Main (as after a restart) continues from the save. The true cross-process restart test is
## tests/persistence/run_restart_test.sh.

const MAIN_TSCN := preload("res://game/main/main.tscn")

var main: Main


func before_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)


func after_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 1.0


func _boot() -> Main:
	var m := MAIN_TSCN.instantiate() as Main
	m.fade_duration = 0.0
	add_to_root(m)
	return m


func _restart() -> void:
	# Simulate quitting and relaunching: throw away the game and all in-memory state.
	main.free()
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	WorldState.reset()
	main = _boot()
	await wait_frames(2)


func test_main_registers_session_providers_in_order() -> void:
	# Phase 3 added player_state (bag, money) and farm, Phase 4 kith; the player section still loads last.
	assert_eq(SaveService.get_provider_ids(), [&"clock", &"world", &"player_state", &"farm", &"kith", &"player"] as Array[StringName])


func test_providers_unregister_when_main_leaves() -> void:
	main.free()
	assert_eq(SaveService.get_provider_ids().size(), 0)
	main = _boot()
	await wait_frames(1)


func test_new_game_without_save_starts_at_spawn() -> void:
	assert_false(SaveService.has_save(main.save_slot))
	assert_true(main.player.global_position.distance_to(main.current_map.get_spawn_position()) < 1.0)
	assert_eq(Clock.time.day_index, 0)


func test_state_survives_save_and_restart() -> void:
	main.player.global_position = Vector2(300, 250)
	main.player.set_facing(Vector2.LEFT)
	Clock.end_day()
	Clock.end_day()
	Clock.advance_minutes(135)
	WorldState.set_flag(&"test_flag", 3)
	WorldState.discover_location(&"test_map")
	assert_eq(SaveService.save_game(main.save_slot), OK)

	await _restart()

	assert_eq(main.player.global_position, Vector2(300, 250), "position restored")
	assert_eq(main.player.facing, Vector2.LEFT, "facing restored")
	assert_eq(Clock.time.day_index, 2, "day restored")
	assert_eq(Clock.time.minute_of_day, 360 + 135, "time restored")
	assert_eq(WorldState.get_flag(&"test_flag"), 3, "world flag restored")
	assert_true(WorldState.is_discovered(&"test_map"), "discovered location restored")
	assert_eq(main.hud.get_clock_text(), "8:10 AM", "HUD reflects loaded time")


func test_sleeping_auto_saves() -> void:
	EventBus.sleep_requested.emit(null)
	for i in 30:
		await tree.process_frame
		if not main.is_transitioning():
			break
	assert_true(SaveService.has_save(main.save_slot), "sleeping writes a save")
	var lines := PackedStringArray()
	var box := main.hud.message_box
	while box.is_open():
		lines.append(box.get_current_line())
		box.advance()
	assert_true(lines.has("(Game saved.)"))

	await _restart()
	assert_eq(Clock.time.day_index, 1, "the next morning was saved")
	assert_eq(Clock.time.minute_of_day, 360)


func test_load_game_restores_earlier_state_in_same_session() -> void:
	main.player.global_position = Vector2(200, 200)
	SaveService.save_game(main.save_slot)
	main.player.global_position = Vector2(500, 300)
	Clock.advance_minutes(300)
	assert_eq(SaveService.load_game(main.save_slot), OK)
	assert_eq(main.player.global_position, Vector2(200, 200))
	assert_eq(Clock.time.minute_of_day, 360)


func test_unknown_saved_map_falls_back_to_spawn() -> void:
	main.load_save_data({"map_id": "no_such_map", "position": [1, 1], "facing": [0, 1]})
	assert_true(main.player.global_position.distance_to(main.current_map.get_spawn_position()) < 1.0)
