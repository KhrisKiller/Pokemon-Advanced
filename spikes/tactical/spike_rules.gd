extends RefCounted
## TACTICAL SPIKE — throwaway rules for evaluating grid combat. NOT production code.
## Deliberately has no class_name (nothing leaks into the game's global namespace) and uses no
## autoloads. Everything the spike needs lives in spikes/tactical/.
##
## Scenario "Hold the crossing": Blue defends the objective tile west of the bridge.
## Victory: survive TURN_LIMIT turns, or rout every Red unit.
## Defeat: a Red unit ends its turn on the objective, or every Blue unit is routed.

enum Team { BLUE, RED }
enum Terrain { PLAIN, ROAD, FOREST, HILL, WATER, FORD, BRIDGE }
enum Outcome { ONGOING, VICTORY, DEFEAT }

const TURN_LIMIT := 8
const MAX_HP := 10
## Damage = attack × DAMAGE_SCALE × (hp / MAX_HP) − defence, then reduced by terrain.
## Tuned 2.0 → 1.5 after the first playthrough: at 2.0 a Brute one-shot the Skimmer.
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

## ASCII map: . plain  = road  F forest  H hill  ~ water  f ford  B bridge
const MAP := [
	".FF..~.F..",
	".F...~..H.",
	"H...F~F...",
	"...==B===.",
	"..F..~..F.",
	".H...~.H..",
	"...F.~....",
	".....f.F..",
]
const OBJECTIVE := Vector2i(3, 3)

