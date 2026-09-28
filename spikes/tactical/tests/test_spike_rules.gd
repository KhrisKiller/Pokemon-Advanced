extends TestCase
## Rules of the isolated tactical spike. Run with:
##   godot --headless --path . res://tests/test_runner.tscn -- --dir=res://spikes/tactical/tests

const Rules := preload("res://spikes/tactical/spike_rules.gd")

var rules: Rules


func before_each() -> void:
	rules = Rules.new()


func _unit(archetype: String) -> Rules.Unit:
	for u in rules.units:
		if u.archetype == archetype:
			return u
	return null


func _place(archetype: String, cell: Vector2i) -> Rules.Unit:
	var u := _unit(archetype)
	u.cell = cell
	return u


func test_scenario_setup() -> void:
	assert_eq(rules.width, 10)
	assert_eq(rules.height, 8)
	assert_eq(rules.living(Rules.Team.BLUE).size(), 2)
	assert_eq(rules.living(Rules.Team.RED).size(), 2)
	assert_eq(rules.terrain_at(Rules.OBJECTIVE), Rules.Terrain.ROAD)
	assert_eq(rules.outcome, Rules.Outcome.ONGOING)


func test_foot_units_cannot_enter_deep_water_but_flyers_can() -> void:
	var brute := _place("brute", Vector2i(6, 1))
	assert_false(rules.reachable_cells(brute).has(Vector2i(5, 1)), "water blocks foot units")
	var skimmer := _place("skimmer", Vector2i(4, 1))
	assert_true(rules.reachable_cells(skimmer).has(Vector2i(5, 1)), "flyers cross water")


func test_forest_costs_more_for_heavy_units() -> void:
	var bulwark := _place("bulwark", Vector2i(4, 1))  # forest at (4, 2) costs 3 for heavy
	var cells := rules.reachable_cells(bulwark)
	assert_eq(cells.get(Vector2i(4, 2)), 3)
	assert_false(cells.has(Vector2i(4, 3)), "no move left after the forest")


func test_enemies_block_paths_allies_do_not() -> void:
	var brute := _place("brute", Vector2i(7, 3))
	_place("slinger", Vector2i(6, 3))  # ally in front
	var cells := rules.reachable_cells(brute)
	assert_true(cells.has(Vector2i(5, 3)), "can pass through an ally onto the bridge")
	assert_false(cells.has(Vector2i(6, 3)), "cannot stop on an ally")
	_place("bulwark", Vector2i(5, 3))  # enemy on the bridge
	cells = rules.reachable_cells(brute)
	assert_false(cells.has(Vector2i(4, 3)), "enemy on the bridge blocks the crossing")


func test_damage_scales_with_attacker_health_and_terrain() -> void:
	var brute := _unit("brute")
	var bulwark := _unit("bulwark")
	var on_plain := rules.predict_damage(brute, 10, bulwark, Vector2i(0, 0))
	assert_eq(on_plain, 6, "6*1.5 - 3")
	assert_lt(rules.predict_damage(brute, 5, bulwark, Vector2i(0, 0)), on_plain, "damaged units hit weaker")
	assert_lt(rules.predict_damage(brute, 10, bulwark, Vector2i(0, 2)), on_plain, "hill protects")
	assert_gt(rules.predict_damage(brute, 10, bulwark, Vector2i(5, 7)), on_plain, "ford exposes")
	assert_eq(rules.predict_damage(brute, 1, bulwark, Vector2i(0, 2)), 1, "minimum 1 damage")


func test_flyers_get_no_terrain_cover() -> void:
	var skimmer := _unit("skimmer")
	assert_eq(rules.terrain_defense(skimmer, Vector2i(0, 2)), 0.0)


func test_melee_attack_triggers_counter() -> void:
	var brute := _place("brute", Vector2i(6, 3))
	var bulwark := _place("bulwark", Vector2i(5, 3))
	var result := rules.attack(brute, bulwark)
	assert_gt(result["damage"], 0)
	assert_gt(result["counter"], 0, "adjacent melee defender counters")
	assert_lt(brute.hp, 10)
	assert_true(brute.has_acted)


