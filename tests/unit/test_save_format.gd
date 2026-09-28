extends TestCase
## SaveFormat: building, versions, sections.


func test_build_contains_header_and_sections() -> void:
	var data := SaveFormat.build({"clock": {"day_index": 3}}, "2026-01-01T00:00:00Z")
	assert_eq(SaveFormat.get_version(data), SaveFormat.CURRENT_VERSION)
	var sections := SaveFormat.get_sections(data)
	assert_eq(sections.keys(), ["clock"])
	assert_eq(sections["clock"]["day_index"], 3)


func test_non_save_data_has_no_version() -> void:
	assert_eq(SaveFormat.get_version({}), -1)
	assert_eq(SaveFormat.get_version({"format_version": "one"}), -1)


func test_json_float_version_is_accepted() -> void:
	assert_eq(SaveFormat.get_version({"format_version": 1.0}), 1)


func test_future_or_invalid_versions_are_rejected() -> void:
	assert_eq(SaveFormat.upgrade({"format_version": SaveFormat.CURRENT_VERSION + 1}), {})
	assert_eq(SaveFormat.upgrade({"format_version": 0}), {})
	assert_eq(SaveFormat.upgrade({"hello": "world"}), {})


func test_sections_ignore_non_dictionary_values() -> void:
	var sections := SaveFormat.get_sections({"format_version": 1, "saved_at": "x", "junk": 5, "a": {}})
	assert_eq(sections.keys(), ["a"])
