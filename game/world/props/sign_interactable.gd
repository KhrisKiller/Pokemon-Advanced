class_name SignInteractable
extends Interactable
## Shows fixed text lines when used. Used for signs, notices and anything "inspectable".
## (Phase 1 placeholder for the data-driven dialogue system.)

@export_multiline var lines: PackedStringArray = ["..."]


func _on_interact(_actor: Node) -> void:
	EventBus.dialogue_requested.emit(lines)