func test_ranged_attack_gets_no_counter_and_needs_range() -> void:
	var slinger := _place("slinger", Vector2i(7, 3))
	var bulwark := _place("bulwark", Vector2i(5, 3))
	var result := rules.attack(slinger, bulwark)
	assert_gt(result["damage"], 0)
	assert_eq(result["counter"], 0)
	var adjacent := _place("skimmer", Vector2i(7, 4))
	slinger.has_acted = false
	assert_false(rules.in_attack_range(slinger, slinger.cell, adjacent.cell), "min range 2")


func test_slinger_cannot_move_and_fire() -> void:
	_place("brute", Vector2i(8, 6))
	var slinger := _place("slinger", Vector2i(9, 3))
	rules.active_team = Rules.Team.RED
	assert_true(rules.move_unit(slinger, Vector2i(8, 3)))
	assert_false(rules.can_attack_now(slinger))
	var brute := _unit("brute")
	brute.cell = Vector2i(8, 5)
	assert_true(rules.move_unit(brute, Vector2i(7, 5)))
	assert_true(rules.can_attack_now(brute), "melee units can move and attack")


func test_units_move_once_per_turn() -> void:
	var skimmer := _unit("skimmer")
	assert_true(rules.move_unit(skimmer, skimmer.cell + Vector2i.RIGHT))
	assert_false(rules.move_unit(skimmer, skimmer.cell + Vector2i.RIGHT))


func test_routing_all_red_is_victory() -> void:
	for u in rules.living(Rules.Team.RED):
		u.hp = 1
	var brute := _unit("brute")
	var skimmer := _place("skimmer", brute.cell + Vector2i.LEFT)
	rules.attack(skimmer, brute)
	assert_eq(rules.outcome, Rules.Outcome.ONGOING)
	var slinger := _unit("slinger")
	var bulwark := _place("bulwark", slinger.cell + Vector2i.LEFT)
	rules.attack(bulwark, slinger)
	assert_eq(rules.outcome, Rules.Outcome.VICTORY)


func test_red_ending_turn_on_objective_is_defeat() -> void:
	rules.end_phase()  # Blue → Red
	_unit("brute").cell = Rules.OBJECTIVE
	rules.end_phase()  # Red ends
	assert_eq(rules.outcome, Rules.Outcome.DEFEAT)


func test_surviving_the_turn_limit_is_victory() -> void:
	for i in Rules.TURN_LIMIT * 2:
		rules.end_phase()
	assert_eq(rules.outcome, Rules.Outcome.VICTORY)
	assert_eq(rules.turn, Rules.TURN_LIMIT)


func test_end_phase_resets_the_next_team() -> void:
	rules.end_phase()
	assert_eq(rules.active_team, Rules.Team.RED)
	var brute := _unit("brute")
	brute.has_acted = true
	rules.end_phase()
	assert_eq(rules.turn, 2)
	rules.end_phase()
	assert_false(brute.has_acted)


func test_ai_takes_the_objective_when_reachable() -> void:
	var brute := _place("brute", Rules.OBJECTIVE + Vector2i(0, 2))
	_place("bulwark", Vector2i(0, 7))
	var plan := rules.plan(brute)
	assert_eq(plan["move"], Rules.OBJECTIVE)


func test_ai_prefers_the_objective_over_a_fight() -> void:
	var brute := _place("brute", Vector2i(7, 3))
	_place("skimmer", Vector2i(6, 1))
	_place("bulwark", Vector2i(0, 7))
	assert_eq(rules.plan(brute)["move"], Rules.OBJECTIVE)


func test_ai_attacks_when_it_can() -> void:
	var brute := _place("brute", Vector2i(8, 1))
	var skimmer := _place("skimmer", Vector2i(6, 1))
	_place("bulwark", Vector2i(0, 7))
	var plan := rules.plan(brute)
	assert_eq(plan["target"], skimmer)


func test_ai_vs_ai_battles_always_end() -> void:
	for i in 20:
		var battle := Rules.new()
		var guard := 0
		while battle.outcome == Rules.Outcome.ONGOING and guard < 100:
			battle.run_ai_phase(battle.active_team)
			battle.end_phase()
			guard += 1
		assert_ne(battle.outcome, Rules.Outcome.ONGOING, "battle %d ended" % i)
