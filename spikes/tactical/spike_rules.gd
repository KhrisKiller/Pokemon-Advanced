extends RefCounted
## TACTICAL SPIKE — throwaway rules for evaluating grid combat. NOT production code.
## Deliberately has no class_name (nothing leaks into the game's global namespace) and uses no
## autoloads. Everything the spike needs lives in spikes/tactical/.
##
## v0.2: scenarios are data (map, line-up, objective, turn limit, damage scale, zone of control).
##   "v01"    — the v0.1 baseline (2v2 hold, no ZOC). Default, so the v0.1 tests still apply.
##   "hold"   — 3v3: keep Red off the gold tile for TURN_LIMIT turns (or rout them).
##   "rout"   — 3v3: rout Red before the turn limit.
##   "escort" — 3v3: get the Courier to the east exit (reach) and keep it alive (protect).

enum Team { BLUE, RED }
enum Terrain { PLAIN, ROAD, FOREST, HILL, WATER, FORD, BRIDGE }
enum Outcome { ONGOING, VICTORY, DEFEAT }

## v0.1 constants, kept for the baseline scenario and its tests.
const TURN_LIMIT := 8
const MAX_HP := 10
## Damage = attack × scale × (hp / MAX_HP) − defence, then reduced by terrain.
## v0.1 tuned 2.0 → 1.5 (a Brute one-shot the Skimmer at 2.0). v0.2 scenarios set their own scale.
const DAMAGE_SCALE := 1.5
const INF_COST := 999

## Per terrain: move cost by movement class (INF_COST = impassable), defence bonus (0–1).
const TERRAIN_INFO := {
	Terrain.PLAIN: {"name": "Plain", "cost": {"foot": 1, "heavy": 1, "air": 1}, "defense": 0.0},
	Terrain.ROAD: {"name": "Road", "cost": {"foot": 1, "heavy": 1, "air": 1}, "defense": 0.0},
	Terrain.FOREST: {"name": "Forest", "cost": {"foot": 2, "heavy": 3, "air": 1}, "defense": 0.25},
	Terrain.HILL: {"name": "Hill", "cost": {"foot": 2, "heavy": 2, "air": 1}, "defense": 0.35},
	Terrain.WATER: {"name": "Deep water", "cost": {"foot": INF_COST, "heavy": INF_COST, "air": 1}, "defense": 0.0},
	Terrain.FORD: {"name": "Ford", "cost": {"foot": 3, "heavy": 3, "air": 1}, "defense": -0.15},
	Terrain.BRIDGE: {"name": "Bridge", "cost": {"foot": 1, "heavy": 1, "air": 1}, "defense": 0.0},
}
const TERRAIN_CHARS := {".": Terrain.PLAIN, "=": Terrain.ROAD, "F": Terrain.FOREST, "H": Terrain.HILL,
	"~": Terrain.WATER, "f": Terrain.FORD, "B": Terrain.BRIDGE}

## ASCII maps: . plain  = road  F forest  H hill  ~ water  f ford  B bridge
const MAP := [  # "River crossing" (v0.1 and hold)
	".FF..~.F..",
	".F...~..H.",
	"H...F~F...",
	"...==B===.",
	"..F..~..F.",
	".H...~.H..",
	"...F.~....",
	".....f.F..",
]
const FIELD_MAP := [  # open ground with cover (rout)
	"..F....F..",
	".H...H..F.",
	"....F.....",
	"..H....H..",
	".....F..H.",
	"F..H......",
	"..F...F.H.",
	"....H...F.",
]
const PASS_MAP := [  # road east over a guarded bridge, or the slow southern ford (escort)
	"FF..F~.FFF",
	"F...H~..HF",
	"..F..~F...",
	"====.B====",
	"..F..~..=.",
	".H..F~.H=.",
	"...F.f....",
	"F....~.FFF",
]
const OBJECTIVE := Vector2i(3, 3)

