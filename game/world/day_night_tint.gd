class_name DayNightTint
extends CanvasModulate
## Tints the world by time of day. Only affects the canvas it lives on, so the HUD (on its own
## CanvasLayer) keeps its true colours.

## Colour over the 24 h day: offset 0.0 = midnight, 0.5 = noon.
@export var gradient: Gradient


func _ready() -> void:
	if gradient == null:
		gradient = Gradient.new()
	Clock.minute_changed.connect(_on_time_changed)
	Clock.time_step_changed.connect(_on_time_changed)
	apply_time(Clock.time)


func apply_time(time: GameTime) -> void:
	color = color_for_hour(time.get_hour_float())


func color_for_hour(hour: float) -> Color:
	return gradient.sample(fposmod(hour, 24.0) / 24.0)


func _on_time_changed(time: GameTime) -> void:
	apply_time(time)
