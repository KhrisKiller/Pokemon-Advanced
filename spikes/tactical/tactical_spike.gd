extends Node2D
## TACTICAL SPIKE — playable view/controller for spike_rules.gd. NOT production code.
## Run: godot --path . res://spikes/tactical/tactical_spike.tscn
## Controls: mouse or arrows to move the cursor · Left click / Space / Enter to select & confirm ·
## Right click / Esc to cancel (after moving: wait) · Tab to end your turn · R to restart ·
## 1–4 to pick a scenario (v0.1 baseline, Hold, Rout, Escort) · V to show Red's danger zone.

const Rules := preload("res://spikes/tactical/spike_rules.gd")

enum State { SELECT, MOVE, TARGET, ENEMY, OVER }

const CELL := 32
const ORIGIN := Vector2(16, 52)
const PANEL_X := 352.0
const AI_STEP_SECONDS := 0.35

const TERRAIN_COLORS := {
	Rules.Terrain.PLAIN: Color("7fae5a"), Rules.Terrain.ROAD: Color("c8a46a"),
	Rules.Terrain.FOREST: Color("3f7a3a"), Rules.Terrain.HILL: Color("a58a5c"),
	Rules.Terrain.WATER: Color("3f7fbf"), Rules.Terrain.FORD: Color("78a8d0"),
	Rules.Terrain.BRIDGE: Color("8a5a32"),
}
const TEAM_COLORS := {Rules.Team.BLUE: Color("3b6fd8"), Rules.Team.RED: Color("d0463b")}

const SCENARIO_KEYS := {KEY_1: "v01", KEY_2: "hold", KEY_3: "rout", KEY_4: "escort"}
const OBJECTIVE_TEXT := {
	"hold": ["Win: survive %d turns or rout Red.", "Lose: Red ends a turn on the gold tile."],
	"rout": ["Win: rout every Red unit by turn %d.", "Lose: Blue is routed or time runs out."],
	"escort": ["Win: the Courier reaches a green exit (turn %d).", "Lose: the Courier falls or time runs out."],
}

var rules: Rules
var scenario_id := "hold"
var show_danger := false
var state: int = State.SELECT
var cursor := Vector2i(4, 3)
var selected: Rules.Unit = null
var reachable := {}
var target_cells: Array[Vector2i] = []
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	restart()


func restart() -> void:
	rules = Rules.new(scenario_id)
	state = State.SELECT
	selected = null
	reachable = {}
	target_cells.clear()
	rules.log_lines.append("%s. Keys 1–4 switch scenario." % rules.scenario["name"])
	queue_redraw()


