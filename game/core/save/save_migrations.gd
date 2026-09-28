class_name SaveMigrations
extends RefCounted
## Upgrades save files between **file format** versions, one step at a time (v1 → v2 → …).
##
## Two layers of versioning exist:
## - File format (`format_version`): the envelope. Migrated here.
## - Section data (`"version"` inside each section): owned by the provider that wrote it, which
##   must keep reading its older section versions in `load_save_data()`.
## Never edit an existing step; add a new one and a fixture written by the old code.

## Runs every step needed to bring `data` from its version to `target_version`.
## Returns {} if a step is missing or fails.
static func migrate(data: Dictionary, target_version: int) -> Dictionary:
	var current := data.duplicate(true)
	var version := SaveFormat.get_version(current)
	while version < target_version:
		match version:
			1:
				current = _v1_to_v2(current)
			_:
				push_warning("No save migration from format v%d." % version)
				return {}
		var next := SaveFormat.get_version(current)
		if next != version + 1:
			push_warning("Save migration from v%d produced v%d." % [version, next])
			return {}
		version = next
	return current


## v1: header keys and sections share the top level.
## v2: { format_version, meta: { saved_at, game_version, summary }, sections: { id: {...} } }
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var sections := {}
	for key: String in data:
		if key in ["format_version", "saved_at"]:
			continue
		if typeof(data[key]) == TYPE_DICTIONARY:
			sections[key] = data[key]
	return {
		"format_version": 2,
		"meta": {
			"saved_at": str(data.get("saved_at", "")),
			"game_version": "unknown (format v1)",
			"summary": {},
		},
		"sections": sections,
	}
