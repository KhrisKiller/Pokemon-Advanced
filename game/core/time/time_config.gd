class_name TimeConfig
extends Resource
## Tunable rules of the in-game calendar. The instance used by the game is
## `res://data/config/time_config.tres`.

## Real seconds that one in-game minute lasts while the clock runs.
@export_range(0.01, 10.0, 0.01) var real_seconds_per_game_minute: float = 0.7
## Hour the player wakes up (0–23).
@export_range(0, 23) var day_start_hour: int = 6
## Hour the day ends. Values above 24 mean "after midnight": 26 = 2:00 the next morning.
@export_range(1, 30) var day_end_hour: int = 26
@export_range(1, 112) var days_per_season: int = 28
## Stable ids, used in saves and data conditions.
@export var season_ids: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]
## Display names, same order as `season_ids`.
@export var season_names: PackedStringArray = ["Spring", "Summer", "Autumn", "Winter"]
@export var weekday_names: PackedStringArray = [
	"Moonday", "Tideday", "Rootday", "Emberday", "Galeday", "Starday", "Restday",
]
## The HUD clock only updates in steps of this many minutes (Stardew-style 10-minute ticks).
@export_range(1, 60) var display_step_minutes: int = 10


func get_day_start_minute() -> int:
	return day_start_hour * 60


func get_day_end_minute() -> int:
	return day_end_hour * 60


func get_days_per_year() -> int:
	return days_per_season * season_ids.size()