# --- input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if rules.in_bounds(cell):
			cursor = cell
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and rules.in_bounds(cell):
			cursor = cell
			confirm()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move_cursor(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				_move_cursor(Vector2i.RIGHT)
			KEY_UP, KEY_W:
				_move_cursor(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_move_cursor(Vector2i.DOWN)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				confirm()
			KEY_ESCAPE:
				cancel()
			KEY_TAB:
				end_player_turn()
			KEY_R:
				restart()
			KEY_V:
				show_danger = not show_danger
				queue_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if state != State.ENEMY:
					scenario_id = SCENARIO_KEYS[event.keycode]
					restart()


func _move_cursor(offset: Vector2i) -> void:
	var next := cursor + offset
	if rules.in_bounds(next):
		cursor = next
		queue_redraw()


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - ORIGIN) / CELL
	return Vector2i(floori(local.x), floori(local.y))


# --- player flow -----------------------------------------------------------------------------

func confirm() -> void:
	match state:
		State.SELECT:
			var unit := rules.unit_at(cursor)
			if unit != null and unit.team == Rules.Team.BLUE and not unit.has_acted:
				selected = unit
				reachable = rules.reachable_cells(unit)
				state = State.MOVE
		State.MOVE:
			if reachable.has(cursor):
				rules.move_unit(selected, cursor)
				reachable = {}
				_enter_targeting()
		State.TARGET:
			var target := rules.unit_at(cursor)
			if target != null and target_cells.has(cursor):
				rules.attack(selected, target)
				_finish_unit()
			elif cursor == selected.cell:
				rules.wait(selected)
				_finish_unit()
	queue_redraw()


func cancel() -> void:
	match state:
		State.MOVE:
			selected = null
			reachable = {}
			state = State.SELECT
		State.TARGET:
			rules.wait(selected)
			_finish_unit()
	queue_redraw()


func _enter_targeting() -> void:
	target_cells.clear()
	if rules.can_attack_now(selected):
		for target in rules.targets_from(selected, selected.cell):
			target_cells.append(target.cell)
	if target_cells.is_empty():
		rules.wait(selected)
		_finish_unit()
	else:
		state = State.TARGET


func _finish_unit() -> void:
	selected = null
	target_cells.clear()
	state = State.SELECT
	if rules.outcome != Rules.Outcome.ONGOING:
		state = State.OVER
	elif rules.all_acted(Rules.Team.BLUE):
		end_player_turn()


func end_player_turn() -> void:
	if state == State.ENEMY or state == State.OVER:
		return
	selected = null
	reachable = {}
	target_cells.clear()
	rules.end_phase()
	_run_enemy_phase()


func _run_enemy_phase() -> void:
	state = State.ENEMY
	queue_redraw()
	for unit in rules.living(Rules.Team.RED):
		if rules.outcome != Rules.Outcome.ONGOING:
			break
		await get_tree().create_timer(AI_STEP_SECONDS).timeout
		var plan := rules.plan(unit)
		if plan["move"] != unit.cell:
			rules.move_unit(unit, plan["move"])
			queue_redraw()
			await get_tree().create_timer(AI_STEP_SECONDS).timeout
		var target: Rules.Unit = plan["target"]
		if target != null and target.is_alive() and rules.in_attack_range(unit, unit.cell, target.cell):
			rules.attack(unit, target)
		else:
			rules.wait(unit)
		queue_redraw()
	rules.end_phase()
	state = State.OVER if rules.outcome != Rules.Outcome.ONGOING else State.SELECT
	queue_redraw()


# --- drawing ---------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("1f2622"))
	_text(Vector2(16, 20), "TACTICAL SPIKE v0.2", 14, Color.WHITE)
	_text(Vector2(16, 38), "Prototype to evaluate grid combat. Not final art or rules.", 9, Color("a9b5ad"))
	for y in rules.height:
		for x in rules.width:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			draw_rect(rect, TERRAIN_COLORS[rules.terrain_at(cell)])
			draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)
			match rules.terrain_at(cell):
				Rules.Terrain.FOREST:
					draw_circle(rect.get_center(), 8, Color("2c5a2a"))
				Rules.Terrain.HILL:
					draw_colored_polygon(PackedVector2Array([rect.position + Vector2(6, 26), rect.position + Vector2(16, 8), rect.position + Vector2(26, 26)]), Color("8a7048"))
	var objective_color := Color("f2c14e") if rules.objective_type == "hold" else Color("7be07b")
	for cell in rules.objective_cells:
		draw_rect(_cell_rect(cell).grow(-2), objective_color, false, 3.0)
	if show_danger:
		var danger := rules.threat_map(Rules.Team.RED)
		for cell: Vector2i in danger:
			var rect := _cell_rect(cell).grow(-3)
			draw_line(rect.position, rect.end, Color(1, 0.3, 0.25, 0.8), 2.0)
			draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), Color(1, 0.3, 0.25, 0.8), 2.0)
			if int(danger[cell]) > 1:
				_text(rect.position + Vector2(1, 9), str(danger[cell]), 8, Color(1, 0.8, 0.75))
	for cell: Vector2i in reachable:
		draw_rect(_cell_rect(cell).grow(-1), Color(0.35, 0.6, 1.0, 0.45))
	for cell in target_cells:
		draw_rect(_cell_rect(cell).grow(-1), Color(1.0, 0.25, 0.2, 0.5))
	for unit in rules.units:
		if unit.is_alive():
			_draw_unit(unit)
	draw_rect(_cell_rect(cursor), Color.WHITE, false, 2.0)
	_draw_panel()
	if state == State.OVER:
		var won := rules.outcome == Rules.Outcome.VICTORY
		draw_rect(Rect2(ORIGIN + Vector2(40, 100), Vector2(240, 56)), Color(0, 0, 0, 0.8))
		_text(ORIGIN + Vector2(60, 128), "VICTORY" if won else "DEFEAT", 20, Color("f2c14e") if won else Color("ff6b5e"))
		_text(ORIGIN + Vector2(60, 146), "Press R to play again", 10, Color.WHITE)


