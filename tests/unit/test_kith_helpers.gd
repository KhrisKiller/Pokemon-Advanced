extends TestCase
## The watering helper: capability, Trust and the daily limit, applied through FarmState by the
## daily simulation (no input, no walking).

var config: KithConfig
var roster: KithRoster
var farm: FarmState
var pipweed: CropData


func before_each() -> void:
	config = load("res://data/config/kith_config.tres")
	roster = KithRoster.new(config, ContentDB)
	farm = FarmState.new(ContentDB)
	pipweed = ContentDB.get_crop(&"pipweed")


func _planted(count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for i in count:
		var id := StringName("farm:%d,23" % (10 + i))
		farm.till(id)
		farm.plant(id, pipweed)
		ids.append(id)
	return ids


func _watered(ids: Array[StringName]) -> int:
	var n := 0
	for id in ids:
		if farm.get_plot(id).watered:
			n += 1
	return n


func test_config_values() -> void:
	assert_eq(config.watering_daily_limit, 3)
	assert_eq(config.watering_min_trust, 25)


func test_farm_helper_action_waters_only_growing_dry_plots() -> void:
	var ids := _planted(2)
	farm.till(&"farm:30,23")  # tilled, empty: nothing to water
	farm.water(ids[1])  # already watered
	var watered := farm.apply_helper_action(KithHelpers.WATER, 5)
	assert_eq(watered, [ids[0]] as Array[StringName])
	assert_false(farm.get_plot(&"farm:30,23").watered)


func test_farm_helper_action_skips_mature_crops_and_respects_limit() -> void:
	var ids := _planted(4)
	var crop := farm.get_plot(ids[0]).crop
	crop.days_grown = pipweed.growth_days
	assert_true(farm.is_mature(ids[0]))
	var watered := farm.apply_helper_action(KithHelpers.WATER, 2)
	assert_eq(watered, [ids[1], ids[2]] as Array[StringName], "stable id order, limit 2")
	assert_eq(farm.apply_helper_action(KithHelpers.WATER, 0).size(), 0)


func test_unknown_farm_action_does_nothing() -> void:
	_planted(1)
	assert_eq(farm.apply_helper_action(&"weed", 3).size(), 0)


func test_requires_the_capability() -> void:
	var mole := roster.add_new(&"sprigmole")
	mole.trust = 100
	assert_false(KithHelpers.can_help(mole, roster.get_species(mole), KithHelpers.WATER, config))
	var ids := _planted(3)
	assert_eq(KithHelpers.run_daily(roster, farm, config).size(), 0)
	assert_eq(_watered(ids), 0)


func test_requires_trust() -> void:
	var rillet := roster.add_new(&"rillet")
	var ids := _planted(3)
	rillet.trust = config.watering_min_trust - 1
	assert_eq(KithHelpers.run_daily(roster, farm, config).size(), 0, "not trusted enough yet")
	assert_eq(_watered(ids), 0)
	rillet.trust = config.watering_min_trust
	var reports := KithHelpers.run_daily(roster, farm, config)
	assert_eq(reports.size(), 1)
	assert_eq(reports[0]["uid"], rillet.uid)
	assert_eq(_watered(ids), 3)


func test_daily_limit_is_per_kith_and_resets_each_day() -> void:
	var rillet := roster.add_new(&"rillet")
	rillet.trust = 50
	var ids := _planted(5)
	var reports := KithHelpers.run_daily(roster, farm, config)
	assert_eq((reports[0]["plots"] as Array).size(), 3)
	assert_eq(rillet.helper_actions_today, 3)
	assert_eq(_watered(ids), 3)
	assert_eq(KithHelpers.run_daily(roster, farm, config).size(), 0, "limit reached for today")
	assert_eq(_watered(ids), 3)
	farm.advance_day()  # soil dries
	roster.start_new_day()
	assert_eq(rillet.helper_actions_today, 0)
	KithHelpers.run_daily(roster, farm, config)
	assert_eq(_watered(ids), 3)


func test_two_waterers_share_the_work() -> void:
	var a := roster.add_new(&"rillet")
	var b := roster.add_new(&"rillet")
	a.trust = 30
	b.trust = 30
	var ids := _planted(5)
	var reports := KithHelpers.run_daily(roster, farm, config)
	assert_eq(reports.size(), 2)
	assert_eq(_watered(ids), 5)
	assert_eq(a.helper_actions_today + b.helper_actions_today, 5)


func test_nothing_to_water_is_not_reported() -> void:
	var rillet := roster.add_new(&"rillet")
	rillet.trust = 30
	assert_eq(KithHelpers.run_daily(roster, farm, config).size(), 0)
	assert_eq(rillet.helper_actions_today, 0)


func test_helper_watering_makes_crops_grow() -> void:
	var rillet := roster.add_new(&"rillet")
	rillet.trust = 30
	var ids := _planted(1)
	for day in pipweed.growth_days:
		roster.start_new_day()
		KithHelpers.run_daily(roster, farm, config)
		farm.advance_day()
	assert_true(farm.is_mature(ids[0]), "watered only by the kith, the crop matured")
