extends TestCase
## Farming rules (FarmState, FarmActions, Shipping) against the real crop data, no scene tree.

const PLOT := &"farm:17,21"

var farm: FarmState
var player: PlayerState
var pipweed: CropData
var bluecap: CropData


func before_each() -> void:
	farm = FarmState.new(ContentDB)
	player = PlayerState.new(load("res://data/config/new_game.tres"), ContentDB)
	pipweed = ContentDB.get_crop(&"pipweed")
	bluecap = ContentDB.get_crop(&"bluecap")


func _select(seed_id: StringName) -> void:
	while player.selected_seed != seed_id:
		player.cycle_seed()


func _act() -> Dictionary:
	return FarmActions.perform(farm, player, PLOT)


func test_new_plot_must_be_tilled_first() -> void:
	assert_eq(FarmActions.next_action(farm, PLOT), FarmActions.Action.TILL)
	assert_false(farm.can_plant(PLOT))
	assert_false(farm.water(PLOT), "untilled soil can't be watered")
	assert_true(farm.till(PLOT))
	assert_false(farm.till(PLOT), "already tilled")
	assert_true(farm.can_plant(PLOT))


func test_planting_consumes_a_seed() -> void:
	_select(&"pipweed_seed")
	var seeds := player.inventory.count(&"pipweed_seed")
	_act()  # till
	var result := _act()  # plant
	assert_eq(result["action"], FarmActions.Action.PLANT)
	assert_true(result["ok"])
	assert_eq(player.inventory.count(&"pipweed_seed"), seeds - 1)
	assert_eq(farm.get_plot(PLOT).crop.crop_id, &"pipweed")
	assert_false(farm.plant(PLOT, pipweed), "one crop per plot")


func test_planting_without_seeds_fails_cleanly() -> void:
	for seed in player.get_seed_ids():
		player.inventory.remove(seed, player.inventory.count(seed))
	_act()
	var result := _act()
	assert_false(result["ok"])
	assert_eq(result["message"], "You have no seeds to plant.")
	assert_false(farm.get_plot(PLOT).has_crop())


func test_unwatered_crops_do_not_grow() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, pipweed)
	for i in 5:
		farm.advance_day()
	assert_eq(farm.get_plot(PLOT).crop.days_grown, 0)
	assert_false(farm.is_mature(PLOT))


func test_day_by_day_growth_to_maturity() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, pipweed)  # Day 1: plant
	assert_true(farm.water(PLOT))
	assert_false(farm.water(PLOT), "already watered today")
	assert_eq(FarmActions.next_action(farm, PLOT), FarmActions.Action.INSPECT)
	var summary := farm.advance_day()  # sleep → Day 2
	assert_eq(summary["grown"], 1)
	var crop := farm.get_plot(PLOT).crop
	assert_eq(crop.days_grown, 1, "Day 2: grew")
	assert_false(farm.get_plot(PLOT).watered, "soil dries overnight")
	assert_eq(FarmActions.next_action(farm, PLOT), FarmActions.Action.WATER)
	farm.water(PLOT)
	farm.advance_day()  # Day 3
	farm.water(PLOT)
	summary = farm.advance_day()  # Day 4
	assert_eq(summary["matured"], 1)
	assert_true(farm.is_mature(PLOT), "mature after %d watered days" % pipweed.growth_days)
	assert_eq(crop.get_stage(pipweed), pipweed.stage_count - 1)
	assert_eq(FarmActions.next_action(farm, PLOT), FarmActions.Action.HARVEST)


func test_growth_stages_advance() -> void:
	var crop := CropState.new(&"emberroot")
	var ember := ContentDB.get_crop(&"emberroot")
	var stages: Array[int] = []
	for day in ember.growth_days + 1:
		crop.days_grown = day
		stages.append(crop.get_stage(ember))
	assert_eq(stages[0], 0)
	assert_eq(stages[-1], ember.stage_count - 1)
	for i in range(1, stages.size()):
		assert_true(stages[i] >= stages[i - 1], "stages never go backwards")
	assert_lt(stages[-2], ember.stage_count - 1, "only mature crops show the last stage")


func test_harvest_removes_single_crop_and_fills_inventory() -> void:
	_select(&"pipweed_seed")
	_act()
	_act()
	for day in pipweed.growth_days:
		farm.water(PLOT)
		farm.advance_day()
	var result := _act()
	assert_eq(result["action"], FarmActions.Action.HARVEST)
	assert_true(result["ok"])
	assert_eq(result["message"], "Harvested 1 Pipweed.")
	assert_eq(player.inventory.count(&"pipweed"), pipweed.harvest_quantity)
	assert_false(farm.get_plot(PLOT).has_crop(), "crop removed")
	assert_true(farm.get_plot(PLOT).tilled, "soil stays tilled")
	assert_eq(FarmActions.next_action(farm, PLOT), FarmActions.Action.PLANT)


