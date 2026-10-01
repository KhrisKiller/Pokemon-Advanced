class_name KithState
extends RefCounted
## One individual kith the player owns: identity, Trust and day-to-day state. Its species rules
## come from KithData (looked up by `species_id`); nothing species-wide is copied in here.
## The same instance will later feed BattleCreatureState and TacticalUnitState (§7).

const SAVE_VERSION := 1

## Unique, stable id ("kith_0001"); never reused.
var uid: StringName
var species_id: StringName
var nickname: String = ""
var trust: int = 0
## Future-safe progression (unused until creature battles).
var level: int = 1
var xp: int = 0
## Daily state, reset by the daily tick.
var fed_today: int = 0
var helper_actions_today: int = 0
## Where and when it bonded.
var bonded_day: int = 0
var origin: StringName = &""


func _init(id: StringName = &"", species: StringName = &"") -> void:
	uid = id
	species_id = species


func get_display_name(species: KithData) -> String:
	if nickname != "":
		return nickname
	return species.display_name if species != null else String(species_id)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "uid": String(uid), "species_id": String(species_id), "nickname": nickname,
		"trust": trust, "level": level, "xp": xp, "fed_today": fed_today,
		"helper_actions_today": helper_actions_today, "bonded_day": bonded_day, "origin": String(origin),
	}


static func from_dict(data: Dictionary) -> KithState:
	var state := KithState.new(StringName(str(data.get("uid", ""))), StringName(str(data.get("species_id", ""))))
	state.nickname = str(data.get("nickname", ""))
	state.trust = maxi(0, int(data.get("trust", 0)))
	state.level = maxi(1, int(data.get("level", 1)))
	state.xp = maxi(0, int(data.get("xp", 0)))
	state.fed_today = maxi(0, int(data.get("fed_today", 0)))
	state.helper_actions_today = maxi(0, int(data.get("helper_actions_today", 0)))
	state.bonded_day = maxi(0, int(data.get("bonded_day", 0)))
	state.origin = StringName(str(data.get("origin", "")))
	return state
