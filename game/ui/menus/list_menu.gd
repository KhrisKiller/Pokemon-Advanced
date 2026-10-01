class_name ListMenu
extends PanelContainer
## Minimal modal list menu: a title, selectable rows, a detail text and a feedback line.
## While open it pauses the clock and locks the player (like the message box).
## Keys: up/down select, interact/accept choose, cancel goes back (or closes).
## Subclasses build the rows (`_build_rows`) and handle `_go_back`. Rows are
## {"text": String, "action": Callable (optional)}.

signal closed

var modal_id: StringName = &"menu"

var _rows: Array[Dictionary] = []
var _selected: int = 0
var _title: Label
var _rows_label: Label
var _detail: Label
var _message: Label
var _hint: Label


func _init() -> void:
	hide()
	custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	add_child(box)
	_title = _make_label(box, 13)
	_rows_label = _make_label(box, 11)
	_detail = _make_label(box, 9)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message = _make_label(box, 10)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override(&"font_color", Color(0.18, 0.37, 0.16))
	_hint = _make_label(box, 9)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func is_open() -> bool:
	return visible


## Opens the menu (no-op if already open).
func open_menu() -> void:
	if visible:
		return
	_selected = 0
	set_message("")
	show()
	Clock.request_pause(modal_id)
	EventBus.modal_opened.emit(modal_id)
	refresh()


func close_menu() -> void:
	if not visible:
		return
	hide()
	Clock.release_pause(modal_id)
	EventBus.modal_closed.emit(modal_id)
	closed.emit()


func refresh() -> void:
	_rows = _build_rows()
	_selected = clampi(_selected, 0, maxi(0, _rows.size() - 1))
	_render()


func move_selection(step: int) -> void:
	if _rows.is_empty():
		return
	_selected = posmod(_selected + step, _rows.size())
	_render()


func select(index: int) -> void:
	_selected = clampi(index, 0, maxi(0, _rows.size() - 1))
	_render()


## Runs the selected row's action.
func choose() -> void:
	if _selected >= _rows.size():
		return
	var action: Variant = _rows[_selected].get("action")
	if action is Callable and (action as Callable).is_valid():
		(action as Callable).call()
	if visible:
		refresh()


func get_row_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for row in _rows:
		texts.append(row["text"])
	return texts


## Index of the first row whose text contains `fragment` (-1 if none).
func find_row(fragment: String) -> int:
	for i in _rows.size():
		if String(_rows[i]["text"]).contains(fragment):
			return i
	return -1


func get_selected() -> int:
	return _selected


func get_title() -> String:
	return _title.text


func get_detail() -> String:
	return _detail.text


func get_message() -> String:
	return _message.text


func set_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


# --- for subclasses --------------------------------------------------------------------------

func _build_rows() -> Array[Dictionary]:
	return []


## Cancel pressed. Default: close. Menus with sub-pages go up a level first.
func _go_back() -> void:
	close_menu()


func _set_title(text: String) -> void:
	_title.text = text


func _set_detail(text: String) -> void:
	_detail.text = text
	_detail.visible = text != ""


func _set_hint(text: String) -> void:
	_hint.text = text


# --- input and drawing -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_up"):
		move_selection(-1)
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_down"):
		move_selection(1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		choose()
	elif event.is_action_pressed(&"ui_cancel"):
		_go_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _render() -> void:
	var lines := PackedStringArray()
	for i in _rows.size():
		lines.append(("▶ " if i == _selected else "   ") + String(_rows[i]["text"]))
	_rows_label.text = "\n".join(lines)
	_update_detail()


## Subclasses refresh the detail text for the current selection here.
func _update_detail() -> void:
	pass


static func _make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label
