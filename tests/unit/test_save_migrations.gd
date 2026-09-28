extends TestCase
## SaveMigrations against real fixtures written by older game code.

const FIXTURE_DIR := "res://tests/fixtures/saves"
const V1_FIXTURE := "res://tests/fixtures/saves/v1_phase2_early.json"


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_v1_fixture_is_really_v1() -> void:
	var raw := _read(V1_FIXTURE)
	assert_eq(SaveFormat.get_version(raw), 1)
	assert_true(raw.has("clock") and raw.has("player") and raw.has("world"), "v1 keeps sections at top level")


func test_v1_to_v2_moves_sections_and_builds_meta() -> void:
	var raw := _read(V1_FIXTURE)
	var migrated := SaveMigrations.migrate(raw, 2)
	assert_eq(SaveFormat.get_version(migrated), 2)
	var sections := SaveFormat.get_sections(migrated)
	assert_eq(sections.keys().size(), 3)
	assert_eq(int(sections["clock"]["day_index"]), 2)
	assert_eq(sections["player"]["map_id"], "test_map")
	assert_eq(int(sections["world"]["flags"]["test_flag"]), 3)
	var meta := SaveFormat.get_file_meta(migrated)
	assert_eq(meta["saved_at"], raw["saved_at"], "timestamp preserved")
	assert_false(migrated.has("clock"), "no section left at the top level")


func test_migration_does_not_mutate_input() -> void:
	var raw := _read(V1_FIXTURE)
	var copy := raw.duplicate(true)
	SaveMigrations.migrate(raw, 2)
	assert_eq(raw, copy)


func test_upgrade_runs_migrations() -> void:
	var upgraded := SaveFormat.upgrade(_read(V1_FIXTURE))
	assert_eq(SaveFormat.get_version(upgraded), SaveFormat.CURRENT_VERSION)


func test_missing_step_fails_cleanly() -> void:
	assert_eq(SaveMigrations.migrate({"format_version": 0}, 2), {})


func test_every_committed_fixture_upgrades() -> void:
	# Regression net: every save format we ever shipped must still load.
	var dir := DirAccess.open(FIXTURE_DIR)
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		count += 1
		var upgraded := SaveFormat.upgrade(_read(FIXTURE_DIR.path_join(file)))
		assert_false(upgraded.is_empty(), "%s upgrades" % file)
		assert_eq(SaveFormat.get_version(upgraded), SaveFormat.CURRENT_VERSION, file)
	assert_gt(count, 0, "fixtures exist")
