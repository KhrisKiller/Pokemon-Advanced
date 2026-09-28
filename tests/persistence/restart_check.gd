extends Node
## One half of the cross-process persistence test. Run by tests/persistence/run_restart_test.sh:
##   --phase=write   boot the real game (new game), change state, save, quit
##   --phase=verify  boot the real game in a NEW process (continues from the save), check state
## Prints "RESTART CHECK PASS" / "RESTART CHECK FAIL: …" and exits 0 / 1.

const SAVE_DIR := "user://restart_test"
const MAIN_SCENE := "res://game/main/main.tscn"

const EXPECTED_POSITION := Vector2(312, 264)
const EXPECTED_FACING := Vector2.RIGHT
const EXPECTED_DAY := 3
const EXPECTED_MINUTE := 360 + 250
const EXPECTED_FLAG := &"restart_check_flag"
const EXPECTED_COUNTER := &"restart_check_counter"

var _failures: PackedStringArray = []


func _ready() -> void:
	SaveService.save_dir = SAVE_DIR
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	match phase:
		"write":
			await _write()
		"verify":
			await _verify()
		_:
			_failures.append("unknown phase '%s'" % phase)
	if _failures.is_empty():
		print("RESTART CHECK PASS (%s)" % phase)
		get_tree().quit(0)
	else:
		print("RESTART CHECK FAIL (%s): %s" % [phase, "; ".join(_failures)])
		get_tree().quit(1)


func _boot() -> Main:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.fade_duration = 0.0
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _write() -> void:
	SaveService.delete_all_saves()
	var main := await _boot()
	_check(Clock.time.day_index == 0, "write phase must start a new game")
	for i in EXPECTED_DAY:
		Clock.end_day()
	Clock.advance_minutes(EXPECTED_MINUTE - 360)
	main.player.global_position = EXPECTED_POSITION
	main.player.set_facing(EXPECTED_FACING)
	WorldState.set_flag(EXPECTED_FLAG)
	WorldState.increment(EXPECTED_COUNTER, 41)
	WorldState.discover_location(main.current_map.map_id)
	_check(SaveService.save_game(main.save_slot) == OK, "save_game returned an error")


func _verify() -> void:
	_check(SaveService.has_save(1), "no save found from the write phase")
	var main := await _boot()
	_check(main.player.global_position == EXPECTED_POSITION, "position %s" % main.player.global_position)
	_check(main.player.facing == EXPECTED_FACING, "facing %s" % main.player.facing)
	_check(Clock.time.day_index == EXPECTED_DAY, "day %d" % Clock.time.day_index)
	_check(Clock.time.minute_of_day == EXPECTED_MINUTE, "minute %d" % Clock.time.minute_of_day)
	_check(WorldState.has_flag(EXPECTED_FLAG), "flag missing")
	_check(WorldState.get_flag(EXPECTED_COUNTER) == 41, "counter %s" % str(WorldState.get_flag(EXPECTED_COUNTER)))
	_check(WorldState.is_discovered(main.current_map.map_id), "discovered location missing")
	_check(main.hud.get_clock_text() == Clock.time.format_clock(), "HUD not refreshed after load")
	SaveService.delete_all_saves()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
