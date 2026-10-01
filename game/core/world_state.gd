extends Node
## Persistent facts about the world (autoload `WorldState`).
##
## Phase 2 scope: named flags (bool, int or String values) and discovered locations. Later phases
## add war tension, faction control and route status here (see TECHNICAL_DESIGN.md §8).
## Flags are how story, NPCs and (later) quests remember things without special-case code.

signal flag_changed(flag: StringName, value: Variant)
signal location_discovered(map_id: StringName)
## All flags and locations were replaced by a loaded save (no flag_changed per flag).
signal loaded

const SAVE_VERSION := 1

var _flags: Dictionary[StringName, Variant] = {}
var _discovered: Dictionary[StringName, bool] = {}


func reset() -> void:
	_flags.clear()
	_discovered.clear()


# --- flags -----------------------------------------------------------------------------------

func set_flag(flag: StringName, value: Variant = true) -> void:
	if not _is_supported_value(value):
		push_error("World flag '%s' must be bool, int or String (got %s)." % [flag, type_string(typeof(value))])
		return
	if _flags.has(flag) and typeof(_flags[flag]) == typeof(value) and _flags[flag] == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return _flags.get(flag, default)


## True if the flag exists and is truthy (true, non-zero, non-empty).
func has_flag(flag: StringName) -> bool:
	return _flags.has(flag) and bool(_flags[flag])


func clear_flag(flag: StringName) -> void:
	if _flags.erase(flag):
		flag_changed.emit(flag, null)


func increment(flag: StringName, amount: int = 1) -> int:
	var value := int(_flags.get(flag, 0)) + amount
	set_flag(flag, value)
	return value


# --- locations -------------------------------------------------------------------------------

## Marks a map as discovered. Returns true the first time.
func discover_location(map_id: StringName) -> bool:
	if _discovered.has(map_id):
		return false
	_discovered[map_id] = true
	location_discovered.emit(map_id)
	return true


func is_discovered(map_id: StringName) -> bool:
	return _discovered.has(map_id)


func get_discovered_locations() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_discovered.keys())
	return ids


# --- persistence (Saveable contract) ---------------------------------------------------------

func get_save_id() -> StringName:
	return &"world"


func to_save_data() -> Dictionary:
	var flags := {}
	for flag in _flags:
		flags[String(flag)] = _flags[flag]
	var discovered: Array[String] = []
	for id in _discovered:
		discovered.append(String(id))
	discovered.sort()
	return {"version": SAVE_VERSION, "flags": flags, "discovered": discovered}


func load_save_data(data: Dictionary) -> void:
	reset()
	var flags: Variant = data.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		for key: String in flags:
			var value: Variant = flags[key]
			# JSON has no int type: whole numbers come back as floats.
			if typeof(value) == TYPE_FLOAT:
				value = int(value)
			if _is_supported_value(value):
				_flags[StringName(key)] = value
	var discovered: Variant = data.get("discovered", [])
	if typeof(discovered) == TYPE_ARRAY:
		for id: Variant in discovered:
			_discovered[StringName(str(id))] = true
	loaded.emit()


static func _is_supported_value(value: Variant) -> bool:
	return typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]
