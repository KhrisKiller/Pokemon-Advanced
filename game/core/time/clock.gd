extends Node
## The game clock (autoload `Clock`). It owns the single `GameTime`, advances it in real time
## while nothing pauses it, and announces changes.
##
## Pausing is done with reason-keyed requests, so independent systems (dialogue, menus,
## cutscenes, fades) never un-pause each other by accident.

signal minute_changed(time: GameTime)
## Emitted when the HUD-visible time changes (every `display_step_minutes`).
signal time_step_changed(time: GameTime)
signal hour_changed(hour: int)
## Emitted once when the clock reaches the end of the day (2:00 AM by default).
signal curfew_reached
signal day_started(time: GameTime)

const DEFAULT_CONFIG_PATH := "res://data/config/time_config.tres"

var config: TimeConfig
var time: GameTime
## Debug/test multiplier for how fast time passes.
var time_scale: float = 1.0

var _pause_reasons: Dictionary[StringName, bool] = {}
var _accumulated_seconds: float = 0.0
var _curfew_announced := false


func _init() -> void:
	var loaded: Resource = load(DEFAULT_CONFIG_PATH) if ResourceLoader.exists(DEFAULT_CONFIG_PATH) else null
	setup(loaded as TimeConfig)


## Resets the clock to the first morning of a new game with the given config.
func setup(new_config: TimeConfig = null) -> void:
	config = new_config if new_config != null else TimeConfig.new()
	time = GameTime.new(config)
	_pause_reasons.clear()
	_accumulated_seconds = 0.0
	_curfew_announced = false


func _process(delta: float) -> void:
	tick(delta)


## Advances by `real_seconds` of real time. Called every frame; public for tests.
func tick(real_seconds: float) -> void:
	if is_paused() or time.is_day_over():
		return
	_accumulated_seconds += real_seconds * time_scale
	var minutes := int(_accumulated_seconds / config.real_seconds_per_game_minute)
	if minutes <= 0:
		return
	_accumulated_seconds -= minutes * config.real_seconds_per_game_minute
	advance_minutes(minutes)


## Advances the clock by whole game minutes, emitting signals for each minute that passes.
func advance_minutes(minutes: int) -> void:
	for i in minutes:
		var previous_hour := time.get_hour()
		var previous_step := time.get_display_minute_of_day()
		if time.advance(1) == 0:
			break
		minute_changed.emit(time)
		if time.get_display_minute_of_day() != previous_step:
			time_step_changed.emit(time)
		if time.get_hour() != previous_hour:
			hour_changed.emit(time.get_hour())
	if time.is_day_over():
		_accumulated_seconds = 0.0
		if not _curfew_announced:
			_curfew_announced = true
			curfew_reached.emit()


## Ends the current day and starts the next morning. Only the day-transition flow should call
## this (see Main); it is where growth, the world tick and auto-save will hook in.
func end_day() -> void:
	time.start_next_day()
	_accumulated_seconds = 0.0
	_curfew_announced = false
	day_started.emit(time)
	time_step_changed.emit(time)


# --- pausing ---------------------------------------------------------------------------------

func request_pause(reason: StringName) -> void:
	_pause_reasons[reason] = true


func release_pause(reason: StringName) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func get_pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_pause_reasons.keys())
	return reasons


# --- persistence (Saveable contract) ---------------------------------------------------------

func get_save_id() -> StringName:
	return &"clock"


func to_save_data() -> Dictionary:
	return time.to_dict()


func load_save_data(data: Dictionary) -> void:
	time.from_dict(data)
	_accumulated_seconds = 0.0
	_curfew_announced = time.is_day_over()
	time_step_changed.emit(time)
