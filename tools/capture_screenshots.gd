extends Node
## Dev tool: plays a short scripted session of the real game and saves screenshots.
## Needs a display (use xvfb-run on a headless machine):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/capture_screenshots.tscn -- --out=/tmp/shots
## Screenshots are 2× nearest-neighbour upscales of the 640×360 game view.

const MAIN_SCENE := "res://game/main/main.tscn"

var _out_dir := "user://screenshots"
var _main: Main


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await _run()
	get_tree().quit()


func _run() -> void:
	await _frames(20)
	await _shot("01_wake_up_in_house")

	# Walk south out of the door.
	Input.action_press(&"move_down")
	await get_tree().create_timer(1.6).timeout
	Input.action_release(&"move_down")
	await _frames(20)
	await _shot("02_walked_outside")

	# Stand below the welcome sign, facing it.
	var sign := _main.current_map.entities.get_node("WelcomeSign") as Node2D
	_main.player.global_position = sign.global_position + Vector2(0, 18)
	_main.player.set_facing(Vector2.UP)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	await _shot("03_interaction_prompt")

	_main.player.try_interact()
	await _frames(5)
	await _shot("04_sign_message")
	_main.hud.message_box.close()

	_set_time(19 * 60)
	await _frames(5)
	await _shot("05_evening")
	_set_time(23 * 60 + 30)
	await _frames(5)
	await _shot("06_night")

	# Sleep: walk to the bed and use it.
	var bed := _main.current_map.entities.get_node("Bed") as Node2D
	_main.player.global_position = bed.global_position + Vector2(18, -8)
	_main.player.set_facing(Vector2.LEFT)
	_main.player.camera.reset_smoothing()
	await _frames(10)
	await _shot("07_bed_prompt")
	_main.player.try_interact()
	await get_tree().create_timer(_main.fade_duration * 2.0 + 0.3).timeout
	await _shot("08_next_morning")


func _set_time(minute_of_day: int) -> void:
	Clock.time.set_to(Clock.time.day_index, minute_of_day)
	Clock.advance_minutes(0)
	Clock.time_step_changed.emit(Clock.time)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
