class_name Main
extends Node
## Entry scene. Loads the start map, spawns the player, binds the HUD, and owns the
## day-transition flow (sleep or curfew → next morning).
##
## The day transition is the single place where end-of-day work happens. Later phases add,
## in this order: crop growth, world tick, NPC schedule reset, auto-save (see TECHNICAL_DESIGN.md §6.1).

const TRANSITION_MODAL := &"day_transition"
const REASON_SLEPT := &"slept"
const REASON_EXHAUSTED := &"exhausted"

@export var start_map: PackedScene
@export var player_scene: PackedScene
@export var start_spawn: StringName = &"Default"
## Seconds for each half of the fade.
@export var fade_duration: float = 0.6

var current_map: WorldMap
var player: Player
var _transitioning := false

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	load_map(start_map, start_spawn)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	Clock.curfew_reached.connect(_on_curfew_reached)


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
	# Future hooks, in order: farming growth, world tick, NPC schedules, auto-save.
	if reason == REASON_EXHAUSTED:
		player.global_position = current_map.get_spawn_position(start_spawn)
		player.camera.reset_smoothing()
	player.set_facing(Vector2.DOWN)

	await hud.fade_in(fade_duration)
	Clock.release_pause(TRANSITION_MODAL)
	EventBus.modal_closed.emit(TRANSITION_MODAL)
	_transitioning = false
	EventBus.day_transition_finished.emit(reason)
	EventBus.dialogue_requested.emit(_wake_up_lines(reason))


func _wake_up_lines(reason: StringName) -> PackedStringArray:
	var today := "It's %s." % Clock.time.format_date()
	if reason == REASON_EXHAUSTED:
		return PackedStringArray(["You collapsed from exhaustion and somehow made it home.", today])
	return PackedStringArray(["You slept well.", today])


func _on_sleep_requested(_source: Node) -> void:
	run_day_transition(REASON_SLEPT)


func _on_curfew_reached() -> void:
	run_day_transition(REASON_EXHAUSTED)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_skip_hour") and not _transitioning:
		Clock.advance_minutes(60)
		get_viewport().set_input_as_handled()
