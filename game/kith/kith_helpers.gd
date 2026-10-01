class_name KithHelpers
extends RefCounted
## Kith utility work done by the daily simulation (never by simulating player input).
## Phase 4 has one ability: &"water". Each eligible kith works through the farming rules
## (FarmState.apply_helper_action), so it doesn't matter which map the player is on.

const WATER := &"water"


## Can this kith use `ability` today? Needs the capability (species data), enough Trust and daily
## actions left (KithConfig).
static func can_help(kith: KithState, species: KithData, ability: StringName, config: KithConfig) -> bool:
	if species == null or not species.has_ability(ability):
		return false
	match ability:
		WATER:
			return kith.trust >= config.watering_min_trust and kith.helper_actions_today < config.watering_daily_limit
	return false


## Runs every party member's helper work for the new day. Returns one entry per kith that did
## something: {"uid", "name", "ability", "plots": Array[StringName]}.
static func run_daily(roster: KithRoster, farm: FarmState, config: KithConfig) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for kith in roster.get_members():
		var species := roster.get_species(kith)
		if not can_help(kith, species, WATER, config):
			continue
		var plots := farm.apply_helper_action(WATER, config.watering_daily_limit - kith.helper_actions_today)
		if plots.is_empty():
			continue
		kith.helper_actions_today += plots.size()
		reports.append({"uid": kith.uid, "name": kith.get_display_name(species), "ability": WATER, "plots": plots})
	return reports
