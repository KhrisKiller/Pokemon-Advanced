extends Node
## Dev tool: plays a short scripted session of the real game and saves screenshots.
## Needs a display (use xvfb-run on a headless machine):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/capture_screenshots.tscn -- --out=/tmp/shots
## Screenshots are 2× nearest-neighbour upscales of the 640×360 game view.

const MAIN_SCENE := "res://game/main/main.tscn"

var _out_dir := "user://screenshots"
var _main: Main


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	SaveService.save_dir = "user://screenshot_saves"  # never touch the player's real saves
	SaveService.delete_all_saves()
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await _run()
	get_tree().quit()


func _run() -> void:
	await _frames(20)
	await _shot("01_farm_wake_up")

	# Walk south out of the farmhouse door.
	Input.action_press(&"move_down")
	await get_tree().create_timer(1.6).timeout
	Input.action_release(&"move_down")
	await _frames(20)
	await _shot("02_farm_outside")

	# Read the farm sign.
	var sign := _main.current_map.entities.get_node("FarmSign") as Node2D
	_main.player.global_position = sign.global_position + Vector2(0, 18)
	_main.player.set_facing(Vector2.UP)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	await _shot("03_interaction_prompt")
	_main.player.try_interact()
	await _frames(5)
	await _shot("04_sign_message")
	_main.hud.message_box.close()

	await _farm_demo()
	await _kith_demo()

	# Tour the areas through the real transition flow.
	await _travel(&"village", &"from_farm")
	await _shot("05_village_arrival")
	_main.player.global_position = Vector2(27 * 16, 21 * 16)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	await _shot("06_village_plaza")
	await _talk_to("Tamsin", "06b_talk_tamsin")
	await _shop_demo()
	await _travel(&"forest", &"from_farm")
	await _shot("07_forest_arrival")
	await _talk_to("Odile", "07b_talk_odile")
	_main.player.global_position = Vector2(46 * 16, 12 * 16)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	await _shot("08_forest_pond")

	await _helper_demo()

	_set_time(23 * 60 + 30)
	await _frames(5)
	await _shot("09_forest_night")


## Till, plant and water five plots, then sleep and water until they're ready; harvest and sell.
func _farm_demo() -> void:
	var seeds: Array[StringName] = [&"pipweed_seed", &"pipweed_seed", &"bluecap_seed", &"emberroot_seed", &"pipweed_seed"]
	for i in seeds.size():
		while _main.session.player.selected_seed != seeds[i]:
			_main.session.player.cycle_seed()
		var id := StringName("farm:%d,23" % (18 + i))
		for step in 3:  # till, plant, water
			await _use_plot(id)
	await _shot("10_farm_planted")
	for day in 5:
		await _sleep()
		if day == 0:
			await _shot("11_farm_next_morning_dry")
		for i in 5:
			var id := StringName("farm:%d,23" % (18 + i))
			if not _main.session.farm.is_mature(id):
				await _use_plot(id)
		if day == 1:
			await _shot("12_farm_growing")
	await _shot("13_farm_ready")
	await _use_plot(&"farm:18,23")
	await _shot("14_harvest_message")
	_main.hud.message_box.close()
	for i in range(1, 5):
		await _use_plot(StringName("farm:%d,23" % (18 + i)))
		_main.hud.message_box.close()
	_main.hud.toggle_inventory()
	await _frames(3)
	await _shot("15_bag")
	_main.hud.toggle_inventory()
	var crate := _main.current_map.entities.get_node("ShippingCrate") as Node2D
	_main.player.global_position = crate.global_position + Vector2(0, 16)
	_main.player.set_facing(Vector2.UP)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	_main.player.try_interact()
	await _frames(5)
	await _shot("16_sold")
	_main.hud.message_box.close()


