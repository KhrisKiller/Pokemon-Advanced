class_name SaveFormat
extends RefCounted
## Pure description of the save file layout: building, validating and upgrading save data.
## No file access here (see SaveService), so it is fully unit-testable.
##
## Format history (migrations in SaveMigrations; fixtures in tests/fixtures/saves/):
##   v1 — { "format_version": 1, "saved_at": String, "<section_id>": {...}, ... }
##        Sections at the top level next to the header keys. (Phase 2, first save commit.)
##   v2 — { "format_version": 2,
##          "meta": { "saved_at": String, "game_version": String, "summary": {...} },
##          "sections": { "<section_id>": {...} } }
##        Sections namespaced; `meta` lets a load screen show a slot without reading sections.

const CURRENT_VERSION := 2


## Builds a save dictionary in the current format.
static func build(sections: Dictionary, saved_at: String, game_version: String = "", summary: Dictionary = {}) -> Dictionary:
	return {
		"format_version": CURRENT_VERSION,
		"meta": {"saved_at": saved_at, "game_version": game_version, "summary": summary},
		"sections": sections.duplicate(true),
	}


## Returns the version of raw save data, or -1 if it is not a MONSERA save.
static func get_version(data: Dictionary) -> int:
	var version: Variant = data.get("format_version")
	if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
		return -1
	return int(version)


## Upgrades raw data of any supported version to CURRENT_VERSION. Returns {} if unusable.
static func upgrade(data: Dictionary) -> Dictionary:
	var version := get_version(data)
	if version < 1 or version > CURRENT_VERSION:
		return {}
	var upgraded := data if version == CURRENT_VERSION else SaveMigrations.migrate(data, CURRENT_VERSION)
	if upgraded.is_empty() or typeof(upgraded.get("sections")) != TYPE_DICTIONARY:
		return {}
	return upgraded


## Extracts the sections (id → data) from data in the current format.
static func get_sections(data: Dictionary) -> Dictionary:
	var sections := {}
	var raw: Variant = data.get("sections", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return sections
	for key: String in raw:
		if typeof(raw[key]) == TYPE_DICTIONARY:
			sections[key] = raw[key]
	return sections


static func get_file_meta(data: Dictionary) -> Dictionary:
	var meta: Variant = data.get("meta", {})
	return meta if typeof(meta) == TYPE_DICTIONARY else {}
