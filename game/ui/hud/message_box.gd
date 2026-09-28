class_name MessageBox
extends PanelContainer
## Modal box that shows text lines one at a time. While open it pauses the clock and locks
## player control. Phase 1 stand-in for the data-driven dialogue system.

signal closed

const MODAL_ID := &"message_box"

var _lines: PackedStringArray = []
var _index: int = 0

@onready var _text: Label = %Text
@onready var _more: Label = %More
@onready var _name_tag: Label = %NameTag


func _ready() -> void:
	hide()
	EventBus.dialogue_requested.connect(show_lines)
	EventBus.conversation_requested.connect(_on_conversation_requested)


func show_lines(lines: PackedStringArray, speaker: String = "") -> void:
	if lines.is_empty():
		return
	_name_tag.text = speaker
	_name_tag.visible = speaker != ""
	_lines = lines
	_index = 0
	if not visible:
		show()
		Clock.request_pause(MODAL_ID)
		EventBus.modal_opened.emit(MODAL_ID)
	_show_current()


func is_open() -> bool:
	return visible


func get_speaker() -> String:
	return _name_tag.text if visible and _name_tag.visible else ""


func get_current_line() -> String:
	return _lines[_index] if visible and _index < _lines.size() else ""


func advance() -> void:
	if not visible:
		return
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_current()


func close() -> void:
	if not visible:
		return
	hide()
	_lines = []
	Clock.release_pause(MODAL_ID)
	EventBus.modal_closed.emit(MODAL_ID)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _show_current() -> void:
	_text.text = _lines[_index]
	_more.text = "▼" if _index < _lines.size() - 1 else "■"


func _on_conversation_requested(speaker: String, lines: PackedStringArray) -> void:
	show_lines(lines, speaker)
