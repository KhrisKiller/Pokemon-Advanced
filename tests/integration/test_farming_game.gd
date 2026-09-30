extends TestCase
## Farming inside the real game: plots on the farm map, the player's interact button, the existing
## day transition as the daily tick, the bag, the shipping crate, HUD, travel and save/restart.

const MAIN_SCENE := preload("res://game/main/main.tscn")
const PLOT_ID := &"farm:18,23"

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
	var m := MAIN_SCENE.instantiate() as Main
	m.fade_duration = 0.0
	add_to_root(m)
	return m


func _restart() -> void:
	main.free()
	WorldState.reset()
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)


func _plot(plot_id: StringName = PLOT_ID) -> FarmPlot:
	for node in main.current_map.entities.get_children():
		if node is FarmPlot and node.plot_id == plot_id:
			return node
	return null


## Stands just below a plot, facing it, and presses interact.
func _use_plot(plot_id: StringName = PLOT_ID) -> void:
	var plot := _plot(plot_id)
	main.player.global_position = plot.global_position + Vector2(0, 16)
	main.player.set_facing(Vector2.UP)
	await wait_physics_frames(3)  # overlaps register one physics step after a teleport
	assert_eq(main.player.probe.current_target, plot, "facing the plot")
	main.player.try_interact()
	await wait_frames(1)


func _close_messages() -> PackedStringArray:
	var lines := PackedStringArray()
	var box := main.hud.message_box
	while box.is_open():
		lines.append(box.get_current_line())
		box.advance()
	return lines


func _sleep() -> PackedStringArray:
	EventBus.sleep_requested.emit(null)
	for i in 30:
		await tree.process_frame
		if not main.is_transitioning():
			break
	return _close_messages()


func _crop() -> CropState:
	return main.session.farm.get_plot(PLOT_ID).crop


func _select_seed(seed_id: StringName) -> void:
	while main.session.player.selected_seed != seed_id:
		main.session.player.cycle_seed()


# --- map & wiring ----------------------------------------------------------------------------

func test_farm_has_plots_and_a_shipping_crate() -> void:
	var plots: Array[StringName] = []
	for node in main.current_map.entities.get_children():
		if node is FarmPlot:
			plots.append(node.plot_id)
	assert_eq(plots.size(), 20)
	for id in plots:
		assert_true(String(id).begins_with("farm:"), "stable map-based id")
	assert_not_null(main.current_map.entities.get_node_or_null("ShippingCrate"))
	assert_true(main.session.farm.get_plot_ids().size() >= 20, "plots registered in the farm state")


func test_new_game_starts_with_seeds_and_money() -> void:
	var config: NewGameConfig = load("res://data/config/new_game.tres")
	assert_eq(main.session.player.money, config.starting_money)
	assert_eq(main.hud.get_money_text(), "%d marks" % config.starting_money)
	assert_true(main.hud.get_seed_text().contains("×"), "HUD shows the selected seed")


# --- the full loop ---------------------------------------------------------------------------

func test_full_loop_till_plant_water_sleep_grow_harvest_sell() -> void:
	_select_seed(&"pipweed_seed")
	var seeds := main.session.player.inventory.count(&"pipweed_seed")
	var plot := _plot()

	assert_eq(plot.get_prompt(), "Till")
	await _use_plot()
	assert_true(main.session.farm.get_plot(PLOT_ID).tilled, "tilled")
	assert_true(plot.get_node("Soil").visible, "soil drawn")
	assert_eq(main.hud.get_prompt_text(), "[E] Plant Pipweed Seeds", "prompt follows the plot")

	await _use_plot()  # Day 1: plant
	assert_eq(_crop().crop_id, &"pipweed")
	assert_eq(main.session.player.inventory.count(&"pipweed_seed"), seeds - 1, "seed used")
	assert_true(plot.get_node("Crop").visible, "crop drawn")

	await _use_plot()  # water
	assert_true(main.session.farm.get_plot(PLOT_ID).watered)
	assert_eq(plot.get_node("Soil").frame, FarmPlot.SoilFrame.WET)

	var lines := await _sleep()  # → Day 2
	assert_eq(Clock.time.day_index, 1)
	assert_eq(_crop().days_grown, 1, "grew overnight")
	assert_true(lines.has("Your watered crops grew overnight."))
	assert_false(main.session.farm.get_plot(PLOT_ID).watered, "soil dried")
	assert_eq(plot.get_node("Soil").frame, FarmPlot.SoilFrame.DRY)

	await _use_plot()  # water
	await _sleep()  # → Day 3
	await _use_plot()  # water
	lines = await _sleep()  # → Day 4: mature
	assert_true(main.session.farm.is_mature(PLOT_ID))
	assert_true(lines.has("1 crop is ready to harvest!"))
	assert_eq(plot.get_node("Crop").frame, 3, "mature sprite")

	await _use_plot()  # harvest
	assert_eq(_close_messages(), PackedStringArray(["Harvested 1 Pipweed."]))
	assert_eq(main.session.player.inventory.count(&"pipweed"), 1, "harvest in the bag")
	assert_null_crop()

	var money := main.session.player.money
	var crate := main.current_map.entities.get_node("ShippingCrate") as ShippingCrate
	main.player.global_position = crate.global_position + Vector2(0, 16)
	main.player.set_facing(Vector2.UP)
	await wait_physics_frames(3)
	assert_eq(main.hud.get_prompt_text(), "[E] Sell produce")
	main.player.try_interact()
	var price := ContentDB.get_item(&"pipweed").base_value
	assert_eq(_close_messages(), PackedStringArray(["Sold 1 Pipweed for %d marks." % price]))
	assert_eq(main.session.player.money, money + price, "money updated")
	assert_eq(main.hud.get_money_text(), "%d marks" % (money + price), "HUD updated")
	assert_eq(main.session.player.inventory.count(&"pipweed"), 0)


