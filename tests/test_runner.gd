extends Node
## Headless test runner. Usage:
##   godot --headless --path . res://tests/test_runner.tscn [-- --filter=<substring>] [--dir=<res://path>]...
## Runs every `test_*` method in `tests/unit/test_*.gd` and `tests/integration/test_*.gd`, or in the
## directories given with --dir (e.g. --dir=res://spikes/tactical/tests for the isolated spike).
## A test fails on a failed assertion OR on any engine/script error logged while it runs.
## Isolation: saves go to `user://test_saves` (wiped before every test) and WorldState is reset.
## Exits with code 0 when everything passes, 1 otherwise.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]
const TEST_SAVE_DIR := "user://test_saves"


class ErrorCollector:
	extends Logger
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# error_type 1 = warning; only count real errors.
		if error_type == 1:
			return
		_mutex.lock()
		var text := rationale if rationale != "" else code
		_errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var result := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return result


var _collector := ErrorCollector.new()


func _ready() -> void:
	# If an autoload failed to compile, fail fast instead of hanging.
	for autoload in ["EventBus", "SaveService", "Clock", "WorldState"]:
		if get_node_or_null("/root/" + autoload) == null:
			printerr("Autoload %s is missing (script error?). Aborting tests." % autoload)
			get_tree().quit(1)
			return
	SaveService.save_dir = TEST_SAVE_DIR
	OS.add_logger(_collector)
	await get_tree().process_frame
	var exit_code: int = await _run_all()
	OS.remove_logger(_collector)
	get_tree().quit(exit_code)


func _run_all() -> int:
	var filter := _get_filter()
	var passed := 0
	var failed: PackedStringArray = []
	var started := Time.get_ticks_msec()

	for path in _find_test_files(_get_dirs()):
		if filter != "" and not path.contains(filter):
			continue
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: could not load test script" % path)
			continue
		print("\n%s" % path.trim_prefix("res://"))
		for method in _find_test_methods(script):
			var errors := await _run_test(script, method)
			if errors.is_empty():
				passed += 1
				print("  ✓ %s" % method)
			else:
				print("  ✗ %s" % method)
				for e in errors:
					print("      %s" % e)
				failed.append("%s::%s" % [path.get_file(), method])
		_collector.take()  # errors raised while tearing down are not attributed to a test.

	print("\n%d passed, %d failed (%d ms)" % [passed, failed.size(), Time.get_ticks_msec() - started])
	for f in failed:
		print("  FAILED %s" % f)
	return 0 if failed.is_empty() and passed > 0 else 1


func _run_test(script: Script, method: String) -> PackedStringArray:
	var test: TestCase = script.new()
	var container := Node.new()
	container.name = "TestRoot"
	add_child(container)
	test.tree = get_tree()
	test.root = container
	SaveService.save_dir = TEST_SAVE_DIR
	SaveService.delete_all_saves()
	WorldState.reset()
	_collector.take()

	await test.before_each()
	await test.call(method)
	await test.after_each()

	container.queue_free()
	await get_tree().process_frame

	var errors := test.get_failures()
	for e in _collector.take():
		errors.append("engine error: %s" % e)
	return errors


func _find_test_files(dirs: Array[String]) -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.begins_with("test_") and file.ends_with(".gd"):
				files.append(dir_path.path_join(file))
	files.sort()
	return files


func _find_test_methods(script: Script) -> PackedStringArray:
	var methods: PackedStringArray = []
	for info in script.get_script_method_list():
		var name: String = info["name"]
		if name.begins_with("test_") and not methods.has(name):
			methods.append(name)
	return methods


func _get_dirs() -> Array[String]:
	var dirs: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dirs.append(arg.trim_prefix("--dir="))
	return dirs if not dirs.is_empty() else TEST_DIRS


func _get_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""
