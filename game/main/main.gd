class_name Main
extends Node
## Entry scene. Loads the start map, spawns the player, binds the HUD, and owns the
## day-transition flow (sleep or curfew → next morning).
##
## Also the save provider for the "player" section (current map, position, facing). On start it
## continues from the save slot if one exists; it auto-saves at the end of every day transition.
##
## The day transition is the single place where end-of-day work happens. Later phases add, in
## this order: crop growth, world tick, NPC schedule reset — all before the auto-save
## (see TECHNICAL_DESIGN.md §6.1).

const TRANSITION_MODAL := &"day_transition"
const REASON_SLEPT := &"slept"
const REASON_EXHAUSTED := &"exhausted"

@export var start_map: PackedScene
@export var player_scene: PackedScene
@export var start_spawn: StringName = &"Default"
## Seconds for each half of the fade.
@export var fade_duration: float = 0.6
@export var save_slot: int = 1
## Continue from `save_slot` on start if a save exists.
@export var load_save_on_start: bool = true

var current_map: WorldMap
var player: Player
var _transitioning := false

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	load_map(start_map, start_spawn)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	Clock.curfew_reached.connect(_on_curfew_reached)
	# Main is the composition root of a play session, so it decides what gets saved.
	# Sections load in this order: time, world, then the player (which may change the map).
	for provider: Object in [Clock, WorldState, self]:
		SaveService.register(provider)
	if load_save_on_start and SaveService.has_save(save_slot):
		SaveService.load_game(save_slot)


func _exit_tree() -> void:
	for provider: Object in [Clock, WorldState, self]:
		SaveService.unregister(provider)


func load_map(map_scene: PackedScene, spawn_id: StringName) -> void:
	if current_map != null:
		current_map.queue_free()
	current_map = map_scene.instantiate() as WorldMap
	world.add_child(current_map)
	if player == null:
		player = player_scene.instantiate() as Player
		current_map.add_entity(player)
		hud.bind_player(player)
	else:
		player.reparent(current_map.entities)
	player.global_position = current_map.get_spawn_position(spawn_id)
	current_map.apply_camera_limits(player.camera)
	player.camera.reset_smoothing()


func is_transitioning() -> bool:
	return _transitioning


## Fades out, advances to the next morning, fades in, shows a wake-up message.
func run_day_transition(reason: StringName) -> void:
	if _transitioning:
		return
	_transitioning = true
	Clock.request_pause(TRANSITION_MODAL)
	EventBus.modal_opened.emit(TRANSITION_MODAL)
	await hud.fade_out(fade_duration)

	Clock.end_day()
	# Future hooks, in order: farming growth, world tick, NPC schedules — then the auto-save.
	if reason == REASON_EXHAUSTED:
		player.global_position = current_map.get_spawn_position(start_spawn)
		player.camera.reset_smoothing()
	player.set_facing(Vector2.DOWN)
	var saved := SaveService.save_game(save_slot) == OK

	await hud.fade_in(fade_duration)
	Clock.release_pause(TRANSITION_MODAL)
	EventBus.modal_closed.emit(TRANSITION_MODAL)
	_transitioning = false
	EventBus.day_transition_finished.emit(reason)
	EventBus.dialogue_requested.emit(_wake_up_lines(reason, saved))


func _wake_up_lines(reason: StringName, saved: bool) -> PackedStringArray:
	var lines := PackedStringArray()
	if reason == REASON_EXHAUSTED:
		lines.append("You collapsed from exhaustion and somehow made it home.")
	else:
		lines.append("You slept well.")
	lines.append("It's %s." % Clock.time.format_date())
	if saved:
		lines.append("(Game saved.)")
	return lines


func _on_sleep_requested(_source: Node) -> void:
	run_day_transition(REASON_SLEPT)


func _on_curfew_reached() -> void:
	run_day_transition(REASON_EXHAUSTED)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or _transitioning:
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

func get_save_id() -> StringName:
	return &"player"


## Player section history: v1 stored `facing` as [x, y] floats; v2 stores a name ("left").
const PLAYER_SECTION_VERSION := 2
const FACING_NAMES := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}


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
	if data.is_empty() or map_id != current_map.map_id:
		if not data.is_empty():
			push_warning("Saved map '%s' is not available; starting at the default spawn." % map_id)
		player.global_position = current_map.get_spawn_position(start_spawn)
		player.set_facing(Vector2.DOWN)
	else:
		player.global_position = _to_vector2(data.get("position"), current_map.get_spawn_position(start_spawn))
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
