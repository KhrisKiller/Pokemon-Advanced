extends Node
## Save/load service (autoload `SaveService`).
##
## Systems that persist register as **providers** implementing the Saveable contract:
##   get_save_id() -> StringName
##   to_save_data() -> Dictionary      (JSON-safe values only: bool, int, float, String, Array, Dictionary)
##   load_save_data(data: Dictionary)  (must accept {} and fall back to defaults)
## The composition root (Main) registers the session's providers; sections load in registration order. Files are JSON in `save_dir`, written atomically
## (temp file + rename) with the previous save kept as `.bak`, which is used if the main file is
## unreadable.

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(slot: int, error: Error)
signal load_failed(slot: int, error: Error)

const DEFAULT_SAVE_DIR := "user://saves"

var save_dir: String = DEFAULT_SAVE_DIR
var _providers: Array[Object] = []


# --- providers -------------------------------------------------------------------------------

func register(provider: Object) -> void:
	for method in ["get_save_id", "to_save_data", "load_save_data"]:
		if not provider.has_method(method):
			push_error("Save provider %s is missing %s()" % [provider, method])
			return
	if _providers.has(provider):
		return
	for existing in _providers:
		if existing.get_save_id() == provider.get_save_id():
			push_error("Duplicate save id '%s'" % provider.get_save_id())
			return
	_providers.append(provider)


func unregister(provider: Object) -> void:
	_providers.erase(provider)


func get_provider_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for provider in _providers:
		ids.append(provider.get_save_id())
	return ids


# --- slots -----------------------------------------------------------------------------------

func get_slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_slot_path(slot)) or FileAccess.file_exists(get_slot_path(slot) + ".bak")


func delete_save(slot: int = 1) -> void:
	for path in [get_slot_path(slot), get_slot_path(slot) + ".bak", get_slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func delete_all_saves() -> void:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


# --- save / load -----------------------------------------------------------------------------

func collect_sections() -> Dictionary:
	var sections := {}
	for provider in _providers:
		sections[String(provider.get_save_id())] = provider.to_save_data()
	return sections


func save_game(slot: int = 1) -> Error:
	var data := SaveFormat.build(collect_sections(), Time.get_datetime_string_from_system(true) + "Z")
	var err := _write_atomic(get_slot_path(slot), JSON.stringify(data, "\t"))
	if err != OK:
		push_warning("Saving slot %d failed: %s" % [slot, error_string(err)])
		save_failed.emit(slot, err)
		return err
	game_saved.emit(slot)
	return OK


func load_game(slot: int = 1) -> Error:
	var path := get_slot_path(slot)
	var data := read_save_data(path)
	if data.is_empty() and FileAccess.file_exists(path + ".bak"):
		push_warning("Save slot %d is unreadable; using the backup." % slot)
		data = read_save_data(path + ".bak")
	if data.is_empty():
		var err := ERR_FILE_NOT_FOUND if not has_save(slot) else ERR_FILE_CORRUPT
		load_failed.emit(slot, err)
		return err
	apply_sections(SaveFormat.get_sections(data))
	game_loaded.emit(slot)
	return OK


## Gives each provider its section ({} if missing), in registration order.
func apply_sections(sections: Dictionary) -> void:
	for provider in _providers.duplicate():
		var id := String(provider.get_save_id())
		var section: Variant = sections.get(id, {})
		provider.load_save_data(section if typeof(section) == TYPE_DICTIONARY else {})


## Reads, parses and upgrades a save file. Returns {} if missing, corrupt or unsupported.
func read_save_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Save file %s is not valid JSON (%s)." % [path, json.get_error_message()])
		return {}
	var parsed: Dictionary = json.data
	var upgraded := SaveFormat.upgrade(parsed)
	if upgraded.is_empty():
		push_warning("Save file %s has an unsupported format version (%s)." % [path, SaveFormat.get_version(parsed)])
	return upgraded


func _write_atomic(path: String, text: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		var backup := path + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		err = DirAccess.rename_absolute(path, backup)
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp_path, path)
