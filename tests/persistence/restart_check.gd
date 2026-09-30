extends Node
## One half of the cross-process persistence test. Run by tests/persistence/run_restart_test.sh:
##   --phase=write   boot the real game (new game), change state, save, quit
##   --phase=verify  boot the real game in a NEW process (continues from the save), check state
## Prints "RESTART CHECK PASS" / "RESTART CHECK FAIL: …" and exits 0 / 1.

const SAVE_DIR := "user://restart_test"
const MAIN_SCENE := "res://game/main/main.tscn"

const EXPECTED_MAP := &"village"
const EXPECTED_POSITION := Vector2(312, 264)
const EXPECTED_FACING := Vector2.RIGHT
const EXPECTED_DAY := 3
const EXPECTED_MINUTE := 360 + 250
const EXPECTED_FLAG := &"restart_check_flag"
const EXPECTED_COUNTER := &"restart_check_counter"
const GROWING_PLOT := &"farm:18,23"  # emberroot, 2 watered days, watered again today
const HARVESTED_PLOT := &"farm:19,23"  # pipweed harvested into the bag

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
	_check(main.current_map.map_id == &"farm", "new game must start on the farm")
	_write_farm(main)
	_check(main.change_map(EXPECTED_MAP, &"from_farm"), "could not change map")
	for i in EXPECTED_DAY:
		Clock.end_day()
	Clock.advance_minutes(EXPECTED_MINUTE - 360)
	main.player.global_position = EXPECTED_POSITION
	main.player.set_facing(EXPECTED_FACING)
	WorldState.set_flag(EXPECTED_FLAG)
	WorldState.increment(EXPECTED_COUNTER, 41)
	_check(SaveService.save_game(main.save_slot) == OK, "save_game returned an error")


## Works the farm through the real rules: two plots, a harvest, a sale.
func _write_farm(main: Main) -> void:
	var farm := main.session.farm
	var player := main.session.player
	for plot_id in [GROWING_PLOT, HARVESTED_PLOT]:
		farm.till(plot_id)
	farm.plant(GROWING_PLOT, ContentDB.get_crop(&"emberroot"))
	farm.plant(HARVESTED_PLOT, ContentDB.get_crop(&"pipweed"))
	player.inventory.remove(&"emberroot_seed", 1)
	player.inventory.remove(&"pipweed_seed", 1)
	for day in 3:
		farm.water(GROWING_PLOT)
		farm.water(HARVESTED_PLOT)
		farm.advance_day()
	var result := FarmActions.perform(farm, player, HARVESTED_PLOT)
	_check(result["action"] == FarmActions.Action.HARVEST and result["ok"], "harvest failed: %s" % result)
	player.inventory.add(&"emberroot", 2)
	Shipping.sell_all(player, ContentDB)  # sells the pipweed and the 2 emberroot
	player.inventory.add(&"bluecap", 3)  # unsold harvest stays in the bag
	farm.water(GROWING_PLOT)
	while player.selected_seed != &"bluecap_seed":
		player.cycle_seed()


func _verify_farm(main: Main) -> void:
	var farm := main.session.farm
	var player := main.session.player
	var growing := farm.get_plot(GROWING_PLOT)
	_check(growing != null and growing.tilled and growing.watered, "growing plot soil/watered")
	_check(growing != null and growing.crop != null and growing.crop.crop_id == &"emberroot", "crop type")
	_check(growing != null and growing.crop != null and growing.crop.days_grown == 3, "growth state")
	var harvested := farm.get_plot(HARVESTED_PLOT)
	_check(harvested != null and harvested.tilled and not harvested.has_crop(), "harvested plot")
	var expected_money := 50 + ContentDB.get_item(&"pipweed").base_value + 2 * ContentDB.get_item(&"emberroot").base_value
	_check(player.money == expected_money, "money %d, expected %d" % [player.money, expected_money])
	_check(player.inventory.count(&"bluecap") == 3, "harvested bluecap in bag")
	_check(player.inventory.count(&"pipweed") == 0, "sold pipweed gone")
	_check(player.inventory.count(&"pipweed_seed") == 5, "pipweed seeds %d" % player.inventory.count(&"pipweed_seed"))
	_check(player.inventory.count(&"emberroot_seed") == 2, "emberroot seeds")
	_check(player.selected_seed == &"bluecap_seed", "selected seed %s" % player.selected_seed)
	_check(main.hud.get_money_text() == "%d marks" % expected_money, "HUD money")


func _verify() -> void:
	_check(SaveService.has_save(1), "no save found from the write phase")
	var main := await _boot()
	_check(main.current_map.map_id == EXPECTED_MAP, "map %s" % main.current_map.map_id)
	_check(main.player.global_position == EXPECTED_POSITION, "position %s" % main.player.global_position)
	_check(main.player.facing == EXPECTED_FACING, "facing %s" % main.player.facing)
	_check(Clock.time.day_index == EXPECTED_DAY, "day %d" % Clock.time.day_index)
	_check(Clock.time.minute_of_day == EXPECTED_MINUTE, "minute %d" % Clock.time.minute_of_day)
	_check(WorldState.has_flag(EXPECTED_FLAG), "flag missing")
	_check(WorldState.get_flag(EXPECTED_COUNTER) == 41, "counter %s" % str(WorldState.get_flag(EXPECTED_COUNTER)))
	_check(WorldState.is_discovered(&"farm") and WorldState.is_discovered(EXPECTED_MAP), "discovered locations missing")
	_check(main.hud.get_clock_text() == Clock.time.format_clock(), "HUD not refreshed after load")
	_verify_farm(main)
	SaveService.delete_all_saves()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
