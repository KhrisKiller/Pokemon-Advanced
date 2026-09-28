class_name NpcData
extends Resource
## Identity and placeholder dialogue of one NPC (data/npcs/<id>.tres).
## Phase 2 scope only: no schedules, relationships or quests yet (see ROADMAP.md, EPIC: NPC).

@export var id: StringName = &""
@export var display_name: String = ""
## 4 frames of 16×24: down, up, left, right (same layout as the player).
@export var sprite: Texture2D
## Said the first time the player talks to this NPC.
@export_multiline var first_meeting_lines: PackedStringArray = []
## Said on every later conversation.
@export_multiline var repeat_lines: PackedStringArray = []


## World flag set after the first conversation (persisted by WorldState).
func get_met_flag() -> StringName:
	return StringName("met_%s" % id)
