class_name Npc
extends Interactable
## A placeholder NPC: identity (NpcData), a position in a map, interaction and placeholder
## dialogue. Stands still; turns to face whoever talks to it.

enum Frame { DOWN, UP, LEFT, RIGHT }

@export var data: NpcData

var facing: Vector2 = Vector2.DOWN

@onready var _sprite: Sprite2D = $Sprite2D


func _init() -> void:
	super()
	prompt = "Talk"


func _ready() -> void:
	if data != null and data.sprite != null:
		_sprite.texture = data.sprite
	_apply_facing()


func can_interact(actor: Node) -> bool:
	return super(actor) and data != null


func get_display_name() -> String:
	return data.display_name if data != null else ""


## Lines for the next conversation: first meeting until the met flag is set.
func get_lines() -> PackedStringArray:
	if data == null:
		return PackedStringArray()
	if WorldState.has_flag(data.get_met_flag()) and not data.repeat_lines.is_empty():
		return data.repeat_lines
	return data.first_meeting_lines


func _on_interact(actor: Node) -> void:
	if actor is Node2D:
		face_towards((actor as Node2D).global_position)
	var lines := get_lines()
	WorldState.set_flag(data.get_met_flag())
	EventBus.conversation_requested.emit(data.display_name, lines)


func face_towards(point: Vector2) -> void:
	var delta := point - global_position
	if delta == Vector2.ZERO:
		return
	if absf(delta.x) > absf(delta.y):
		facing = Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if delta.y > 0.0 else Vector2.UP
	_apply_facing()


func _apply_facing() -> void:
	if _sprite == null:
		return
	match facing:
		Vector2.UP:
			_sprite.frame = Frame.UP
		Vector2.LEFT:
			_sprite.frame = Frame.LEFT
		Vector2.RIGHT:
			_sprite.frame = Frame.RIGHT
		_:
			_sprite.frame = Frame.DOWN
