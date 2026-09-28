class_name InteractionProbe
extends Area2D
## Sensor in front of an actor that picks the best Interactable to use.
##
## The owner moves it with `set_facing()`. It tracks overlapping interactables and exposes the
## closest enabled one as `current_target`, emitting `target_changed` when that changes.

signal target_changed(target: Interactable)

## Distance from the actor's origin to the probe centre along the facing direction.
@export var reach: float = 12.0
## Offset from the actor's origin (feet) to its "hands" height.
@export var origin_offset: Vector2 = Vector2(0, -6)

var current_target: Interactable = null
var _candidates: Array[Interactable] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER_INTERACTABLES
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func set_facing(direction: Vector2) -> void:
	position = origin_offset + direction.normalized() * reach


func _physics_process(_delta: float) -> void:
	refresh_target()


## Chooses the closest enabled candidate. Public so tests and the owner can force a refresh.
func refresh_target() -> void:
	var best: Interactable = null
	var best_distance := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.can_interact(owner):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if best != current_target:
		current_target = best
		target_changed.emit(current_target)


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not _candidates.has(area):
		_candidates.append(area)


func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area)
