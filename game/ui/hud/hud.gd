class_name Hud
extends CanvasLayer
## In-game HUD: date/time, interaction prompt, message box and full-screen fade.

@onready var message_box: MessageBox = %MessageBox
@onready var _date_label: Label = %DateLabel
@onready var _time_label: Label = %TimeLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _fade: ColorRect = %Fade
@onready var _location_label: Label = %LocationLabel

var _prompt_target: Interactable = null
var _open_modals: Dictionary[StringName, bool] = {}
var _fade_tween: Tween
var _location_tween: Tween


func _ready() -> void:
	_prompt_label.hide()
	_fade.color.a = 0.0
	Clock.time_step_changed.connect(_update_clock)
	Clock.day_started.connect(_update_clock)
	EventBus.modal_opened.connect(_on_modal_opened)
	EventBus.modal_closed.connect(_on_modal_closed)
	_update_clock(Clock.time)


## Connects the prompt to a player's interaction probe.
func bind_player(player: Player) -> void:
	player.probe.target_changed.connect(_on_target_changed)
	_on_target_changed(player.probe.current_target)


func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_label.visible else ""


func get_clock_text() -> String:
	return _time_label.text


## Briefly shows the name of the area the player just entered.
func show_location(location_name: String, hold_seconds: float = 2.0) -> void:
	if location_name == "":
		return
	_location_label.text = location_name
	_location_label.size.x = 0.0  # shrink to fit the new text
	if _location_tween != null and _location_tween.is_valid():
		_location_tween.kill()
	_location_label.modulate.a = 1.0
	_location_tween = create_tween()
	_location_tween.tween_interval(hold_seconds)
	_location_tween.tween_property(_location_label, "modulate:a", 0.0, 0.5)


func get_location_text() -> String:
	return _location_label.text if _location_label.modulate.a > 0.0 else ""


func fade_out(duration: float) -> void:
	await _fade_to(1.0, duration)


func fade_in(duration: float) -> void:
	await _fade_to(0.0, duration)


func _fade_to(alpha: float, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.0:
		_fade.color.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, duration)
	await _fade_tween.finished


func _update_clock(time: GameTime) -> void:
	_date_label.text = time.format_date()
	_time_label.text = time.format_clock()


func _on_target_changed(target: Interactable) -> void:
	_prompt_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	var show_prompt := _prompt_target != null and is_instance_valid(_prompt_target) and _open_modals.is_empty()
	_prompt_label.visible = show_prompt
	if show_prompt:
		_prompt_label.text = "[%s] %s" % [_describe_action(&"interact"), _prompt_target.prompt]


func _on_modal_opened(modal_id: StringName) -> void:
	_open_modals[modal_id] = true
	_refresh_prompt()


func _on_modal_closed(modal_id: StringName) -> void:
	_open_modals.erase(modal_id)
	_refresh_prompt()


## Name of the first keyboard key bound to an action (controller glyphs come later).
static func _describe_action(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var keycode := key.keycode
		if keycode == KEY_NONE and DisplayServer.get_name() != "headless":  # layout-aware label
			keycode = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		if keycode == KEY_NONE:
			keycode = key.physical_keycode
		return OS.get_keycode_string(keycode)
	return String(action)