func test_regrowing_crop_stays_and_regrows() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, bluecap)
	for day in bluecap.growth_days:
		farm.water(PLOT)
		farm.advance_day()
	assert_eq(farm.harvest(PLOT), {"item_id": &"bluecap", "quantity": bluecap.harvest_quantity})
	assert_true(farm.get_plot(PLOT).has_crop(), "bluecap stays")
	assert_false(farm.is_mature(PLOT))
	for day in bluecap.regrow_days:
		farm.water(PLOT)
		farm.advance_day()
	assert_true(farm.is_mature(PLOT), "ready again after regrow_days")
	assert_eq(farm.get_plot(PLOT).crop.times_harvested, 1)


func test_harvest_needs_room_in_the_bag() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, pipweed)
	for day in pipweed.growth_days:
		farm.water(PLOT)
		farm.advance_day()
	for i in player.inventory.capacity:
		player.inventory.add(StringName("junk_%d" % i), 99)
	var result := _act()
	assert_false(result["ok"])
	assert_true(farm.is_mature(PLOT), "crop kept when the bag is full")


func test_immature_crop_cannot_be_harvested() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, pipweed)
	assert_eq(farm.harvest(PLOT), {})


func test_inspect_reports_days_left() -> void:
	farm.till(PLOT)
	farm.plant(PLOT, pipweed)
	farm.water(PLOT)
	var result := _act()
	assert_eq(result["action"], FarmActions.Action.INSPECT)
	assert_eq(result["message"], "Pipweed — watered today. Ready in 3 more watered days.")


func test_prompts_follow_the_plot_state() -> void:
	_select(&"emberroot_seed")
	assert_eq(FarmActions.prompt_for(farm, player, PLOT), "Till")
	farm.till(PLOT)
	assert_eq(FarmActions.prompt_for(farm, player, PLOT), "Plant Emberroot Seeds")
	farm.plant(PLOT, ContentDB.get_crop(&"emberroot"))
	assert_eq(FarmActions.prompt_for(farm, player, PLOT), "Water")


func test_many_plots_are_independent() -> void:
	farm.till(&"a")
	farm.till(&"b")
	farm.plant(&"a", pipweed)
	farm.plant(&"b", pipweed)
	farm.water(&"a")
	farm.advance_day()
	assert_eq(farm.get_plot(&"a").crop.days_grown, 1)
	assert_eq(farm.get_plot(&"b").crop.days_grown, 0)


func test_farm_save_round_trip() -> void:
	farm.till(&"a")
	farm.plant(&"a", pipweed)
	farm.water(&"a")
	farm.advance_day()
	farm.water(&"a")
	farm.till(&"b")
	farm.ensure_plot(&"c")
	var restored := FarmState.new(ContentDB)
	restored.load_save_data(JSON.parse_string(JSON.stringify(farm.to_save_data())))
	assert_eq(restored.get_plot_ids().size(), 3)
	var a := restored.get_plot(&"a")
	assert_true(a.tilled)
	assert_true(a.watered)
	assert_eq(a.crop.crop_id, &"pipweed")
	assert_eq(a.crop.days_grown, 1)
	assert_true(restored.get_plot(&"b").tilled)
	assert_false(restored.get_plot(&"b").has_crop())
	assert_false(restored.get_plot(&"c").tilled)


func test_unknown_crop_in_save_is_dropped() -> void:
	farm.load_save_data({"plots": {"x": {"tilled": true, "watered": false, "crop": {"crop_id": "moonmelon", "days_grown": 2}}}})
	assert_true(farm.get_plot(&"x").tilled)
	assert_false(farm.get_plot(&"x").has_crop())


func test_shipping_sells_crops_only() -> void:
	player.inventory.add(&"pipweed", 3)
	player.inventory.add(&"emberroot", 2)
	var seeds := player.inventory.count(&"pipweed_seed")
	var money := player.money
	var result := Shipping.sell_all(player, ContentDB)
	var expected := 3 * ContentDB.get_item(&"pipweed").base_value + 2 * ContentDB.get_item(&"emberroot").base_value
	assert_eq(result["total"], expected)
	assert_eq(player.money, money + expected)
	assert_eq(player.inventory.count(&"pipweed"), 0)
	assert_eq(player.inventory.count(&"pipweed_seed"), seeds, "seeds are not sold")
	assert_eq(Shipping.sell_all(player, ContentDB)["total"], 0, "nothing left to sell")


func test_pricing() -> void:
	var item := ContentDB.get_item(&"emberroot")
	assert_eq(Pricing.sell_price(item, 3), item.base_value * 3)
	assert_eq(Pricing.sell_price(null, 3), 0)
	assert_eq(Pricing.sell_price(item, 0), 0)
