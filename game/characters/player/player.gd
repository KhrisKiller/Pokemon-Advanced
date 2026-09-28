class_name Player
extends CharacterBody2D
## The player's overworld controller: analog movement, 4-way facing, interaction, camera.
## The origin is at the character's feet (y-sort friendly).

signal facing_changed(facing: Vector2)

enum Frame { DOWN, UP, LEFT, RIGHT }

## Walking speed in pixels per second (16 px = 1 tile).
@export var walk_speed: float = 80.0
@export var acceleration: float = 900.0
@export var friction: float = 1400.0

var facing: Vector2 = Vector2.DOWN
## Modals currently open (message box, fades, menus). Input is ignored while any are open.
var _open_modals: Dictionary[StringName, bool] = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var probe: InteractionProbe = $InteractionProbe
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	EventBus.modal_opened.connect(_on_modal_opened)
	EventBus.modal_closed.connect(_on_modal_closed)
	_apply_facing()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if is_control_enabled():
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	step_movement(input, delta)


## Applies one physics step of movement for a given input direction. Public for tests.
func step_movement(input: Vector2, delta: float) -> void:
	var target := input.limit_length(1.0) * walk_speed
	var rate := acceleration if input != Vector2.ZERO else friction
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()
	if input != Vector2.ZERO:
		set_facing(facing_from_input(input, facing))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo() and is_control_enabled():
		if try_interact():
			get_viewport().set_input_as_handled()


## Uses the interactable in front of the player. Returns true if something was used.
func try_interact() -> bool:
	probe.refresh_target()
	var target := probe.current_target
	if target == null:
		return false
	target.interact(self)
	return true


func is_control_enabled() -> bool:
	return _open_modals.is_empty()


func set_facing(direction: Vector2) -> void:
	if direction == facing:
		return
	facing = direction
	_apply_facing()
	facing_changed.emit(facing)


func _apply_facing() -> void:
	probe.set_facing(facing)
	match facing:
		Vector2.UP:
			sprite.frame = Frame.UP
		Vector2.LEFT:
			sprite.frame = Frame.LEFT
		Vector2.RIGHT:
			sprite.frame = Frame.RIGHT
		_:
			sprite.frame = Frame.DOWN


## Converts analog input to one of the 4 cardinal directions. On an exact diagonal, keeps the
## current facing if it is one of the two components (avoids flicker when walking diagonally).
static func facing_from_input(input: Vector2, current: Vector2) -> Vector2:
	if input == Vector2.ZERO:
		return current
	var horizontal := Vector2.RIGHT if input.x > 0.0 else Vector2.LEFT
	var vertical := Vector2.DOWN if input.y > 0.0 else Vector2.UP
	if is_equal_approx(absf(input.x), absf(input.y)):
		if current == horizontal or current == vertical:
			return current
		return horizontal
	return horizontal if absf(input.x) > absf(input.y) else vertical


func _on_modal_opened(modal_id: StringName) -> void:
	_open_modals[modal_id] = true
	velocity = Vector2.ZERO


func _on_modal_closed(modal_id: StringName) -> void:
	_open_modals.erase(modal_id)
