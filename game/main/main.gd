class_name Main
extends Node
## Entry scene and composition root of a play session.
##
## - Loads maps **by id** from the MapCatalog and keeps one persistent Player node that moves
##   between them (state such as facing is preserved; maps hold no player logic).
## - Owns the two screen flows: the map transition (MapTransition → fade → swap map → fade) and
##   the day transition (sleep or curfew → next morning → auto-save).
## - Save provider for the "player" section (map id, position, facing). On start it continues
##   from `save_slot` if a save exists.
## - Owns the GameSession (player belongings, farm) and injects it into map objects that need it.
##
## The day transition is the single place where end-of-day work happens. Later phases add, in
## this order: crop growth, world tick, NPC schedule reset — all before the auto-save
## (see TECHNICAL_DESIGN.md §6.1).

const TRANSITION_MODAL := &"day_transition"
const TRAVEL_MODAL := &"map_transition"
const REASON_SLEPT := &"slept"
const REASON_EXHAUSTED := &"exhausted"

@export var map_catalog: MapCatalog
@export var player_scene: PackedScene
## Starting belongings (money, seeds) for a new game.
@export var new_game: NewGameConfig
## Where a new game begins.
@export var start_map_id: StringName = &"farm"
@export var start_spawn: StringName = &"Default"
## Where the player wakes up after collapsing (curfew).
@export var home_map_id: StringName = &"farm"
@export var home_spawn_id: StringName = &"Default"
## Seconds for each half of the fade.
@export var fade_duration: float = 0.6
@export var save_slot: int = 1
## Continue from `save_slot` on start if a save exists.
@export var load_save_on_start: bool = true

var current_map: WorldMap
var player: Player
var session: GameSession
var _transitioning := false

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	session = GameSession.new(new_game, ContentDB)
	hud.bind_player_state(session.player)
	change_map(start_map_id, start_spawn)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.map_transition_requested.connect(_on_map_transition_requested)
	Clock.curfew_reached.connect(_on_curfew_reached)
	# Main decides what a play session saves. Sections load in this order: time, world, then the
	# player (which may change the map).
	for provider: Object in _save_providers():
		SaveService.register(provider)
	if load_save_on_start and SaveService.has_save(save_slot):
		SaveService.load_game(save_slot)


func _exit_tree() -> void:
	for provider: Object in _save_providers():
		SaveService.unregister(provider)


## Load order: time, world, player belongings, farm, then the player (which may change the map).
func _save_providers() -> Array[Object]:
	var providers: Array[Object] = [Clock, WorldState]
	providers.append_array(session.get_save_providers())
	providers.append(self)
	return providers


# --- maps ------------------------------------------------------------------------------------

## Immediately replaces the current map and places the player at `spawn_id`.
## Returns false (and keeps the current map) if `map_id` is unknown.
func change_map(map_id: StringName, spawn_id: StringName = &"Default") -> bool:
	var new_map := map_catalog.instantiate_map(map_id) if map_catalog != null else null
	if new_map == null:
		push_warning("Unknown map '%s'." % map_id)
		return false
	if new_map.map_id != map_id:
		push_warning("Map scene for '%s' declares map_id '%s'." % [map_id, new_map.map_id])
	if current_map != null:
		# Detach right away (not just queue_free) so the old map's triggers can't fire again.
		current_map.entities.remove_child(player)
		world.remove_child(current_map)
		current_map.queue_free()
	current_map = new_map
	world.add_child(current_map)
	var first_spawn := player == null
	if first_spawn:
		player = player_scene.instantiate() as Player
	# Maps share the world origin: place the player before it enters the new map's physics.
	player.position = current_map.get_spawn_position(spawn_id)
	player.velocity = Vector2.ZERO
	current_map.add_entity(player)
	if first_spawn:
		hud.bind_player(player)  # after entering the tree, so the player's @onready nodes exist
	current_map.apply_camera_limits(player.camera)
	player.camera.reset_smoothing()
	for node in get_tree().get_nodes_in_group(GameSession.SESSION_AWARE_GROUP):
		if current_map.is_ancestor_of(node):
			node.bind_session(session)
	WorldState.discover_location(map_id)
	EventBus.map_changed.emit(map_id)
	return true


func is_transitioning() -> bool:
	return _transitioning


## Fades out, changes map, fades in. Ignored while another transition runs.
func travel_to(map_id: StringName, spawn_id: StringName) -> void:
	if _transitioning:
		return
	if map_catalog == null or not map_catalog.has_map(map_id):
		push_warning("Cannot travel to unknown map '%s'." % map_id)
		return
	_begin_transition(TRAVEL_MODAL)
	await hud.fade_out(fade_duration)
	change_map(map_id, spawn_id)
	await hud.fade_in(fade_duration)
	_end_transition(TRAVEL_MODAL)
	hud.show_location(current_map.display_name)


func _begin_transition(modal_id: StringName) -> void:
	_transitioning = true
	Clock.request_pause(modal_id)
	EventBus.modal_opened.emit(modal_id)


