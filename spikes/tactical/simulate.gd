extends Node
## TACTICAL SPIKE — balance probe. Plays many battles with different Blue policies against the Red
## AI and prints statistics. It can't measure fun; it measures whether positioning and objectives
## change outcomes, how many choices a turn offers, and how long battles last.
##   godot --headless --path . res://spikes/tactical/simulate.tscn [-- --games=200 --scenario=hold]

const Rules := preload("res://spikes/tactical/spike_rules.gd")
const POLICIES := ["passive", "random", "greedy", "noisy", "cautious", "cautious_noisy", "anchor", "terrain_blind", "objective_blind"]
## Red makes a random legal move this often, so repeated games differ.
const RED_NOISE := 0.10
const BLUE_NOISE := 0.25


func _ready() -> void:
	var games := 200
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--scenario="):
			only = arg.trim_prefix("--scenario=")
	for scenario_id in ["v01", "hold", "rout", "escort"]:
		if only != "" and scenario_id != only:
			continue
		_report(scenario_id, {}, games)
		if Rules.SCENARIOS[scenario_id]["zoc"]:
			_report(scenario_id, {"zoc": false}, games, ["noisy", "cautious"], "  ZOC off")
	get_tree().quit()


func _report(scenario_id: String, overrides: Dictionary, games: int, policies: Array = POLICIES, label: String = "") -> void:
	var probe := Rules.new(scenario_id)
	if label == "":
		print("\n== %s — %d games per policy (Red AI with %d%% noise) ==" % [probe.scenario["name"], games, int(RED_NOISE * 100)])
		print("%-18s %6s %6s %13s %9s" % ["Blue policy", "win %", "turns", "min/med/max", "choices"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for policy: String in policies:
		var wins := 0
		var turns: Array[int] = []
		var choices := 0
		var activations := 0
		for g in games:
			var battle := Rules.new(scenario_id)
			if not overrides.is_empty():
				battle.load_scenario(scenario_id, overrides)
			var guard := 0
			while battle.outcome == Rules.Outcome.ONGOING and guard < 100:
				var team := battle.active_team
				for unit in battle.living(team):
					if battle.outcome != Rules.Outcome.ONGOING:
						break
					var all := _choices(battle, unit)
					if team == Rules.Team.BLUE:
						choices += all.size()
						activations += 1
						battle.execute_plan(unit, _pick(battle, unit, all, policy, rng))
					elif rng.randf() < RED_NOISE:
						battle.execute_plan(unit, all[rng.randi_range(0, all.size() - 1)])
					else:
						battle.execute_plan(unit, battle.plan(unit))
				battle.end_phase()
				guard += 1
			if battle.outcome == Rules.Outcome.VICTORY:
				wins += 1
			turns.append(battle.turn)
		turns.sort()
		var avg := 0.0
		for t in turns:
			avg += t
		avg /= turns.size()
		print("%-18s %5.0f%% %6.1f %13s %9.1f" % [policy + label, 100.0 * wins / games, avg,
				"%d/%d/%d" % [turns[0], turns[turns.size() / 2], turns[-1]], float(choices) / maxi(activations, 1)])


## Every legal (move, target) choice for a unit, including just moving/waiting.
func _choices(battle: Rules, unit: Rules.Unit) -> Array:
	var result: Array = []
	for cell: Vector2i in battle.reachable_cells(unit):
		result.append({"move": cell, "target": null})
		if unit.move_and_fire or cell == unit.cell:
			for target in battle.targets_from(unit, cell):
				result.append({"move": cell, "target": target})
	return result


func _pick(battle: Rules, unit: Rules.Unit, choices: Array, policy: String, rng: RandomNumberGenerator) -> Dictionary:
	match policy:
		"passive":
			return {"move": unit.cell, "target": null}
		"random":
			return choices[rng.randi_range(0, choices.size() - 1)]
		"noisy":
			if rng.randf() < BLUE_NOISE:
				return choices[rng.randi_range(0, choices.size() - 1)]
			return battle.plan(unit)
		"cautious":
			return battle.plan(unit, {"caution": true})
		"cautious_noisy":
			if rng.randf() < BLUE_NOISE:
				return choices[rng.randi_range(0, choices.size() - 1)]
			return battle.plan(unit, {"caution": true})
		"anchor":
			# Hold only: the unit nearest the objective parks on it; everyone else plays greedy.
			if battle.objective_type == "hold" and unit == _anchor_unit(battle):
				var reach := battle.reachable_cells(unit)
				var goal: Vector2i = battle.objective_cells[0]
				var move: Vector2i = goal if reach.has(goal) else battle.plan(unit)["move"]
				if unit.cell == goal:
					move = goal
				for enemy in battle.targets_from(unit, move):
					return {"move": move, "target": enemy}
				return {"move": move, "target": null}
			return battle.plan(unit)
		"terrain_blind":
			return battle.plan(unit, {"terrain": false})
		"objective_blind":
			return battle.plan(unit, {"objective": false})
		_:
			return battle.plan(unit)


func _anchor_unit(battle: Rules) -> Rules.Unit:
	var best: Rules.Unit = null
	for u in battle.living(Rules.Team.BLUE):
		if u.move_class == "air":
			continue
		if best == null or Rules.distance(u.cell, battle.objective_cells[0]) < Rules.distance(best.cell, battle.objective_cells[0]):
			best = u
	return best