func assert_null_crop() -> void:
	assert_false(main.session.farm.get_plot(PLOT_ID).has_crop(), "crop removed after harvest")


func test_unwatered_crop_does_not_grow_when_sleeping() -> void:
	await _use_plot()  # till
	await _use_plot()  # plant
	await _sleep()
	await _sleep()
	assert_eq(_crop().days_grown, 0)


func test_crops_grow_while_the_player_is_away() -> void:
	await _use_plot()
	await _use_plot()
	await _use_plot()  # watered
	main.travel_to(&"village", &"from_farm")
	for i in 10:
		await tree.process_frame
	assert_eq(main.current_map.map_id, &"village")
	Clock.advance_minutes(24 * 60)  # collapse in the village → wake at home
	for i in 30:
		await tree.process_frame
		if not main.is_transitioning():
			break
	_close_messages()
	assert_eq(main.current_map.map_id, &"farm")
	assert_eq(_crop().days_grown, 1, "the farm ticked while its map was unloaded")
	assert_eq(_plot().get_node("Crop").frame, _crop().get_stage(ContentDB.get_crop(_crop().crop_id)))


func test_nothing_to_sell_message() -> void:
	var crate := main.current_map.entities.get_node("ShippingCrate") as ShippingCrate
	crate.interact(main.player)
	assert_eq(_close_messages(), PackedStringArray(["Nothing to sell. Harvested crops can be sold here."]))


# --- HUD & input -----------------------------------------------------------------------------

func test_cycle_seed_input_changes_selection() -> void:
	var before := main.session.player.selected_seed
	var event := InputEventAction.new()
	event.action = &"cycle_seed"
	event.pressed = true
	main._unhandled_input(event)
	assert_ne(main.session.player.selected_seed, before)
	var seed := ContentDB.get_item(main.session.player.selected_seed)
	assert_true(main.hud.get_seed_text().begins_with(seed.display_name))


func test_bag_panel_lists_items_and_pauses_time() -> void:
	main.hud.toggle_inventory()
	assert_true(main.hud.is_inventory_open())
	assert_true(Clock.is_paused())
	assert_false(main.player.is_control_enabled())
	assert_true(main.hud.get_inventory_text().contains("Pipweed Seeds ×6"))
	main.hud.toggle_inventory()
	assert_false(main.hud.is_inventory_open())
	assert_false(Clock.is_paused())
	assert_true(main.player.is_control_enabled())


# --- persistence -----------------------------------------------------------------------------

func test_farm_bag_and_money_survive_save_and_restart() -> void:
	_select_seed(&"bluecap_seed")
	await _use_plot()
	await _use_plot()
	await _use_plot()
	await _sleep()  # auto-saves: day 2, bluecap 1 day grown
	await _use_plot()  # watered, not saved yet
	main.session.player.inventory.add(&"emberroot", 2)
	main.session.player.add_money(40)
	var money := main.session.player.money
	var seeds := main.session.player.inventory.count(&"bluecap_seed")
	var selected := main.session.player.selected_seed
	assert_eq(SaveService.save_game(main.save_slot), OK)

	await _restart()

	var plot := main.session.farm.get_plot(PLOT_ID)
	assert_true(plot.tilled)
	assert_true(plot.watered, "watered state saved")
	assert_eq(plot.crop.crop_id, &"bluecap", "crop type saved")
	assert_eq(plot.crop.days_grown, 1, "growth saved")
	assert_eq(main.session.player.money, money)
	assert_eq(main.session.player.inventory.count(&"emberroot"), 2)
	assert_eq(main.session.player.inventory.count(&"bluecap_seed"), seeds)
	assert_eq(main.session.player.selected_seed, selected)
	assert_eq(main.hud.get_money_text(), "%d marks" % money)
	assert_true(_plot().get_node("Crop").visible, "restored crop drawn")
	await _sleep()
	assert_eq(main.session.farm.get_plot(PLOT_ID).crop.days_grown, 2, "keeps growing after load")


func test_save_from_before_farming_loads_with_new_game_belongings() -> void:
	main.free()
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	DirAccess.copy_absolute("res://tests/fixtures/saves/v2_phase2_before_farming.json", SaveService.get_slot_path(1))
	WorldState.reset()
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)
	var config: NewGameConfig = load("res://data/config/new_game.tres")
	assert_eq(main.player.global_position, Vector2(400, 260), "Phase 2 position kept")
	assert_eq(Clock.time.day_index, 1, "Phase 2 day kept")
	assert_true(WorldState.has_flag(&"met_tamsin"), "Phase 2 flags kept")
	assert_eq(main.session.player.money, config.starting_money, "belongings default to a new game")
	assert_eq(main.session.player.inventory.count(&"pipweed_seed"), int(config.starting_items["pipweed_seed"]))
	assert_false(main.session.farm.get_plot(PLOT_ID).tilled, "farm starts untouched")
