extends TestCase
## Regression: a real v1 save file loads into the current game with every value intact, and
## re-saving produces a current-format file that loads the same way.

const MAIN_TSCN := preload("res://game/main/main.tscn")
const V1_FIXTURE := "res://tests/fixtures/saves/v1_phase2_early.json"

var main: Main


func before_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	DirAccess.copy_absolute(V1_FIXTURE, SaveService.get_slot_path(1))


func after_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 1.0


func _boot() -> void:
	main = MAIN_TSCN.instantiate() as Main
	main.fade_duration = 0.0
	add_to_root(main)
	await wait_frames(2)


func _assert_fixture_state() -> void:
	assert_eq(main.current_map.map_id, &"test_map")
	assert_eq(main.player.global_position, Vector2(300, 250), "position")
	assert_eq(main.player.facing, Vector2.LEFT, "v1 [x, y] facing converted")
	assert_eq(Clock.time.day_index, 2, "day")
	assert_eq(Clock.time.minute_of_day, 495, "time")
	assert_eq(WorldState.get_flag(&"test_flag"), 3, "int flag")
	assert_true(WorldState.has_flag(&"met_reeve"), "bool flag")
	assert_true(WorldState.is_discovered(&"test_map"), "discovered location")


func test_v1_save_loads_on_start() -> void:
	await _boot()
	_assert_fixture_state()


func test_resave_writes_current_format_and_round_trips() -> void:
	await _boot()
	assert_eq(SaveService.save_game(1), OK)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.get_slot_path(1)))
	assert_eq(SaveFormat.get_version(raw), SaveFormat.CURRENT_VERSION)
	assert_eq(raw["sections"]["player"]["facing"], "left", "player section is v2")
	assert_eq(int(raw["sections"]["player"]["version"]), 2)
	var meta := SaveService.read_meta(1)
	assert_eq(meta["summary"]["time"], "8:10 AM")
	assert_eq(meta["game_version"], ProjectSettings.get_setting("application/config/version"))

	main.free()
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	WorldState.reset()
	await _boot()
	_assert_fixture_state()
