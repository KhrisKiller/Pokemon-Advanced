class_name BedInteractable
extends Interactable
## The player's bed: asks the game to end the day. `Main` owns the actual day transition.


func _init() -> void:
	super()
	prompt = "Sleep"


func _on_interact(_actor: Node) -> void:
	EventBus.sleep_requested.emit(self)
