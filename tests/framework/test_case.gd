class_name TestCase
extends RefCounted
## Base class for MONSERA tests. Every method whose name starts with `test_` is run by
## `tests/test_runner.tscn`. Methods may be coroutines (use `await`).
##
## Each test gets a fresh `root` node inside the running SceneTree. Anything added with
## `add_to_root()` is freed after the test.

var tree: SceneTree
var root: Node
var _failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# --- helpers ---------------------------------------------------------------------------------

func add_to_root(node: Node) -> Node:
	root.add_child(node)
	return node


func wait_frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


# --- assertions ------------------------------------------------------------------------------

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _values_equal(actual, expected):
		_fail("expected <%s> but got <%s>" % [str(expected), str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _values_equal(actual, unexpected):
		_fail("did not expect <%s>" % str(unexpected), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s but got %s" % [expected, tolerance, actual], message)


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	if not actual > threshold:
		_fail("expected > %s but got %s" % [threshold, actual], message)


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	if not actual < threshold:
		_fail("expected < %s but got %s" % [threshold, actual], message)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_fail("expected a value but got null", message)


func fail(message: String) -> void:
	_fail("failed", message)


# --- runner API ------------------------------------------------------------------------------

func get_failures() -> PackedStringArray:
	return _failures


func clear_failures() -> void:
	_failures.clear()


func _fail(reason: String, message: String) -> void:
	var location := ""
	var stack := get_stack()
	# get_stack()[0] is _fail, [1] the assert_* helper, [2] the test code.
	if stack.size() > 2:
		location = " (%s:%d)" % [str(stack[2]["source"]).get_file(), int(stack[2]["line"])]
	_failures.append("%s%s%s" % [reason, (": " + message) if message != "" else "", location])


static func _values_equal(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) != typeof(b):
		if typeof(a) in numeric and typeof(b) in numeric:
			return is_equal_approx(float(a), float(b))
		# StringName vs String compare by text.
		if (a is String or a is StringName) and (b is String or b is StringName):
			return str(a) == str(b)
		return false
	return a == b