## Unit archetypes (spike-only placeholders, not kith).
const ARCHETYPES := {
	"bulwark": {"name": "Bulwark", "move_class": "heavy", "move": 3, "attack": 5, "defense": 3, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"skimmer": {"name": "Skimmer", "move_class": "air", "move": 5, "attack": 4, "defense": 1, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"brute": {"name": "Brute", "move_class": "foot", "move": 4, "attack": 6, "defense": 2, "min_range": 1, "max_range": 1, "move_and_fire": true},
	"slinger": {"name": "Slinger", "move_class": "foot", "move": 3, "attack": 5, "defense": 1, "min_range": 2, "max_range": 3, "move_and_fire": false},
}

## Starting line-up: [archetype, team, cell]
const LINEUP := [
	["bulwark", Team.BLUE, Vector2i(4, 3)],
	["skimmer", Team.BLUE, Vector2i(2, 5)],
	["brute", Team.RED, Vector2i(8, 3)],
	["slinger", Team.RED, Vector2i(9, 5)],
]


class Unit:
	extends RefCounted
	var id: int
	var archetype: String
	var name: String
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


var width: int
var height: int
var terrain: Array = []  # [y][x] → Terrain
var units: Array[Unit] = []
var turn: int = 1
var active_team: int = Team.BLUE
var outcome: int = Outcome.ONGOING
var log_lines: PackedStringArray = []


func _init() -> void:
	setup()


func setup(lineup: Array = LINEUP) -> void:
	height = MAP.size()
	width = String(MAP[0]).length()
	terrain.clear()
	for row: String in MAP:
		var line: Array = []
		for ch in row:
			line.append({".": Terrain.PLAIN, "=": Terrain.ROAD, "F": Terrain.FOREST, "H": Terrain.HILL,
				"~": Terrain.WATER, "f": Terrain.FORD, "B": Terrain.BRIDGE}[ch])
		terrain.append(line)
	units.clear()
	var next_id := 0
	for entry: Array in lineup:
		var u := Unit.new()
		var a: Dictionary = ARCHETYPES[entry[0]]
		u.id = next_id
		next_id += 1
		u.archetype = entry[0]
		u.name = a["name"]
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


## Dijkstra over move costs. Enemies block; allies can be passed through but not stopped on.
## Returns cell → cost for every cell the unit can end its move on (including its own cell).
func reachable_cells(unit: Unit) -> Dictionary:
	var best := {unit.cell: 0}
	var frontier: Array = [[0, unit.cell]]
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var current: Array = frontier.pop_front()
		var cost: int = current[0]
		var cell: Vector2i = current[1]
		if cost > int(best.get(cell, INF_COST)):
			continue
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


## Damage the attacker would deal. Weaker (damaged) units hit weaker; terrain protects.
func predict_damage(attacker: Unit, attacker_hp: int, defender: Unit, defender_cell: Vector2i) -> int:
	var raw := attacker.attack * DAMAGE_SCALE * float(attacker_hp) / MAX_HP - defender.defense
	var reduced := raw * (1.0 - terrain_defense(defender, defender_cell))
	return maxi(1, roundi(reduced))


# --- actions ---------------------------------------------------------------------------------

func move_unit(unit: Unit, to_cell: Vector2i) -> bool:
	if unit.has_moved or unit.has_acted or not reachable_cells(unit).has(to_cell):
		return false
	unit.changed_cell = to_cell != unit.cell
	unit.cell = to_cell
	unit.has_moved = true
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


## Ends the active team's phase. Red ending on the objective loses the game for Blue.
func end_phase() -> void:
	if outcome != Outcome.ONGOING:
		return
	if active_team == Team.RED:
		for u in living(Team.RED):
			if u.cell == OBJECTIVE:
				outcome = Outcome.DEFEAT
				_log("Red holds the crossing. Defeat.")
				return
		if turn >= TURN_LIMIT:
			outcome = Outcome.VICTORY
			_log("The crossing held for %d turns. Victory!" % TURN_LIMIT)
			return
		turn += 1
	active_team = Team.RED if active_team == Team.BLUE else Team.BLUE
	for u in living(active_team):
		u.has_moved = false
		u.changed_cell = false
		u.has_acted = false


func _check_outcome() -> void:
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
## Greedy utility: take the objective if reachable; otherwise the best trade (damage dealt minus
## half the counter taken, bonus for routing); otherwise advance toward the objective (Red) or
## toward the nearest enemy (Blue bot). Artillery that can't move-and-fire shoots from where it is.
func plan(unit: Unit) -> Dictionary:
	var options := reachable_cells(unit)
	var objective_goal := unit.team == Team.RED
	if objective_goal and options.has(OBJECTIVE):
		return {"move": OBJECTIVE, "target": null}
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
			score += terrain_defense(unit, cell) * 2.0
			if score > best_score:
				best_score = score
				best = {"move": cell, "target": target}
	if best["target"] != null:
		return best
	# No attack: advance.
	var goal := OBJECTIVE
	if not objective_goal:
		var nearest: Unit = null
		for enemy in living(Team.RED):
			if nearest == null or distance(unit.cell, enemy.cell) < distance(unit.cell, nearest.cell):
				nearest = enemy
		if nearest != null:
			goal = nearest.cell
	var best_cell := unit.cell
	var best_distance := distance(unit.cell, goal) * 10 - int(terrain_defense(unit, unit.cell) * 10)
	for cell: Vector2i in options:
		# Artillery keeps its distance: stop at max range of the goal instead of walking into melee.
		var d := distance(cell, goal)
		if unit.min_range > 1:
			d = absi(d - unit.max_range)
		var value := d * 10 - int(terrain_defense(unit, cell) * 10)
		if value < best_distance:
			best_distance = value
			best_cell = cell
	return {"move": best_cell, "target": null}


## Runs a whole phase for `team` with the greedy AI (used for Red, and for Blue in simulations).
func run_ai_phase(team: int) -> void:
	for unit in living(team):
		if outcome != Outcome.ONGOING:
			return
		execute_plan(unit, plan(unit))


func execute_plan(unit: Unit, action: Dictionary) -> void:
	if action["move"] != unit.cell:
		move_unit(unit, action["move"])
	var target: Unit = action["target"]
	if target != null and target.is_alive() and in_attack_range(unit, unit.cell, target.cell):
		attack(unit, target)
	else:
		wait(unit)
