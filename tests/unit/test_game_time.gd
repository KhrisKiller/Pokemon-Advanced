extends TestCase
## GameTime: calendar math, clamping, rollover, formatting, serialisation.

var config: TimeConfig
var time: GameTime


func before_each() -> void:
	config = TimeConfig.new()
	time = GameTime.new(config)


func test_new_game_starts_on_spring_1_year_1_at_six() -> void:
	assert_eq(time.day_index, 0)
	assert_eq(time.minute_of_day, 360)
	assert_eq(time.get_hour(), 6)
	assert_eq(time.get_season_id(), &"spring")
	assert_eq(time.get_day_of_season(), 1)
	assert_eq(time.get_year(), 1)
	assert_eq(time.get_weekday_name(), "Moonday")


func test_advance_moves_minutes_and_hours() -> void:
	var passed := time.advance(95)
	assert_eq(passed, 95)
	assert_eq(time.get_hour(), 7)
	assert_eq(time.get_minute(), 35)


func test_advance_ignores_non_positive_values() -> void:
	assert_eq(time.advance(0), 0)
	assert_eq(time.advance(-30), 0)
	assert_eq(time.minute_of_day, 360)


func test_advance_is_clamped_at_day_end() -> void:
	var passed := time.advance(24 * 60)
	assert_eq(passed, 1560 - 360, "only the remaining minutes of the day pass")
	assert_eq(time.minute_of_day, 1560)
	assert_true(time.is_day_over())
	assert_eq(time.advance(10), 0, "no time passes after the day is over")


func test_after_midnight_hours_wrap() -> void:
	time.set_to(0, 25 * 60 + 30)  # 1:30 AM of the same game day
	assert_eq(time.get_hour(), 1)
	assert_almost_eq(time.get_hour_float(), 1.5, 0.001)
	assert_eq(time.format_clock(), "1:30 AM")


func test_start_next_day_resets_to_morning() -> void:
	time.advance(600)
	time.start_next_day()
	assert_eq(time.day_index, 1)
	assert_eq(time.minute_of_day, 360)
	assert_eq(time.get_day_of_season(), 2)
	assert_eq(time.get_weekday_name(), "Tideday")


func test_season_and_year_rollover() -> void:
	time.set_to(27, 360)
	assert_eq(time.get_season_id(), &"spring")
	assert_eq(time.get_day_of_season(), 28)
	time.start_next_day()
	assert_eq(time.get_season_id(), &"summer")
	assert_eq(time.get_day_of_season(), 1)
	time.set_to(28 * 4 - 1, 360)
	assert_eq(time.get_season_id(), &"winter")
	assert_eq(time.get_year(), 1)
	time.start_next_day()
	assert_eq(time.get_season_id(), &"spring")
	assert_eq(time.get_year(), 2)
	assert_eq(time.get_day_of_season(), 1)


func test_weekday_cycles_every_seven_days() -> void:
	time.set_to(7, 360)
	assert_eq(time.get_weekday_name(), "Moonday")
	time.set_to(13, 360)
	assert_eq(time.get_weekday_name(), "Restday")


func test_format_clock_uses_display_step() -> void:
	time.advance(7)  # 6:07 → shown as 6:00
	assert_eq(time.format_clock(), "6:00 AM")
	time.advance(3)
	assert_eq(time.format_clock(), "6:10 AM")
	time.set_to(0, 12 * 60 + 45)
	assert_eq(time.format_clock(), "12:40 PM")
	time.set_to(0, 24 * 60)
	assert_eq(time.format_clock(), "12:00 AM")


func test_format_date() -> void:
	time.set_to(30, 360)
	assert_eq(time.format_date(), "Rootday, Summer 3 · Year 1")


func test_serialisation_round_trip() -> void:
	time.set_to(45, 1000)
	var restored := GameTime.new(config)
	restored.from_dict(time.to_dict())
	assert_eq(restored.day_index, 45)
	assert_eq(restored.minute_of_day, 1000)


func test_from_dict_clamps_invalid_data() -> void:
	time.from_dict({"day_index": -5, "minute_of_day": 99999})
	assert_eq(time.day_index, 0)
	assert_eq(time.minute_of_day, config.get_day_end_minute())


func test_config_changes_rules() -> void:
	var short := TimeConfig.new()
	short.days_per_season = 7
	short.day_start_hour = 8
	var t := GameTime.new(short)
	assert_eq(t.get_hour(), 8)
	t.set_to(7, 480)
	assert_eq(t.get_season_id(), &"summer")


func test_shipped_config_resource_loads() -> void:
	var shipped: TimeConfig = load("res://data/config/time_config.tres")
	assert_not_null(shipped)
	assert_eq(shipped.season_ids.size(), shipped.season_names.size(), "season ids and names match")
	assert_eq(shipped.weekday_names.size(), 7)
	assert_gt(shipped.day_end_hour, shipped.day_start_hour)
