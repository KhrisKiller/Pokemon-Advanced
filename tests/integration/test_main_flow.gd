extends TestCase
## The real entry scene: boot, HUD, message box, day transitions.

const MAIN_SCENE := preload("res://game/main/main.tscn")

var main: Main


func before_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0  # tests drive time explicitly
	main = MAIN_SCENE.instantiate() as Main
	main.start_map_id = &"test_map"  # these tests exercise the Phase 1 test map
	main.fade_duration = 0.0
	add_to_root(main)
	await wait_frames(2)


func after_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 1.0


func test_boots_with_map_player_and_hud() -> void:
	assert_not_null(main.current_map)
	assert_eq(main.current_map.map_id, &"test_map")
	assert_not_null(main.player)
	assert_eq(main.player.get_parent(), main.current_map.entities, "player is y-sorted with entities")
	assert_true(main.player.global_position.distance_to(main.current_map.get_spawn_position()) < 1.0)
	assert_eq(main.player.camera.limit_right, 48 * 16)
	assert_eq(main.hud.get_clock_text(), "6:00 AM")


func test_hud_clock_follows_time() -> void:
	Clock.advance_minutes(95)
	assert_eq(main.hud.get_clock_text(), "7:30 AM")


func test_sign_prompt_and_message_pause_time() -> void:
	var sign := main.current_map.entities.get_node("WelcomeSign") as Node2D
	main.player.global_position = sign.global_position + Vector2(0, 18)
	main.player.set_facing(Vector2.UP)
	await wait_physics_frames(3)
	assert_eq(main.hud.get_prompt_text(), "[E] Read")

	assert_true(main.player.try_interact())
	var box := main.hud.message_box
	assert_true(box.is_open())
	assert_eq(box.get_current_line(), "WRENFIELD — test grounds.")
	assert_true(Clock.is_paused(), "time stops during messages")
	assert_false(main.player.is_control_enabled(), "player is locked during messages")
	assert_eq(main.hud.get_prompt_text(), "", "prompt hidden during messages")

	box.advance()
	box.advance()
	box.advance()
	assert_false(box.is_open())
	assert_false(Clock.is_paused())
	assert_true(main.player.is_control_enabled())


func test_sleeping_starts_next_morning() -> void:
	Clock.advance_minutes(600)
	EventBus.sleep_requested.emit(null)
	await _wait_for_transition()
	assert_eq(Clock.time.day_index, 1)
	assert_eq(Clock.time.minute_of_day, 360)
	assert_false(Clock.get_pause_reasons().has(Main.TRANSITION_MODAL))
	assert_true(main.hud.message_box.is_open(), "wake-up message shown")
	assert_eq(main.hud.message_box.get_current_line(), "You slept well.")


func test_curfew_sends_player_home() -> void:
	main.player.global_position = Vector2(40 * 16, 25 * 16)
	Clock.advance_minutes(24 * 60)  # reaches 2:00 AM → curfew
	await _wait_for_transition()
	assert_eq(Clock.time.day_index, 1)
	var home := main.current_map.get_spawn_position()
	assert_true(main.player.global_position.distance_to(home) < 1.0, "woke up at home")
	assert_eq(main.hud.message_box.get_current_line(), "You collapsed from exhaustion and somehow made it home.")


func test_double_sleep_request_runs_one_transition() -> void:
	main.fade_duration = 0.05
	EventBus.sleep_requested.emit(null)
	EventBus.sleep_requested.emit(null)
	await _wait_for_transition()
	assert_eq(Clock.time.day_index, 1, "only one day passed")


func _wait_for_transition() -> void:
	for i in 120:
		await tree.process_frame
		if not main.is_transitioning():
			return
	fail("day transition did not finish")