func _draw_unit(unit: Rules.Unit) -> void:
	var center := _cell_rect(unit.cell).get_center()
	var color: Color = TEAM_COLORS[unit.team]
	var done := unit.team == rules.active_team and unit.has_acted
	if done:
		color = color.darkened(0.45)
	draw_circle(center, 12, color)
	draw_arc(center, 12, 0, TAU, 24, Color.WHITE if unit == selected else Color(0, 0, 0, 0.6), 2.0)
	if unit.role == "vip":
		draw_arc(center, 15, 0, TAU, 24, Color("f2c14e"), 2.0)
	_text(center + Vector2(-5, 4), unit.name.substr(0, 2), 10, Color.WHITE)
	draw_rect(Rect2(center + Vector2(4, 5), Vector2(12, 10)), Color(0, 0, 0, 0.75))
	_text(center + Vector2(6, 14), str(unit.hp), 9, Color.WHITE)


func _draw_panel() -> void:
	var y := 66.0
	var phase := "Your turn" if rules.active_team == Rules.Team.BLUE else "Red is moving…"
	if state == State.OVER:
		phase = "Battle over"
	_text(Vector2(PANEL_X, y - 16), rules.scenario["name"], 10, Color("f2c14e"))
	_text(Vector2(PANEL_X, y), "Turn %d / %d — %s" % [rules.turn, rules.turn_limit, phase], 11, Color.WHITE)
	var texts: Array = OBJECTIVE_TEXT[rules.objective_type]
	y += 16
	_text(Vector2(PANEL_X, y), String(texts[0]) % rules.turn_limit if texts[0].contains("%d") else texts[0], 9, Color("d8e0da"))
	y += 12
	_text(Vector2(PANEL_X, y), texts[1] + ("  ZOC on" if rules.zone_of_control else ""), 9, Color("d8e0da"))
	y += 20
	var t: Dictionary = Rules.TERRAIN_INFO[rules.terrain_at(cursor)]
	_text(Vector2(PANEL_X, y), "Tile: %s  (defence %+d%%)" % [t["name"], roundi(t["defense"] * 100)], 10, Color("f2e6c8"))
	y += 14
	var unit := rules.unit_at(cursor)
	if unit != null:
		var a: Dictionary = Rules.ARCHETYPES[unit.archetype]
		_text(Vector2(PANEL_X, y), "%s %s  HP %d  ATK %d  DEF %d" % [Rules._team_name(unit.team), unit.name, unit.hp, unit.attack, unit.defense], 10, Color("f2e6c8"))
		y += 12
		var rng := "range %d" % unit.max_range if unit.min_range == unit.max_range else "range %d–%d" % [unit.min_range, unit.max_range]
		_text(Vector2(PANEL_X, y), "move %d (%s), %s%s" % [unit.move, a["move_class"], rng, "" if unit.move_and_fire else ", can't move+fire"], 9, Color("c9d2cc"))
		if selected != null and unit.team != selected.team and state == State.TARGET:
			y += 12
			var dmg := rules.predict_damage(selected, selected.hp, unit, unit.cell)
			_text(Vector2(PANEL_X, y), "Forecast: deal %d" % dmg, 10, Color("ffb3a8"))
	y = 204.0
	_text(Vector2(PANEL_X, y), "Log", 10, Color("f2c14e"))
	var start := maxi(0, rules.log_lines.size() - 8)
	for i in range(start, rules.log_lines.size()):
		y += 12
		_text(Vector2(PANEL_X, y), rules.log_lines[i], 9, Color("d8e0da"))
	_text(Vector2(16, 336), "Click/Space: select, move, attack · Esc: cancel/wait · Tab: end turn · V: danger · 1–4: scenario · R: restart", 9, Color("a9b5ad"))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
