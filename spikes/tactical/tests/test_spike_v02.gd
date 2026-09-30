extends TestCase
## Tactical spike v0.2: scenarios, zone of control, threat map, escort and rout outcomes.

const Rules := preload("res://spikes/tactical/spike_rules.gd")


func _unit(rules: Rules, archetype: String, team: int = -1) -> Rules.Unit:
	for u in rules.units:
		if u.archetype == archetype and (team == -1 or u.team == team):
			return u
	return null


func test_v02_scenarios_are_3v3_on_10x8() -> void:
	for id in ["hold", "rout", "escort"]:
		var rules := Rules.new(id)
		assert_eq(rules.width, 10, id)
		assert_eq(rules.height, 8, id)
		assert_eq(rules.living(Rules.Team.BLUE).size(), 3, id)
		assert_eq(rules.living(Rules.Team.RED).size(), 3, id)
		var roles := {}
		for u in rules.living(Rules.Team.BLUE):
			roles[u.role] = true
		assert_gt(roles.size(), 1, "%s has distinct roles" % id)
		assert_true(rules.zone_of_control, id)


func test_default_is_still_the_v01_baseline() -> void:
	var rules := Rules.new()
	assert_eq(rules.scenario_id, "v01")
	assert_false(rules.zone_of_control)
	assert_eq(rules.units.size(), 4)


func test_zone_of_control_stops_ground_units() -> void:
	var rules := Rules.new("rout")
	var bulwark := _unit(rules, "bulwark", Rules.Team.BLUE)
	var enemy := _unit(rules, "bulwark", Rules.Team.RED)
	bulwark.cell = Vector2i(2, 4)
	enemy.cell = Vector2i(4, 4)  # (3,4) is next to the enemy
	var with_zoc := rules.reachable_cells(bulwark)
	assert_true(with_zoc.has(Vector2i(3, 4)), "can step up to the enemy")
	assert_false(with_zoc.has(Vector2i(4, 3)), "can't slip past it: (3,4)/(4,3) route is engaged")
	rules.zone_of_control = false
	var without_zoc := rules.reachable_cells(bulwark)
	assert_true(without_zoc.has(Vector2i(4, 3)), "without ZOC it walks around")
	assert_gt(without_zoc.size(), with_zoc.size())


func test_flyers_ignore_zone_of_control() -> void:
	var rules := Rules.new("rout")
	var skimmer := _unit(rules, "skimmer", Rules.Team.BLUE)
	var enemy := _unit(rules, "bulwark", Rules.Team.RED)
	skimmer.cell = Vector2i(2, 4)
	enemy.cell = Vector2i(4, 4)
	var with_zoc := rules.reachable_cells(skimmer)
	rules.zone_of_control = false
	assert_eq(with_zoc.size(), rules.reachable_cells(skimmer).size())


func test_threat_map_counts_attackers() -> void:
	var rules := Rules.new("rout")
	var threat := rules.threat_map(Rules.Team.RED)
	assert_gt(threat.size(), 0)
	var slinger := _unit(rules, "slinger", Rules.Team.RED)
	assert_true(threat.has(slinger.cell + Vector2i(-2, 0)), "artillery threatens at range 2")
	assert_false(threat.has(Vector2i(0, 0)) and threat.get(Vector2i(0, 0), 0) > 3, "no cell has more attackers than units")


func test_escort_victory_when_courier_reaches_exit() -> void:
	var rules := Rules.new("escort")
	var courier := rules.get_vip()
	assert_not_null(courier)
	courier.cell = Vector2i(8, 4)
	assert_true(rules.move_unit(courier, Vector2i(9, 4)))
	assert_eq(rules.outcome, Rules.Outcome.VICTORY)


func test_escort_defeat_when_courier_falls() -> void:
	var rules := Rules.new("escort")
	var courier := rules.get_vip()
	var brute := _unit(rules, "brute")
	courier.hp = 1
	brute.cell = courier.cell + Vector2i.RIGHT
	rules.attack(brute, courier)
	assert_eq(rules.outcome, Rules.Outcome.DEFEAT)


func test_rout_timeout_is_defeat_but_hold_timeout_is_victory() -> void:
	for pair in [["rout", Rules.Outcome.DEFEAT], ["hold", Rules.Outcome.VICTORY]]:
		var rules := Rules.new(pair[0])
		for i in rules.turn_limit * 2:
			rules.end_phase()
		assert_eq(rules.outcome, pair[1], pair[0])


func test_red_ai_goes_for_the_courier() -> void:
	var rules := Rules.new("escort")
	var courier := rules.get_vip()
	var raider := _unit(rules, "raider")
	var bulwark := _unit(rules, "bulwark", Rules.Team.BLUE)
	courier.cell = Vector2i(4, 4)
	bulwark.cell = Vector2i(5, 6)
	raider.cell = Vector2i(6, 4)
	rules.active_team = Rules.Team.RED
	var plan := rules.plan(raider)
	assert_eq(plan["target"], courier, "the Courier is the priority target")


func test_courier_takes_a_winning_step() -> void:
	var rules := Rules.new("escort")
	var courier := rules.get_vip()
	courier.cell = Vector2i(7, 4)
	for u in rules.living(Rules.Team.RED):
		u.cell = Vector2i(0, 7 - u.id % 2) if u.id % 2 == 0 else Vector2i(1, 0)
	assert_true(rules.objective_cells.has(rules.plan(courier)["move"]))


func test_every_plan_style_returns_legal_moves() -> void:
	for id in ["hold", "rout", "escort"]:
		var rules := Rules.new(id)
		for style in [{}, {"caution": true}, {"terrain": false}, {"objective": false}]:
			for u in rules.living(Rules.Team.BLUE):
				var plan := rules.plan(u, style)
				assert_true(rules.reachable_cells(u).has(plan["move"]), "%s %s legal move" % [id, u.name])


func test_ai_vs_ai_battles_end_within_the_turn_limit() -> void:
	for id in ["hold", "rout", "escort"]:
		for style in [{}, {"caution": true}]:
			var battle := Rules.new(id)
			var guard := 0
			while battle.outcome == Rules.Outcome.ONGOING and guard < 100:
				battle.run_ai_phase(battle.active_team, style if battle.active_team == Rules.Team.BLUE else {})
				battle.end_phase()
				guard += 1
			assert_ne(battle.outcome, Rules.Outcome.ONGOING, id)
			assert_true(battle.turn <= battle.turn_limit, id)