func _end_transition(modal_id: StringName) -> void:
	Clock.release_pause(modal_id)
	EventBus.modal_closed.emit(modal_id)
	_transitioning = false


func _on_map_transition_requested(map_id: StringName, spawn_id: StringName, source: Node) -> void:
	# Only triggers of the map the player is actually in count (ignores stale/removed maps).
	if source == null or not is_instance_valid(source) or not current_map.is_ancestor_of(source):
		return
	# Requests arrive from physics callbacks (body_entered); swapping maps there is not allowed.
	travel_to.call_deferred(map_id, spawn_id)


# --- day transition --------------------------------------------------------------------------

## Fades out, advances to the next morning, auto-saves, fades in, shows a wake-up message.
func run_day_transition(reason: StringName) -> void:
	if _transitioning:
		return
	_begin_transition(TRANSITION_MODAL)
	await hud.fade_out(fade_duration)

	Clock.end_day()
	# Daily tick, in order: farming growth, (later: world tick, NPC schedules) — then the auto-save.
	var growth := session.farm.advance_day()
	if reason == REASON_EXHAUSTED:
		if current_map.map_id != home_map_id and map_catalog.has_map(home_map_id):
			change_map(home_map_id, home_spawn_id)
		else:
			player.global_position = current_map.get_spawn_position(home_spawn_id)
			player.camera.reset_smoothing()
	player.set_facing(Vector2.DOWN)
	var saved := SaveService.save_game(save_slot) == OK

	await hud.fade_in(fade_duration)
	_end_transition(TRANSITION_MODAL)
	EventBus.day_transition_finished.emit(reason)
	EventBus.dialogue_requested.emit(_wake_up_lines(reason, saved, growth))


func _wake_up_lines(reason: StringName, saved: bool, growth: Dictionary = {}) -> PackedStringArray:
	var lines := PackedStringArray()
	if reason == REASON_EXHAUSTED:
		lines.append("You collapsed from exhaustion and somehow made it home.")
	else:
		lines.append("You slept well.")
	lines.append("It's %s." % Clock.time.format_date())
	var matured := int(growth.get("matured", 0))
	if matured > 0:
		lines.append("%d crop%s ready to harvest!" % [matured, " is" if matured == 1 else "s are"])
	elif int(growth.get("grown", 0)) > 0:
		lines.append("Your watered crops grew overnight.")
	if saved:
		lines.append("(Game saved.)")
	return lines


func _on_sleep_requested(_source: Node) -> void:
	run_day_transition(REASON_SLEPT)


func _on_curfew_reached() -> void:
	run_day_transition(REASON_EXHAUSTED)


# --- debug -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed(&"cycle_seed") and player.is_control_enabled():
		session.player.cycle_seed()
		get_viewport().set_input_as_handled()
		return
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_skip_hour"):
		Clock.advance_minutes(60)
	elif event.is_action_pressed(&"debug_quicksave"):
		var ok := SaveService.save_game(save_slot) == OK
		EventBus.dialogue_requested.emit(PackedStringArray(["(Debug) Game saved." if ok else "(Debug) Save failed."]))
	elif event.is_action_pressed(&"debug_quickload"):
		if SaveService.load_game(save_slot) != OK:
			EventBus.dialogue_requested.emit(PackedStringArray(["(Debug) No save to load."]))
	else:
		return
	get_viewport().set_input_as_handled()


# --- persistence (Saveable contract, section "player") ---------------------------------------

## Player section history: v1 stored `facing` as [x, y] floats; v2 stores a name ("left").
const PLAYER_SECTION_VERSION := 2
const FACING_NAMES := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}


func get_save_id() -> StringName:
	return &"player"


func to_save_data() -> Dictionary:
	return {
		"version": PLAYER_SECTION_VERSION,
		"map_id": String(current_map.map_id),
		"position": [player.global_position.x, player.global_position.y],
		"facing": _facing_to_name(player.facing),
	}


func get_save_summary() -> Dictionary:
	return {"location": current_map.display_name}


func load_save_data(data: Dictionary) -> void:
	var map_id := StringName(str(data.get("map_id", "")))
	if data.is_empty() or map_catalog == null or not map_catalog.has_map(map_id):
		if not data.is_empty():
			push_warning("Saved map '%s' is not available; starting a new game position." % map_id)
		change_map(start_map_id, start_spawn)
		player.set_facing(Vector2.DOWN)
		return
	if map_id != current_map.map_id:
		change_map(map_id)
	player.global_position = _to_vector2(data.get("position"), current_map.get_spawn_position())
	player.set_facing(_read_facing(data))
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()


static func _read_facing(data: Dictionary) -> Vector2:
	var raw: Variant = data.get("facing")
	if int(data.get("version", 1)) <= 1:
		return _to_vector2(raw, Vector2.DOWN).round()  # v1: [x, y]
	return FACING_NAMES.get(str(raw), Vector2.DOWN)


static func _facing_to_name(facing: Vector2) -> String:
	for facing_name: String in FACING_NAMES:
		if FACING_NAMES[facing_name] == facing:
			return facing_name
	return "down"


static func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
