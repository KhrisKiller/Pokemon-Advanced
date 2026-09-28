class_name SaveFormat
extends RefCounted
## Pure description of the save file layout: building, validating and upgrading save data.
## No file access here (see SaveService), so it is fully unit-testable.
##
## Format history:
##   v1 — { "format_version": 1, "saved_at": String, "<section_id>": {...}, ... }
##        Sections live at the top level next to the header keys.

const CURRENT_VERSION := 1
const HEADER_KEYS: Array[String] = ["format_version", "saved_at"]


## Builds a save dictionary in the current format.
static func build(sections: Dictionary, saved_at: String) -> Dictionary:
	var data := {"format_version": CURRENT_VERSION, "saved_at": saved_at}
	for id: String in sections:
		data[id] = sections[id]
	return data


## Returns the version of raw save data, or -1 if it is not a MONSERA save.
static func get_version(data: Dictionary) -> int:
	var version: Variant = data.get("format_version")
	if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
		return -1
	return int(version)


## Upgrades raw data to CURRENT_VERSION. Returns {} if the data can't be used.
static func upgrade(data: Dictionary) -> Dictionary:
	var version := get_version(data)
	if version < 1 or version > CURRENT_VERSION:
		return {}
	return data


## Extracts the sections (id → data) from data in the current format.
static func get_sections(data: Dictionary) -> Dictionary:
	var sections := {}
	for key: String in data:
		if key in HEADER_KEYS:
			continue
		if typeof(data[key]) == TYPE_DICTIONARY:
			sections[key] = data[key]
	return sections
