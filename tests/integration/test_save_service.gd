extends TestCase
## SaveService file handling with fake providers (autoload instance, test save dir).


class FakeProvider:
	extends RefCounted
	var id: StringName
	var data: Dictionary = {}
	var loaded: Array[Dictionary] = []

	func _init(save_id: StringName, initial: Dictionary = {}) -> void:
		id = save_id
		data = initial

	func get_save_id() -> StringName:
		return id

	func to_save_data() -> Dictionary:
		return data

	func load_save_data(section: Dictionary) -> void:
		loaded.append(section)


var providers: Array[FakeProvider] = []


func after_each() -> void:
	for p in providers:
		SaveService.unregister(p)
	providers.clear()


func _provider(id: StringName, initial: Dictionary = {}) -> FakeProvider:
	var p := FakeProvider.new(id, initial)
	providers.append(p)
	SaveService.register(p)
	return p


func test_save_writes_json_file_with_sections() -> void:
	_provider(&"fake_a", {"value": 42})
	assert_false(SaveService.has_save(9))
	assert_eq(SaveService.save_game(9), OK)
	assert_true(SaveService.has_save(9))
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.get_slot_path(9)))
	assert_eq(SaveFormat.get_version(parsed), SaveFormat.CURRENT_VERSION)
	assert_eq(SaveFormat.get_sections(parsed)["fake_a"]["value"], 42)


func test_round_trip_gives_each_provider_its_section() -> void:
	var a := _provider(&"fake_a", {"n": 1})
	var b := _provider(&"fake_b", {"s": "hello"})
	SaveService.save_game(2)
	assert_eq(SaveService.load_game(2), OK)
	assert_eq(a.loaded.size(), 1)
	assert_eq(int(a.loaded[0]["n"]), 1)
	assert_eq(b.loaded[0]["s"], "hello")


func test_missing_section_loads_as_empty_dictionary() -> void:
	_provider(&"fake_a", {"n": 1})
	SaveService.save_game(3)
	var late := _provider(&"fake_late")
	SaveService.load_game(3)
	assert_eq(late.loaded, [{}] as Array[Dictionary], "providers get {} when their section is absent")


func test_register_rejects_duplicates_and_incomplete_providers() -> void:
	var a := _provider(&"fake_a")
	var count := SaveService.get_provider_ids().size()
	SaveService.register(a)
	assert_eq(SaveService.get_provider_ids().size(), count, "same provider twice is ignored")


func test_load_without_save_fails_cleanly() -> void:
	var failures: Array = []
	SaveService.load_failed.connect(func(slot: int, err: Error) -> void: failures.append([slot, err]), CONNECT_ONE_SHOT)
	assert_eq(SaveService.load_game(7), ERR_FILE_NOT_FOUND)
	assert_eq(failures, [[7, ERR_FILE_NOT_FOUND]])


func test_second_save_keeps_backup_of_first() -> void:
	var a := _provider(&"fake_a", {"n": 1})
	SaveService.save_game(4)
	a.data = {"n": 2}
	SaveService.save_game(4)
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.get_slot_path(4) + ".bak"))
	assert_eq(int(SaveFormat.get_sections(backup)["fake_a"]["n"]), 1)
	assert_false(FileAccess.file_exists(SaveService.get_slot_path(4) + ".tmp"), "temp file cleaned up")


func test_corrupt_save_falls_back_to_backup() -> void:
	var a := _provider(&"fake_a", {"n": 1})
	SaveService.save_game(5)
	a.data = {"n": 2}
	SaveService.save_game(5)
	var file := FileAccess.open(SaveService.get_slot_path(5), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_eq(SaveService.load_game(5), OK)
	assert_eq(int(a.loaded[0]["n"]), 1, "loaded the backup")


func test_unsupported_version_is_rejected() -> void:
	_provider(&"fake_a")
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	var file := FileAccess.open(SaveService.get_slot_path(6), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 999, "fake_a": {}}))
	file.close()
	assert_eq(SaveService.load_game(6), ERR_FILE_CORRUPT)


func test_delete_save() -> void:
	_provider(&"fake_a")
	SaveService.save_game(8)
	SaveService.save_game(8)
	SaveService.delete_save(8)
	assert_false(SaveService.has_save(8))
