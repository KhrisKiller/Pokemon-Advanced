extends TestCase
## PlayerState (money, seeds, new game) and the shipped content (items, crops, new-game config).

var config: NewGameConfig
var player: PlayerState


func before_each() -> void:
	config = load("res://data/config/new_game.tres")
	player = PlayerState.new(config, ContentDB)


func test_content_is_consistent() -> void:
	assert_eq(ContentDB.validate(), PackedStringArray(), "no content problems")
	assert_gt(ContentDB.get_crop_ids().size(), 2, "at least 3 crops")
	for crop_id in ContentDB.get_crop_ids():
		var crop := ContentDB.get_crop(crop_id)
		assert_eq(ContentDB.get_crop_for_seed(crop.seed_item_id), crop)


func test_new_game_belongings_come_from_config() -> void:
	assert_eq(player.money, config.starting_money)
	for item_id: Variant in config.starting_items:
		assert_eq(player.inventory.count(StringName(item_id)), int(config.starting_items[item_id]))
	assert_ne(player.selected_seed, &"", "a seed is selected")


func test_money() -> void:
	player.add_money(25)
	assert_eq(player.money, config.starting_money + 25)
	assert_false(player.spend_money(999999))
	assert_true(player.spend_money(25))
	assert_eq(player.money, config.starting_money)
	player.add_money(-10)
	assert_eq(player.money, config.starting_money, "negative additions ignored")


func test_cycle_seed_wraps_through_carried_seeds() -> void:
	var seeds := player.get_seed_ids()
	assert_eq(seeds.size(), 3)
	var seen: Array[StringName] = []
	for i in seeds.size():
		seen.append(player.selected_seed)
		player.cycle_seed()
	assert_eq(player.selected_seed, seen[0], "wrapped around")
	seen.sort()
	seeds.sort()
	assert_eq(seen, seeds)


func test_selection_moves_on_when_a_seed_runs_out() -> void:
	var first := player.selected_seed
	player.inventory.remove(first, player.inventory.count(first))
	assert_ne(player.selected_seed, first)
	for seed in player.get_seed_ids():
		player.inventory.remove(seed, player.inventory.count(seed))
	assert_eq(player.selected_seed, &"", "no seeds, nothing selected")


func test_crops_are_not_seeds() -> void:
	player.inventory.add(&"pipweed", 3)
	assert_false(player.get_seed_ids().has(&"pipweed"))


func test_save_round_trip() -> void:
	player.inventory.add(&"emberroot", 4)
	player.add_money(123)
	player.cycle_seed()
	var restored := PlayerState.new(config, ContentDB)
	restored.load_save_data(JSON.parse_string(JSON.stringify(player.to_save_data())))
	assert_eq(restored.money, player.money)
	assert_eq(restored.inventory.count(&"emberroot"), 4)
	assert_eq(restored.selected_seed, player.selected_seed)
	assert_eq(restored.get_save_id(), &"player_state")


func test_missing_section_gives_new_game_belongings() -> void:
	player.inventory.clear()
	player.add_money(500)
	player.load_save_data({})
	assert_eq(player.money, config.starting_money)
	assert_eq(player.inventory.count(&"pipweed_seed"), int(config.starting_items["pipweed_seed"]))


func test_new_game_starts_with_bond_charms() -> void:
	assert_eq(player.inventory.count(&"bond_charm"), 3)


func test_pre_phase4_section_gets_the_upgrade_grant_once() -> void:
	var old := {"version": 1, "money": 80, "selected_seed": "pipweed_seed",
			"inventory": {"slots": [{"item_id": "pipweed_seed", "quantity": 2}]}}
	player.load_save_data(old)
	assert_eq(player.inventory.count(&"bond_charm"), 3, "version 1 saves get the Phase 4 starter charms")
	assert_eq(player.money, 80)
	var current := player.to_save_data()
	assert_eq(current["version"], PlayerState.SAVE_VERSION)
	var again := PlayerState.new(config, ContentDB)
	again.load_save_data(JSON.parse_string(JSON.stringify(current)))
	assert_eq(again.inventory.count(&"bond_charm"), 3, "not granted twice")
