class_name KithConfig
extends Resource
## Tunable kith rules (data/config/kith_config.tres). All values are provisional.

@export_range(1, 30) var party_limit: int = 6
@export_range(1, 1000) var trust_max: int = 100
## Trust at or above each threshold gets the matching label (same order, ascending).
@export var trust_thresholds: Array[int] = [0, 25, 50, 75]
@export var trust_labels: PackedStringArray = ["Unfamiliar", "Friendly", "Trusted", "Bonded"]
## Trust a kith starts with when it bonds.
@export_range(0, 100) var starting_trust: int = 10
@export_range(0, 100) var favourite_food_trust: int = 8
@export_range(0, 100) var liked_food_trust: int = 3
## Feedings per kith per day that count (more food is refused until tomorrow).
@export_range(1, 10) var feeds_per_day: int = 1
## Calm gained when a wild kith is offered food.
@export_range(0, 10) var favourite_food_calm: int = 2
@export_range(0, 10) var liked_food_calm: int = 1
## Item consumed to bond.
@export var bond_item_id: StringName = &"bond_charm"
## Helper ability &"water": Trust needed and plots per day.
@export_range(0, 1000) var watering_min_trust: int = 25
@export_range(0, 100) var watering_daily_limit: int = 3


func trust_label(trust: int) -> String:
	var label := trust_labels[0] if not trust_labels.is_empty() else ""
	for i in mini(trust_thresholds.size(), trust_labels.size()):
		if trust >= trust_thresholds[i]:
			label = trust_labels[i]
	return label
