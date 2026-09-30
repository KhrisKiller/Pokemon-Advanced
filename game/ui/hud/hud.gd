class_name Hud
extends CanvasLayer
## In-game HUD: date/time, money, selected seed, interaction prompt, message box, bag panel,
## location banner and full-screen fade.

const INVENTORY_MODAL := &"inventory"

@onready var message_box: MessageBox = %MessageBox
@onready var _date_label: Label = %DateLabel
@onready var _time_label: Label = %TimeLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _fade: ColorRect = %Fade
@onready var _location_label: Label = %LocationLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _inventory_items: Label = %Items

var _player_state: PlayerState

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


## Shows money, the selected seed and the bag of this PlayerState.
func bind_player_state(state: PlayerState) -> void:
	_player_state = state
	state.money_changed.connect(_on_money_changed)
	state.selected_seed_changed.connect(_on_selected_seed_changed)
	state.inventory.changed.connect(_refresh_belongings)
	_refresh_belongings()


func get_money_text() -> String:
	return _money_label.text


func get_seed_text() -> String:
	return _seed_label.text


func is_inventory_open() -> bool:
	return _inventory_panel.visible


func get_inventory_text() -> String:
	return _inventory_items.text


func toggle_inventory() -> void:
	if _inventory_panel.visible:
		_inventory_panel.hide()
		Clock.release_pause(INVENTORY_MODAL)
		EventBus.modal_closed.emit(INVENTORY_MODAL)
	elif _open_modals.is_empty():
		_refresh_belongings()
		_inventory_panel.show()
		Clock.request_pause(INVENTORY_MODAL)
		EventBus.modal_opened.emit(INVENTORY_MODAL)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory") and _player_state != null:
		if _inventory_panel.visible or _open_modals.is_empty():
			toggle_inventory()
			get_viewport().set_input_as_handled()


func _on_money_changed(_money: int) -> void:
	_refresh_belongings()


func _on_selected_seed_changed(_item_id: StringName) -> void:
	_refresh_belongings()


func _refresh_belongings() -> void:
	if _player_state == null:
		return
	_money_label.text = "%d marks" % _player_state.money
	var seed_id := _player_state.selected_seed
	if seed_id == &"":
		_seed_label.text = "Seeds: none"
	else:
		var seed := ContentDB.get_item(seed_id)
		_seed_label.text = "%s ×%d   [%s] switch" % [seed.display_name if seed else String(seed_id),
				_player_state.inventory.count(seed_id), _describe_action(&"cycle_seed")]
	var lines := PackedStringArray()
	for stack in _player_state.inventory.get_stacks():
		var item := ContentDB.get_item(stack["item_id"])
		lines.append("%s ×%d" % [item.display_name if item else String(stack["item_id"]), stack["quantity"]])
	_inventory_items.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


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
	if _prompt_target != null and is_instance_valid(_prompt_target) and _prompt_target.prompt_changed.is_connected(_refresh_prompt):
		_prompt_target.prompt_changed.disconnect(_refresh_prompt)
	_prompt_target = target
	if target != null:
		target.prompt_changed.connect(_refresh_prompt)
	_refresh_prompt()


func _refresh_prompt() -> void:
	var verb := _prompt_target.get_prompt() if _prompt_target != null and is_instance_valid(_prompt_target) else ""
	var show_prompt := verb != "" and _open_modals.is_empty()
	_prompt_label.visible = show_prompt
	if show_prompt:
		_prompt_label.text = "[%s] %s" % [_describe_action(&"interact"), verb]


func _on_modal_opened(modal_id: StringName) -> void:
	_open_modals[modal_id] = true
	_refresh_prompt()
	_seed_label.visible = false


func _on_modal_closed(modal_id: StringName) -> void:
	_open_modals.erase(modal_id)
	_refresh_prompt()
	_seed_label.visible = _open_modals.is_empty()


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
