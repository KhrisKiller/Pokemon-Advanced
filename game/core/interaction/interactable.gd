class_name Interactable
extends Area2D
## Something the player can interact with by facing it and pressing `interact`.
##
## Put it on physics layer 3 (`interactables`) with a CollisionShape2D child. The player's
## InteractionProbe finds it. Subclasses override `_on_interact()`; anything else can connect
## to `interacted`.

signal interacted(actor: Node)

const LAYER_INTERACTABLES := 1 << 2

## Verb shown in the HUD prompt, e.g. "Read", "Sleep", "Talk".
@export var prompt: String = "Interact"
@export var enabled: bool = true


func _init() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact(_actor: Node) -> bool:
	return enabled


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	_on_interact(actor)
	interacted.emit(actor)


## Override in subclasses.
func _on_interact(_actor: Node) -> void:
	pass
