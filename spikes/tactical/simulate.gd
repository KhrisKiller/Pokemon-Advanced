extends Node
## TACTICAL SPIKE — balance probe. Plays many battles with different Blue policies against the
## Red AI and prints outcome statistics. It can't measure fun; it shows whether decisions matter.
##   godot --headless --path . res://spikes/tactical/simulate.tscn [-- --games=200]

const Rules := preload("res://spikes/tactical/spike_rules.gd")


func _ready() -> void:
	var games := 200
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	print("Tactical spike simulation — %d games per policy (Red = greedy AI)\n" % games)
	print("%-22s %8s %8s %10s %12s" % ["Blue policy", "win %", "avg turn", "routs", "avg options"])
	for policy in ["passive", "random", "greedy", "greedy_noisy"]:
		var wins := 0
		var turns := 0
		var routs := 0
		var option_sum := 0
		var option_count := 0
		var n := 1 if policy == "greedy" or policy == "passive" else games
		for g in n:
			var battle := Rules.new()
			var guard := 0
			while battle.outcome == Rules.Outcome.ONGOING and guard < 100:
				if battle.active_team == Rules.Team.BLUE:
					for unit in battle.living(Rules.Team.BLUE):
						if battle.outcome != Rules.Outcome.ONGOING:
							break
						var choices := _choices(battle, unit)
						option_sum += choices.size()
						option_count += 1
						battle.execute_plan(unit, _pick(battle, unit, choices, policy, rng))
				else:
					battle.run_ai_phase(Rules.Team.RED)
				battle.end_phase()
				guard += 1
			if battle.outcome == Rules.Outcome.VICTORY:
				wins += 1
				if battle.living(Rules.Team.RED).is_empty():
					routs += 1
			turns += battle.turn
		print("%-22s %7.0f%% %8.1f %10d %12.1f" % [policy + " (%d)" % n, 100.0 * wins / n, float(turns) / n, routs,
				float(option_sum) / maxi(option_count, 1)])
	print("\n'avg options' = distinct (move, target) choices per Blue activation.")
	get_tree().quit()


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
		"greedy_noisy":
			if rng.randf() < 0.25:
				return choices[rng.randi_range(0, choices.size() - 1)]
			return battle.plan(unit)
		_:
			return battle.plan(unit)
