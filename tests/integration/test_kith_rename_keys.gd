extends TestCase
## The party screen's rename box with real key events (typing, Enter, Esc).

const MAIN_SCENE := preload("res://game/main/main.tscn")
var main: Main


func before_each() -> void:
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0
	main = MAIN_SCENE.instantiate() as Main
	main.fade_duration = 0.0
	add_to_root(main)
	await wait_frames(2)


func _key(code: Key, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = unicode if pressed else 0
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_frames(1)


func _open_rename(menu: KithMenu) -> void:
	menu.select(menu.find_row("Rename"))
	menu.choose()
	await wait_frames(3)


func test_typing_a_name_then_escape_cancels_the_next_rename() -> void:
	var kith := main.session.kith.add_new(&"rillet")
	var menu := main.hud.kith_menu
	assert_true(main.hud.open_kith_menu())
	menu.choose()  # actions
	await _open_rename(menu)
	for c in "Pud":
		await _key(OS.find_keycode_from_string(c), c.unicode_at(0))
	await _key(KEY_ENTER)
	assert_eq(kith.nickname, "Pud")
	assert_eq(menu.page, KithMenu.Page.ACTIONS)
	assert_true(menu.get_message().contains("Now called Pud"), menu.get_message())

	await _open_rename(menu)
	await _key(KEY_X, "x".unicode_at(0))
	for i in 3:  # Esc leaves the text box, then the rename page
		if menu.page != KithMenu.Page.RENAME:
			break
		await _key(KEY_ESCAPE)
	assert_eq(menu.page, KithMenu.Page.ACTIONS)
	assert_eq(kith.nickname, "Pud", "cancelled rename keeps the old name")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	assert_false(menu.is_open())
	assert_true(main.player.is_control_enabled())
