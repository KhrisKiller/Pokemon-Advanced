extends TestCase
## Clock: real-time accumulation, signals, pausing, curfew, end of day.
## Uses its own Clock instance (not the autoload) with processing disabled.

const ClockScript := preload("res://game/core/time/clock.gd")

var clock: Node
var config: TimeConfig


func before_each() -> void:
	config = TimeConfig.new()
	config.real_seconds_per_game_minute = 1.0
	clock = ClockScript.new()
	clock.setup(config)
	clock.set_process(false)
	add_to_root(clock)


func test_tick_accumulates_fractional_seconds() -> void:
	clock.tick(0.5)
	assert_eq(clock.time.minute_of_day, 360)
	clock.tick(0.6)
	assert_eq(clock.time.minute_of_day, 361)
	clock.tick(2.9)  # 0.1 left over + 2.9 = 3.0
	assert_eq(clock.time.minute_of_day, 364)


func test_time_scale_speeds_up_time() -> void:
	clock.time_scale = 10.0
	clock.tick(1.0)
	assert_eq(clock.time.minute_of_day, 370)


func test_emits_step_and_hour_signals() -> void:
	var steps: Array[int] = []
	var hours: Array[int] = []
	clock.time_step_changed.connect(func(t: GameTime) -> void: steps.append(t.get_display_minute_of_day()))
	clock.hour_changed.connect(func(h: int) -> void: hours.append(h))
	clock.advance_minutes(65)
	assert_eq(steps.size(), 6, "6:10, 6:20, … 7:00, 7:10")
	assert_eq(hours, [7] as Array[int])


func test_pause_requests_are_reason_keyed() -> void:
	clock.request_pause(&"dialogue")
	clock.request_pause(&"menu")
	clock.tick(10.0)
	assert_eq(clock.time.minute_of_day, 360, "paused clock does not move")
	clock.release_pause(&"dialogue")
	assert_true(clock.is_paused(), "still paused by the menu")
	clock.release_pause(&"menu")
	assert_false(clock.is_paused())
	clock.tick(2.0)
	assert_eq(clock.time.minute_of_day, 362)


func test_releasing_unknown_reason_is_harmless() -> void:
	clock.release_pause(&"nothing")
	assert_false(clock.is_paused())


func test_curfew_is_announced_once_and_time_stops() -> void:
	var count := [0]
	clock.curfew_reached.connect(func() -> void: count[0] += 1)
	clock.advance_minutes(2000)
	assert_eq(count[0], 1)
	assert_true(clock.time.is_day_over())
	clock.tick(100.0)
	clock.advance_minutes(5)
	assert_eq(count[0], 1, "curfew is not re-announced")


func test_end_day_starts_next_morning() -> void:
	var started := [false]
	clock.day_started.connect(func(_t: GameTime) -> void: started[0] = true)
	clock.advance_minutes(2000)
	clock.end_day()
	assert_true(started[0])
	assert_eq(clock.time.day_index, 1)
	assert_eq(clock.time.minute_of_day, 360)
	var count := [0]
	clock.curfew_reached.connect(func() -> void: count[0] += 1)
	clock.advance_minutes(2000)
	assert_eq(count[0], 1, "curfew works again on the new day")


func test_save_data_round_trip() -> void:
	clock.advance_minutes(123)
	clock.end_day()
	clock.advance_minutes(45)
	var data: Dictionary = clock.to_save_data()
	var other: Node = ClockScript.new()
	other.setup(config)
	other.load_save_data(data)
	assert_eq(other.time.day_index, 1)
	assert_eq(other.time.minute_of_day, 405)
	assert_eq(other.get_save_id(), &"clock")
	other.free()


func test_autoload_uses_shipped_config() -> void:
	var autoload: Node = tree.root.get_node("/root/Clock")
	assert_not_null(autoload)
	assert_almost_eq(autoload.config.real_seconds_per_game_minute, 0.7, 0.0001)
