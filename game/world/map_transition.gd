class_name MapTransition
extends Area2D
## Trigger area that sends the player to another map. Holds only data (target map + spawn id);
## `Main` performs the transition. Needs a CollisionShape2D child. Physics layer 7 (`triggers`).

const LAYER_TRIGGERS := 1 << 6
const LAYER_PLAYER := 1 << 1

@export var target_map_id: StringName = &""
@export var target_spawn_id: StringName = &"Default"
@export var enabled: bool = true


func _init() -> void:
	collision_layer = LAYER_TRIGGERS
	collision_mask = LAYER_PLAYER
	monitoring = true
	monitorable = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if enabled and body is Player:
		EventBus.map_transition_requested.emit(target_map_id, target_spawn_id, self)
