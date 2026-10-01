extends TestCase
## Kith and the seed shop inside the real game: wild kith on the maps, bonding with the interact
## button, the party menu (inspect, feed, active, rename), Pell's shop, the watering helper in the
## existing day transition, and persistence across map changes, restarts and old saves.

const MAIN_SCENE := preload("res://game/main/main.tscn")
const PHASE3_FIXTURE := "res://tests/fixtures/saves/v2_phase3_before_kith.json"
const SPRIGMOLE_SPOT := &"farm:38,25"

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


func _entities_of_type(map: WorldMap, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for node in map.entities.get_children():
		if is_instance_of(node, type):
			found.append(node)
	return found


func _wild(spawn_id: StringName) -> WildKith:
	for node in _entities_of_type(main.current_map, WildKith):
		if (node as WildKith).spawn_id == spawn_id:
			return node
	return null


func _npc(npc_id: StringName) -> Npc:
	for node in _entities_of_type(main.current_map, Npc):
		if (node as Npc).data.id == npc_id:
			return node
	return null


## Stands just below `target`, facing it, and presses interact.
func _use(target: Interactable) -> void:
	main.player.global_position = target.global_position + Vector2(0, 16)
	main.player.set_facing(Vector2.UP)
	await wait_physics_frames(3)
	assert_eq(main.player.probe.current_target, target, "facing %s" % target.name)
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


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_frames(1)
	await wait_frames(1)


func _planted(count: int) -> Array[StringName]:
	var farm := main.session.farm
	var ids: Array[StringName] = []
	for i in count:
		var id := StringName("farm:%d,23" % (18 + i))
		farm.till(id)
		farm.plant(id, ContentDB.get_crop(&"pipweed"))
		ids.append(id)
	return ids


# --- placement -------------------------------------------------------------------------------

func test_wild_kith_live_in_the_maps() -> void:
	var catalog: MapCatalog = load("res://data/maps/map_catalog.tres")
	var expected := {&"farm": [&"sprigmole"], &"forest": [&"bramblehog", &"cindercoot", &"rillet"], &"village": []}
	for map_id: StringName in expected:
		var map := catalog.instantiate_map(map_id)
		add_to_root(map)
		var species: Array[String] = []
		for node in _entities_of_type(map, WildKith):
			var wild := node as WildKith
			assert_true(String(wild.spawn_id).begins_with("%s:" % map_id), "spawn id %s" % wild.spawn_id)
			assert_not_null(wild.get_species(), "known species %s" % wild.kith_id)
			species.append(String(wild.kith_id))
		species.sort()
		var want: Array[String] = []
		for id: StringName in expected[map_id]:
			want.append(String(id))
		assert_eq(species, want, "%s wild kith" % map_id)


# --- bonding ---------------------------------------------------------------------------------

func test_bonding_a_wild_kith_with_the_interact_button() -> void:
	var player := main.session.player
	var wild := _wild(SPRIGMOLE_SPOT)
	assert_not_null(wild)
	assert_eq(main.hud.get_kith_text(), "", "no kith yet")

	await _use(wild)
	var lines := _close_messages()
	assert_true(lines[0].contains("backs away"), "no food yet: %s" % lines)
	assert_eq(main.hud.get_prompt_text().contains("Offer food"), true)

	player.inventory.add(&"pipweed", 2)
	await _use(wild)
	lines = _close_messages()
	assert_true(lines[0].contains("eats the Pipweed"), str(lines))
	assert_eq(player.inventory.count(&"pipweed"), 1, "one favourite food was enough")
	assert_true(main.hud.get_prompt_text().contains("Bond Charm"), main.hud.get_prompt_text())

	await _use(wild)
	lines = _close_messages()
	assert_true(lines[0].contains("joined your party"), str(lines))
	assert_eq(main.session.kith.size(), 1)
	var kith := main.session.kith.get_active()
	assert_eq(kith.species_id, &"sprigmole")
	assert_eq(kith.origin, SPRIGMOLE_SPOT)
	assert_eq(player.inventory.count(&"bond_charm"), 2)
	assert_false(wild.visible, "the bonded kith left its spot")
	await wait_physics_frames(3)
	assert_eq(main.player.probe.current_target, null, "nothing left to interact with")
	assert_true(main.hud.get_kith_text().begins_with("Sprigmole · Trust 10 Unfamiliar"), main.hud.get_kith_text())


# --- party menu ------------------------------------------------------------------------------

func test_party_menu_inspect_feed_active_rename() -> void:
	var roster := main.session.kith
	var mole := roster.add_new(&"sprigmole")
	var rillet := roster.add_new(&"rillet")
	main.session.player.inventory.add(&"pipweed", 2)
	main.session.player.inventory.add(&"bluecap", 1)
	var menu := main.hud.kith_menu

	await _press(&"open_kith")
	assert_true(menu.is_open(), "K opens the party")
	assert_true(Clock.is_paused())
	assert_false(main.player.is_control_enabled())
	assert_eq(menu.get_row_texts().size(), 2)
	assert_true(menu.get_row_texts()[0].begins_with("★ Sprigmole"), str(menu.get_row_texts()))
	assert_true(menu.get_detail().contains("Trust 10/100 (Unfamiliar)"), menu.get_detail())
	assert_true(menu.get_detail().contains("Helper: none"), menu.get_detail())

	await _press(&"ui_down")
	assert_true(menu.get_detail().contains("waters crops once Trust reaches 25"), menu.get_detail())
	await _press(&"interact")
	assert_eq(menu.page, KithMenu.Page.ACTIONS)
	menu.select(menu.find_row("Feed"))
	menu.choose()
	assert_eq(menu.page, KithMenu.Page.FEED)
	assert_true(menu.get_row_texts()[menu.find_row("Bluecap")].contains("loves it"))
	assert_true(menu.get_row_texts()[menu.find_row("Pipweed")].contains("will eat"))
	menu.select(menu.find_row("Bluecap"))
	menu.choose()
	assert_true(menu.get_message().contains("Rillet loved the Bluecap! Trust +8 (18"), menu.get_message())
	assert_eq(main.session.player.inventory.count(&"bluecap"), 0, "consumed from the one bag")
	menu.select(menu.find_row("Pipweed"))
	menu.choose()
	assert_true(menu.get_message().contains("full"), menu.get_message())
	assert_eq(main.session.player.inventory.count(&"pipweed"), 2, "refused food is kept")

	await _press(&"ui_cancel")
	assert_eq(menu.page, KithMenu.Page.ACTIONS)
	menu.select(menu.find_row("Make active"))
	menu.choose()
	assert_eq(roster.active_uid, rillet.uid)
	assert_eq(menu.page, KithMenu.Page.PARTY)
	assert_true(menu.get_row_texts()[1].begins_with("★ Rillet"))

	menu.select(0)
	menu.choose()
	menu.select(menu.find_row("Rename"))
	menu.choose()
	assert_eq(menu.page, KithMenu.Page.RENAME)
	menu.rename("Digby")
	assert_eq(mole.nickname, "Digby")
	assert_eq(menu.page, KithMenu.Page.ACTIONS)

	await _press(&"open_kith")
	assert_false(menu.is_open(), "K closes it again")
	assert_false(Clock.is_paused())
	assert_true(main.player.is_control_enabled())
	assert_true(main.hud.get_kith_text().begins_with("Rillet · Trust 18"), main.hud.get_kith_text())


func test_party_menu_opens_empty_and_not_over_other_modals() -> void:
	var menu := main.hud.kith_menu
	EventBus.dialogue_requested.emit(PackedStringArray(["Hello."]))
	assert_false(main.hud.open_kith_menu(), "not while a message is open")
	_close_messages()
	assert_true(main.hud.open_kith_menu())
	assert_true(menu.get_row_texts()[0].contains("No kith yet"))
	await _press(&"ui_cancel")
	assert_false(menu.is_open())


# --- seed shop -------------------------------------------------------------------------------

func test_buying_seeds_from_pell() -> void:
	main.change_map(&"village", &"from_farm")
	await wait_frames(1)
	var pell := _npc(&"pell")
	assert_not_null(pell)
	var player := main.session.player
	var menu := main.hud.shop_menu
	var money := player.money
	var seeds := player.inventory.count(&"emberroot_seed")

	await _use(pell)
	assert_true(menu.is_open(), "talking to Pell opens the shop")
	assert_true(WorldState.has_flag(&"met_pell"))
	assert_true(menu.get_title().begins_with("Pell's Seeds"), menu.get_title())
	assert_true(Clock.is_paused())
	var row := menu.find_row("Emberroot Seeds")
	assert_true(menu.get_row_texts()[row].contains("40 marks"), menu.get_row_texts()[row])
	menu.select(row)
	await _press(&"interact")
	assert_eq(player.money, money - 40)
	assert_eq(player.inventory.count(&"emberroot_seed"), seeds + 1)
	assert_true(menu.get_message().begins_with("Bought 1 Emberroot Seeds"), menu.get_message())
	assert_true(main.hud.get_money_text() == "%d marks" % player.money)

	await _press(&"interact")  # 10 marks left: can't afford another
	assert_true(menu.get_message().contains("Not enough marks"), menu.get_message())
	assert_eq(player.inventory.count(&"emberroot_seed"), seeds + 1)

	menu.select(menu.find_row("Leave"))
	menu.choose()
	assert_false(menu.is_open())
	assert_true(main.player.is_control_enabled())
	assert_false(Clock.is_paused())


# --- helper in the daily simulation ----------------------------------------------------------

func test_rillet_waters_the_farm_while_the_player_is_in_the_forest() -> void:
	var ids := _planted(4)
	var rillet := main.session.kith.add_new(&"rillet")
	rillet.trust = 30
	main.change_map(&"forest", &"from_farm")
	await wait_frames(1)

	var lines := await _sleep()
	assert_true(Array(lines).has("Rillet watered 3 plots."), str(lines))
	var watered := 0
	for id in ids:
		if main.session.farm.get_plot(id).watered:
			watered += 1
	assert_eq(watered, 3, "daily limit")
	assert_eq(main.current_map.map_id, &"forest", "the player never moved")

	await _sleep()  # those three grow overnight, then get watered again
	var grown := 0
	for id in ids:
		grown += main.session.farm.get_plot(id).crop.days_grown
	assert_eq(grown, 3)


func test_untrusted_rillet_does_not_help() -> void:
	_planted(2)
	main.session.kith.add_new(&"rillet")
	var lines := await _sleep()
	for line in lines:
		assert_false(line.contains("watered"), line)


# --- persistence -----------------------------------------------------------------------------

func test_party_survives_map_changes_save_and_restart() -> void:
	var roster := main.session.kith
	var a := roster.add_new(&"rillet", 1, &"forest:50,12")
	var b := roster.add_new(&"cindercoot", 1, &"forest:33,33")
	a.trust = 52
	a.fed_today = 1
	roster.set_nickname(b.uid, "Ember")
	roster.set_active(b.uid)
	WorldState.set_flag(KithBonding.bonded_flag(SPRIGMOLE_SPOT))
	main.change_map(&"village", &"from_farm")
	main.change_map(&"farm", &"from_village")
	await wait_frames(1)
	assert_eq(roster.size(), 2, "map changes don't touch the party")
	assert_true(main.hud.get_kith_text().begins_with("Ember"))
	assert_eq(SaveService.save_game(main.save_slot), OK)

	await _restart()

	roster = main.session.kith
	assert_eq(roster.size(), 2)
	assert_eq(roster.active_uid, b.uid)
	assert_eq(roster.get_kith(a.uid).trust, 52)
	assert_eq(roster.get_kith(a.uid).fed_today, 1)
	assert_eq(roster.get_kith(a.uid).origin, &"forest:50,12")
	assert_eq(roster.get_kith(b.uid).nickname, "Ember")
	assert_true(main.hud.get_kith_text().begins_with("Ember · Trust 10"), main.hud.get_kith_text())
	assert_false(_wild(SPRIGMOLE_SPOT).visible, "bonded spot stays empty after a restart")
	assert_ne(roster.add_new(&"bramblehog").uid, a.uid, "ids stay unique after loading")


func test_phase3_save_loads_with_an_empty_party_and_starter_charms() -> void:
	main.free()
	WorldState.reset()
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	DirAccess.copy_absolute(PHASE3_FIXTURE, SaveService.get_slot_path(1))
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = _boot()
	await wait_frames(2)

	var player := main.session.player
	assert_eq(main.player.global_position, Vector2(352, 360), "position kept")
	assert_eq(Clock.time.day_index, 1)
	assert_eq(Clock.time.minute_of_day, 480)
	assert_eq(player.money, 120, "money kept")
	assert_eq(player.inventory.count(&"pipweed"), 4, "bag kept")
	assert_eq(player.inventory.count(&"bluecap_seed"), 2)
	assert_eq(player.inventory.count(&"bond_charm"), 3, "Phase 4 starter charms granted")
	var crop := main.session.farm.get_plot(&"farm:18,23").crop
	assert_eq(crop.crop_id, &"bluecap")
	assert_eq(crop.days_grown, 1, "farm kept")
	assert_true(WorldState.has_flag(&"met_tamsin"))
	assert_eq(main.session.kith.size(), 0, "no kith before Phase 4")
	assert_true(_wild(SPRIGMOLE_SPOT).visible)

	assert_eq(SaveService.save_game(1), OK)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.get_slot_path(1)))
	assert_eq(int(raw["sections"]["player_state"]["version"]), PlayerState.SAVE_VERSION)
	assert_eq(int(raw["sections"]["kith"]["version"]), KithRoster.SAVE_VERSION)
	await _restart()
	assert_eq(main.session.player.inventory.count(&"bond_charm"), 3, "granted once, not on every load")
	assert_eq(main.session.player.money, 120)
