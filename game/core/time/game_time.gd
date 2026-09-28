class_name GameTime
extends RefCounted
## Pure model of the in-game date and time. It has no engine dependencies, so it is testable
## and serialisable.
##
## State is two integers:
## - `day_index`: absolute day since the start of the game (0 = Spring 1, Year 1)
## - `minute_of_day`: minutes since 0:00 of that day; runs from day start (6:00 = 360)
##   to day end (26:00 = 1560, i.e. 2:00 AM). It never goes past the day end.

const SAVE_VERSION := 1

var config: TimeConfig
var day_index: int = 0
var minute_of_day: int = 0


func _init(time_config: TimeConfig = null) -> void:
	config = time_config if time_config != null else TimeConfig.new()
	minute_of_day = config.get_day_start_minute()


# --- mutation --------------------------------------------------------------------------------

## Advances the clock by up to `minutes`, stopping at the end of the day.
## Returns how many minutes actually passed.
func advance(minutes: int) -> int:
	if minutes <= 0:
		return 0
	var allowed := mini(minutes, config.get_day_end_minute() - minute_of_day)
	minute_of_day += allowed
	return allowed


## Moves to the start of the next day (used by sleeping or passing out).
func start_next_day() -> void:
	day_index += 1
	minute_of_day = config.get_day_start_minute()


func set_to(new_day_index: int, new_minute_of_day: int) -> void:
	day_index = maxi(new_day_index, 0)
	minute_of_day = clampi(new_minute_of_day, 0, config.get_day_end_minute())


# --- queries ---------------------------------------------------------------------------------

func is_day_over() -> bool:
	return minute_of_day >= config.get_day_end_minute()


## Hour in 0–23 (26:00 → 2).
func get_hour() -> int:
	return (minute_of_day / 60) % 24


func get_minute() -> int:
	return minute_of_day % 60


## Time of day in hours as a float in [0, 24), used for lighting.
func get_hour_float() -> float:
	return fmod(minute_of_day / 60.0, 24.0)


func get_year() -> int:
	return day_index / config.get_days_per_year() + 1


func get_season_index() -> int:
	return (day_index / config.days_per_season) % config.season_ids.size()


func get_season_id() -> StringName:
	return config.season_ids[get_season_index()]


func get_season_name() -> String:
	return config.season_names[get_season_index()]


## 1-based day within the season.
func get_day_of_season() -> int:
	return day_index % config.days_per_season + 1


func get_weekday_index() -> int:
	return day_index % config.weekday_names.size()


func get_weekday_name() -> String:
	return config.weekday_names[get_weekday_index()]


## The minute of day rounded down to the display step (HUD shows 6:00, 6:10, …).
func get_display_minute_of_day() -> int:
	return minute_of_day - minute_of_day % config.display_step_minutes


# --- formatting ------------------------------------------------------------------------------

## "6:00 AM", "12:30 PM", "2:00 AM". Uses the display step.
func format_clock() -> String:
	var shown := get_display_minute_of_day()
	var hour24 := (shown / 60) % 24
	var minute := shown % 60
	var suffix := "AM" if hour24 < 12 else "PM"
	var hour12 := hour24 % 12
	if hour12 == 0:
		hour12 = 12
	return "%d:%02d %s" % [hour12, minute, suffix]


## "Moonday, Spring 1 · Year 1"
func format_date() -> String:
	return "%s, %s %d · Year %d" % [get_weekday_name(), get_season_name(), get_day_of_season(), get_year()]


# --- persistence (Saveable contract, see TECHNICAL_DESIGN.md §9) -----------------------------

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "day_index": day_index, "minute_of_day": minute_of_day}


func from_dict(data: Dictionary) -> void:
	set_to(int(data.get("day_index", 0)), int(data.get("minute_of_day", config.get_day_start_minute())))