## Unit archetypes (spike-only placeholders, not kith). `role` is informational.
const ARCHETYPES := {
	"bulwark": {"name": "Bulwark", "role": "vanguard", "move_class": "heavy", "move": 3, "attack": 5, "defense": 3, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"skimmer": {"name": "Skimmer", "role": "flyer", "move_class": "air", "move": 5, "attack": 4, "defense": 1, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"brute": {"name": "Brute", "role": "vanguard", "move_class": "foot", "move": 4, "attack": 6, "defense": 2, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"slinger": {"name": "Slinger", "role": "artillery", "move_class": "foot", "move": 3, "attack": 5, "defense": 1, "min_range": 2, "max_range": 3, "move_and_fire": false},
	"raider": {"name": "Raider", "role": "skirmisher", "move_class": "foot", "move": 5, "attack": 4, "defense": 1, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"courier": {"name": "Courier", "role": "vip", "move_class": "foot", "move": 4, "attack": 2, "defense": 1, "min_range": 1, "max_range": 1, "move_and_fire": true},
}

## Starting line-up of the v0.1 baseline: [archetype, team, cell]
const LINEUP := [
	["bulwark", Team.BLUE, Vector2i(4, 3)],
	["skimmer", Team.BLUE, Vector2i(2, 5)],
	["brute", Team.RED, Vector2i(8, 3)],
	["slinger", Team.RED, Vector2i(9, 5)],
]

const SCENARIOS := {
	"v01": {
		"name": "v0.1 baseline — Hold the crossing (2v2)", "objective": "hold", "map": MAP, "lineup": LINEUP,
		"objective_cells": [Vector2i(3, 3)], "turn_limit": 8, "damage_scale": 1.5, "zoc": false,
		"blue_guards": false,
	},
	"hold": {
		"name": "Hold the crossing (3v3)", "objective": "hold", "map": MAP,
		"lineup": [
			["bulwark", Team.BLUE, Vector2i(4, 3)], ["skimmer", Team.BLUE, Vector2i(2, 5)], ["slinger", Team.BLUE, Vector2i(2, 2)],
			["brute", Team.RED, Vector2i(8, 3)], ["raider", Team.RED, Vector2i(8, 6)], ["slinger", Team.RED, Vector2i(9, 1)],
		],
		"objective_cells": [Vector2i(3, 3)], "turn_limit": 8, "damage_scale": 1.0, "zoc": true, "blue_guards": true,
	},
	"rout": {
		"name": "Rout (3v3, mirrored armies)", "objective": "rout", "map": FIELD_MAP,
		"lineup": [
			["bulwark", Team.BLUE, Vector2i(1, 3)], ["skimmer", Team.BLUE, Vector2i(1, 5)], ["slinger", Team.BLUE, Vector2i(0, 2)],
			["bulwark", Team.RED, Vector2i(8, 4)], ["skimmer", Team.RED, Vector2i(8, 2)], ["slinger", Team.RED, Vector2i(9, 5)],
		],
		"objective_cells": [], "turn_limit": 12, "damage_scale": 1.0, "zoc": true, "blue_guards": false,
	},
	"escort": {
		"name": "Escort the Courier (3v3)", "objective": "escort", "map": PASS_MAP,
		"lineup": [
			["courier", Team.BLUE, Vector2i(0, 3)], ["bulwark", Team.BLUE, Vector2i(1, 4)], ["skimmer", Team.BLUE, Vector2i(0, 5)],
			["brute", Team.RED, Vector2i(7, 3)], ["raider", Team.RED, Vector2i(6, 6)], ["slinger", Team.RED, Vector2i(8, 1)],
		],
		"objective_cells": [Vector2i(9, 3), Vector2i(9, 4)], "turn_limit": 10, "damage_scale": 1.0, "zoc": true,
		"blue_guards": false,
	},
}


class Unit:
	extends RefCounted
	var id: int
	var archetype: String
	var name: String
	var role: String
	var team: int
	var cell: Vector2i
	var hp: int = 10
	var move: int
	var move_class: String
	var attack: int
	var defense: int
	var min_range: int
	var max_range: int
	var move_and_fire: bool
	var has_moved := false  # used its move this turn (even if it stayed put)
	var changed_cell := false  # actually moved this turn (blocks fire for non move-and-fire units)
	var has_acted := false

	func is_alive() -> bool:
		return hp > 0

	func can_counter() -> bool:
		return min_range == 1


var scenario_id: String
var scenario: Dictionary
var objective_type: String
var objective_cells: Array[Vector2i] = []
var turn_limit: int = TURN_LIMIT
var damage_scale: float = DAMAGE_SCALE
var zone_of_control: bool = false
var width: int
var height: int
var terrain: Array = []  # [y][x] → Terrain
var units: Array[Unit] = []
var turn: int = 1
var active_team: int = Team.BLUE
var outcome: int = Outcome.ONGOING
var log_lines: PackedStringArray = []


func _init(id: String = "v01") -> void:
	load_scenario(id)


## Loads a scenario by id. `overrides` may replace any scenario key (used by the simulation).
func load_scenario(id: String, overrides: Dictionary = {}) -> void:
	scenario_id = id
	scenario = SCENARIOS[id].duplicate()
	scenario.merge(overrides, true)
	objective_type = scenario["objective"]
	objective_cells.assign(scenario["objective_cells"])
	turn_limit = scenario["turn_limit"]
	damage_scale = scenario["damage_scale"]
	zone_of_control = scenario["zoc"]
	_build_map(scenario["map"])
	setup(scenario["lineup"])


## v0.1 API: resets units and the turn counter on the current map.
func setup(lineup: Array = LINEUP) -> void:
	units.clear()
	var next_id := 0
	for entry: Array in lineup:
		var u := Unit.new()
		var a: Dictionary = ARCHETYPES[entry[0]]
		u.id = next_id
		next_id += 1
		u.archetype = entry[0]
		u.name = a["name"]
		u.role = a["role"]
		u.team = entry[1]
		u.cell = entry[2]
		u.move = a["move"]
		u.move_class = a["move_class"]
		u.attack = a["attack"]
		u.defense = a["defense"]
		u.min_range = a["min_range"]
		u.max_range = a["max_range"]
		u.move_and_fire = a["move_and_fire"]
		units.append(u)
	turn = 1
	active_team = Team.BLUE
	outcome = Outcome.ONGOING
	log_lines.clear()


func _build_map(rows: Array) -> void:
	height = rows.size()
	width = String(rows[0]).length()
	terrain.clear()
	for row: String in rows:
		var line: Array = []
		for ch in row:
			line.append(TERRAIN_CHARS[ch])
		terrain.append(line)


# --- queries ---------------------------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> int:
	return terrain[cell.y][cell.x]


func move_cost(unit: Unit, cell: Vector2i) -> int:
	return TERRAIN_INFO[terrain_at(cell)]["cost"][unit.move_class]


func terrain_defense(unit: Unit, cell: Vector2i) -> float:
	if unit.move_class == "air":
		return 0.0  # flyers get no cover
	return TERRAIN_INFO[terrain_at(cell)]["defense"]


func unit_at(cell: Vector2i) -> Unit:
	for u in units:
		if u.is_alive() and u.cell == cell:
			return u
	return null


func living(team: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.is_alive() and u.team == team:
			result.append(u)
	return result


func get_vip() -> Unit:
	for u in units:
		if u.role == "vip":
			return u
	return null


## True if a living enemy of `unit` stands next to `cell`.
func is_engaged(unit: Unit, cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var other := unit_at(cell + offset)
		if other != null and other.team != unit.team:
			return true
	return false


## Dijkstra over move costs. Enemies block; allies can be passed through but not stopped on.
## Zone of control (if enabled): a ground unit that enters a cell next to an enemy must stop there.
## Returns cell → cost for every cell the unit can end its move on (including its own cell).
func reachable_cells(unit: Unit) -> Dictionary:
	var best := {unit.cell: 0}
	var frontier: Array = [[0, unit.cell]]
	var uses_zoc := zone_of_control and unit.move_class != "air"
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var current: Array = frontier.pop_front()
		var cost: int = current[0]
		var cell: Vector2i = current[1]
		if cost > int(best.get(cell, INF_COST)):
			continue
		if uses_zoc and cell != unit.cell and is_engaged(unit, cell):
			continue  # stopped by an adjacent enemy
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not in_bounds(next):
				continue
			var occupant := unit_at(next)
			if occupant != null and occupant.team != unit.team:
				continue
			var next_cost := cost + move_cost(unit, next)
			if next_cost > unit.move or next_cost >= int(best.get(next, INF_COST)):
				continue
			best[next] = next_cost
			frontier.append([next_cost, next])
	var result := {}
	for cell: Vector2i in best:
		var occupant := unit_at(cell)
		if occupant == null or occupant == unit:
			result[cell] = best[cell]
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func in_attack_range(attacker: Unit, from_cell: Vector2i, target_cell: Vector2i) -> bool:
	var d := distance(from_cell, target_cell)
	return d >= attacker.min_range and d <= attacker.max_range


func targets_from(attacker: Unit, from_cell: Vector2i) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.is_alive() and u.team != attacker.team and in_attack_range(attacker, from_cell, u.cell):
			result.append(u)
	return result


## How many units of `team` could attack each cell on their next turn (the "danger zone").
func threat_map(team: int) -> Dictionary:
	var threat := {}
	for u in living(team):
		var attack_cells := {}
		var origins: Array = reachable_cells(u).keys() if u.move_and_fire else [u.cell]
		for origin: Vector2i in origins:
			for y in range(-u.max_range, u.max_range + 1):
				for x in range(-u.max_range, u.max_range + 1):
					var cell: Vector2i = origin + Vector2i(x, y)
					if in_bounds(cell) and in_attack_range(u, origin, cell):
						attack_cells[cell] = true
		for cell: Vector2i in attack_cells:
			threat[cell] = int(threat.get(cell, 0)) + 1
	return threat


## Damage the attacker would deal. Weaker (damaged) units hit weaker; terrain protects.
func predict_damage(attacker: Unit, attacker_hp: int, defender: Unit, defender_cell: Vector2i) -> int:
	var raw := attacker.attack * damage_scale * float(attacker_hp) / MAX_HP - defender.defense
	var reduced := raw * (1.0 - terrain_defense(defender, defender_cell))
	return maxi(1, roundi(reduced))


# --- actions ---------------------------------------------------------------------------------

func move_unit(unit: Unit, to_cell: Vector2i) -> bool:
	if unit.has_moved or unit.has_acted or not reachable_cells(unit).has(to_cell):
		return false
	unit.changed_cell = to_cell != unit.cell
	unit.cell = to_cell
	unit.has_moved = true
	_check_outcome()
	return true


func can_attack_now(unit: Unit) -> bool:
	if unit.has_acted:
		return false
	return unit.move_and_fire or not unit.changed_cell


## Resolves an attack plus counterattack. Returns a summary dictionary.
func attack(attacker: Unit, defender: Unit) -> Dictionary:
	var result := {"damage": 0, "counter": 0, "defender_routed": false, "attacker_routed": false}
	if not can_attack_now(attacker) or not in_attack_range(attacker, attacker.cell, defender.cell):
		return result
	var damage := predict_damage(attacker, attacker.hp, defender, defender.cell)
	defender.hp = maxi(0, defender.hp - damage)
	result["damage"] = damage
	_log("%s %s hits %s for %d." % [_team_name(attacker.team), attacker.name, defender.name, damage])
	if defender.is_alive():
		if defender.can_counter() and in_attack_range(defender, defender.cell, attacker.cell):
			var counter := predict_damage(defender, defender.hp, attacker, attacker.cell)
			attacker.hp = maxi(0, attacker.hp - counter)
			result["counter"] = counter
			_log("  %s counters for %d." % [defender.name, counter])
			if not attacker.is_alive():
				result["attacker_routed"] = true
				_log("  %s is routed!" % attacker.name)
	else:
		result["defender_routed"] = true
		_log("  %s is routed!" % defender.name)
	attacker.has_acted = true
	attacker.has_moved = true
	_check_outcome()
	return result


func wait(unit: Unit) -> void:
	unit.has_moved = true
	unit.has_acted = true


func all_acted(team: int) -> bool:
	for u in living(team):
		if not u.has_acted:
			return false
	return true


## Ends the active team's phase. At the end of Red's phase: Red on a hold tile = defeat; reaching
## the turn limit = victory (hold) or defeat (rout, escort).
func end_phase() -> void:
	if outcome != Outcome.ONGOING:
		return
	if active_team == Team.RED:
		if objective_type == "hold":
			for u in living(Team.RED):
				if objective_cells.has(u.cell):
					outcome = Outcome.DEFEAT
					_log("Red holds the crossing. Defeat.")
					return
		if turn >= turn_limit:
			if objective_type == "hold":
				outcome = Outcome.VICTORY
				_log("The crossing held for %d turns. Victory!" % turn_limit)
			else:
				outcome = Outcome.DEFEAT
				_log("Out of time. Defeat.")
			return
		turn += 1
	active_team = Team.RED if active_team == Team.BLUE else Team.BLUE
	for u in living(active_team):
		u.has_moved = false
		u.changed_cell = false
		u.has_acted = false


func _check_outcome() -> void:
	if outcome != Outcome.ONGOING:
		return
	if objective_type == "escort":
		var vip := get_vip()
		if vip != null and not vip.is_alive():
			outcome = Outcome.DEFEAT
			_log("The Courier fell. Defeat.")
			return
		if vip != null and objective_cells.has(vip.cell):
			outcome = Outcome.VICTORY
			_log("The Courier got through. Victory!")
			return
	if living(Team.RED).is_empty():
		outcome = Outcome.VICTORY
		_log("Red is routed. Victory!")
	elif living(Team.BLUE).is_empty():
		outcome = Outcome.DEFEAT
		_log("Blue is routed. Defeat.")


func _log(line: String) -> void:
	log_lines.append(line)


static func _team_name(team: int) -> String:
	return "Blue" if team == Team.BLUE else "Red"


# --- AI --------------------------------------------------------------------------------------

## Plans one unit's activation: {"move": cell, "target": Unit or null}.
## Greedy utility, objective-aware:
##   1. a winning move (Red onto a hold tile; the Courier onto an exit);
##   2. the best trade: damage dealt minus half the counter taken, bonus for routing and for hitting
##      the Courier (Red), plus terrain cover;
##   3. otherwise advance toward a goal chosen by the objective (see _advance_goal).
## `style` (for the simulation's comparison bots): {"terrain": false} ignores cover,
## {"objective": false} plays every scenario as a plain rout, {"caution": true} reads the enemy's
## danger zone: it avoids ending a move where enemies can strike next turn unless the trade is
## worth it, and waits for the enemy to come (positional play).
func plan(unit: Unit, style: Dictionary = {}) -> Dictionary:
	var use_terrain: bool = style.get("terrain", true)
	var use_objective: bool = style.get("objective", true)
	var caution: bool = style.get("caution", false)
	var options := reachable_cells(unit)
	var danger := threat_map(Team.RED if unit.team == Team.BLUE else Team.BLUE) if caution else {}
	if use_objective:
		var winning := _winning_move(unit, options)
		if winning != Vector2i(-1, -1):
			return {"move": winning, "target": null}
	if unit.role == "vip" and use_objective:
		return {"move": _courier_step(unit, options, use_terrain), "target": null}
	var best := {"move": unit.cell, "target": null}
	var best_score := -INF
	for cell: Vector2i in options:
		var fire_ok := unit.move_and_fire or cell == unit.cell
		if not fire_ok:
			continue
		for target in targets_from(unit, cell):
			var dealt := predict_damage(unit, unit.hp, target, target.cell)
			var score := float(mini(dealt, target.hp))
			if dealt >= target.hp:
				score += 6.0
			elif target.can_counter() and distance(cell, target.cell) <= target.max_range:
				score -= 0.5 * predict_damage(target, target.hp - dealt, unit, cell)
			if use_objective and target.role == "vip":
				score += 8.0
			if use_terrain:
				score += terrain_defense(unit, cell) * 2.0
			if caution:
				score -= 1.5 * int(danger.get(cell, 0))
			if score > best_score:
				best_score = score
				best = {"move": cell, "target": target}
	if best["target"] != null and (not caution or best_score > 0.0):
		return best
	var goal := _advance_goal(unit, use_objective)
	var best_cell := unit.cell
	var best_value := _cell_value(unit, unit.cell, goal, use_terrain) + (int(danger.get(unit.cell, 0)) * 15 if caution else 0)
	for cell: Vector2i in options:
		var value := _cell_value(unit, cell, goal, use_terrain)
		if caution:
			value += int(danger.get(cell, 0)) * 15
		if value < best_value:
			best_value = value
			best_cell = cell
	return {"move": best_cell, "target": null}


func _winning_move(unit: Unit, options: Dictionary) -> Vector2i:
	if objective_type == "hold" and unit.team == Team.RED:
		for cell in objective_cells:
			if options.has(cell):
				return cell
	if objective_type == "escort" and unit.role == "vip":
		for cell in objective_cells:
			if options.has(cell):
				return cell
	return Vector2i(-1, -1)


## Where a unit heads when it can't attack.
func _advance_goal(unit: Unit, use_objective: bool) -> Vector2i:
	var enemy_team := Team.RED if unit.team == Team.BLUE else Team.BLUE
	if use_objective:
		if objective_type == "hold" and (unit.team == Team.RED or scenario.get("blue_guards", false)):
			return objective_cells[0]
		if objective_type == "escort":
			var vip := get_vip()
			if vip != null and vip.is_alive():
				if unit.team == Team.RED:
					return vip.cell  # intercept
				return _nearest(vip.cell, living(enemy_team)).cell if not living(enemy_team).is_empty() else vip.cell
	var anchor := unit.cell
	var target := _nearest(anchor, living(enemy_team))
	return target.cell if target != null else unit.cell


func _nearest(from: Vector2i, candidates: Array[Unit]) -> Unit:
	var nearest: Unit = null
	for u in candidates:
		if nearest == null or distance(from, u.cell) < distance(from, nearest.cell):
			nearest = u
	return nearest


func _cell_value(unit: Unit, cell: Vector2i, goal: Vector2i, use_terrain: bool) -> int:
	# Artillery keeps its distance: aims to stand at max range of the goal.
	var d := distance(cell, goal)
	if unit.min_range > 1:
		d = absi(d - unit.max_range)
	return d * 10 - (int(terrain_defense(unit, cell) * 10) if use_terrain else 0)


## The Courier steps toward the nearest exit, avoiding cells enemies can hit next turn.
func _courier_step(unit: Unit, options: Dictionary, use_terrain: bool) -> Vector2i:
	var threat := threat_map(Team.RED)
	var best_cell := unit.cell
	var best_value := INF
	for cell: Vector2i in options:
		var to_exit := INF_COST
		for exit_cell in objective_cells:
			to_exit = mini(to_exit, distance(cell, exit_cell))
		var value := to_exit * 10.0 + int(threat.get(cell, 0)) * 25.0
		if use_terrain:
			value -= terrain_defense(unit, cell) * 10.0
		if value < best_value:
			best_value = value
			best_cell = cell
	return best_cell


## Runs a whole phase for `team` with the greedy AI (used for Red, and for Blue in simulations).
func run_ai_phase(team: int, style: Dictionary = {}) -> void:
	for unit in living(team):
		if outcome != Outcome.ONGOING:
			return
		execute_plan(unit, plan(unit, style))


func execute_plan(unit: Unit, action: Dictionary) -> void:
	if action["move"] != unit.cell:
		move_unit(unit, action["move"])
	if outcome != Outcome.ONGOING:
		return
	var target: Unit = action["target"]
	if target != null and target.is_alive() and in_attack_range(unit, unit.cell, target.cell):
		attack(unit, target)
	else:
		wait(unit)