## Befriends the Sprigmole on the farm (food, then a Bond Charm) and opens the party menu.
func _kith_demo() -> void:
	_main.session.player.inventory.add(&"pipweed", 3)  # the demo sold its harvest
	var wild := _main.current_map.entities.get_node("WildSprigmole_38_25") as Interactable
	await _face(wild, Vector2(18, 0), Vector2.LEFT)
	await _shot("17_wild_kith_prompt")
	_main.player.try_interact()
	await _frames(5)
	await _shot("18_wild_kith_fed")
	_main.hud.message_box.close()
	await _frames(5)
	_main.player.try_interact()
	await _frames(5)
	await _shot("19_kith_bonded")
	_main.hud.message_box.close()
	await _frames(5)
	var menu := _main.hud.kith_menu
	_main.hud.open_kith_menu()
	await _frames(3)
	await _shot("20_kith_menu")
	menu.choose()  # actions
	menu.choose()  # feed
	menu.select(menu.find_row("Pipweed"))
	menu.choose()
	await _frames(3)
	await _shot("21_kith_fed")
	menu.close_menu()
	await _frames(3)


func _shop_demo() -> void:
	var pell := _main.current_map.entities.get_node("Pell") as Interactable
	await _face(pell, Vector2(0, 18), Vector2.UP)
	_main.player.try_interact()
	await _frames(3)
	var menu := _main.hud.shop_menu
	menu.select(menu.find_row("Bluecap"))
	menu.choose()
	await _frames(3)
	await _shot("06c_seed_shop")
	menu.close_menu()
	await _frames(3)


## Bonds the pond Rillet, trusts it enough to help, and sleeps in the forest: it waters the farm.
func _helper_demo() -> void:
	var player := _main.session.player
	player.inventory.add(&"bluecap", 2)
	var wild := _main.current_map.entities.get_node("WildRillet_50_12") as Interactable
	await _face(wild, Vector2(18, 0), Vector2.LEFT)
	await _shot("08b_wild_rillet")
	for step in 2:
		_main.player.try_interact()
		await _frames(3)
		_main.hud.message_box.close()
		await _frames(3)
	var rillet := _main.session.kith.get_active()
	for kith in _main.session.kith.get_members():
		if kith.species_id == &"rillet":
			rillet = kith
	rillet.trust = 30  # several days of feeding, skipped for the tour
	for i in 4:
		var id := StringName("farm:%d,23" % (23 + i))
		_main.session.farm.till(id)
		_main.session.farm.plant(id, ContentDB.get_crop(&"pipweed"))
	EventBus.sleep_requested.emit(null)
	await get_tree().process_frame
	while _main.is_transitioning():
		await get_tree().process_frame
	await _frames(3)
	var box := _main.hud.message_box
	while box.is_open() and not box.get_current_line().contains("watered"):
		box.advance()
	await _frames(3)
	await _shot("08c_helper_watered")
	box.close()
	await _frames(3)


func _face(target: Node2D, offset: Vector2, facing: Vector2) -> void:
	_main.player.global_position = target.global_position + offset
	_main.player.set_facing(facing)
	_main.player.camera.reset_smoothing()
	for i in 3:
		await get_tree().physics_frame
	await _frames(5)


func _use_plot(plot_id: StringName) -> void:
	for node in _main.current_map.entities.get_children():
		if node is FarmPlot and node.plot_id == plot_id:
			_main.player.global_position = node.global_position + Vector2(0, 16)
			_main.player.set_facing(Vector2.UP)
			_main.player.camera.reset_smoothing()
			for i in 3:
				await get_tree().physics_frame
			_main.player.try_interact()
			await _frames(2)
			return


func _sleep() -> void:
	EventBus.sleep_requested.emit(null)
	await get_tree().process_frame
	while _main.is_transitioning():
		await get_tree().process_frame
	await _frames(5)
	_main.hud.message_box.close()
	await _frames(2)


func _talk_to(npc_name: String, shot_name: String) -> void:
	var npc := _main.current_map.entities.get_node(npc_name) as Node2D
	_main.player.global_position = npc.global_position + Vector2(18, 0)
	_main.player.set_facing(Vector2.LEFT)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	_main.player.try_interact()
	await _frames(5)
	await _shot(shot_name)
	_main.hud.message_box.close()


func _travel(map_id: StringName, spawn_id: StringName) -> void:
	_main.travel_to(map_id, spawn_id)
	while _main.is_transitioning():
		await get_tree().process_frame
	await _frames(15)


func _set_time(minute_of_day: int) -> void:
	Clock.time.set_to(Clock.time.day_index, minute_of_day)
	Clock.advance_minutes(0)
	Clock.time_step_changed.emit(Clock.time)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
