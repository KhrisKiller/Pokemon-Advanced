class_name KithData
extends Resource
## A kith species (data/kith/<id>.tres): the static definition shared by every individual.
## Individuals are KithState. Phase 4 holds only what current systems use; battle stats,
## techniques, maturation and tactical profiles are added by the phases that need them
## (TECHNICAL_DESIGN.md §7).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Identity only for now (no combat yet).
@export var aspects: Array[StringName] = []
## Food item tags this species loves (biggest Trust gain, calms it fastest when wild).
@export var favourite_food_tags: Array[StringName] = []
## Food item tags it will eat. Food matching neither list is refused.
@export var liked_food_tags: Array[StringName] = []
## Utility abilities (e.g. &"water"). What they do and their limits live in KithConfig.
@export var helper_abilities: Array[StringName] = []
## Calm a wild one needs before it accepts a Bond Charm.
@export_range(0, 10) var bond_calm_needed: int = 2
@export var sprite: Texture2D
@export var ui_color: Color = Color.WHITE


func loves(item: ItemData) -> bool:
	return item != null and _matches(item, favourite_food_tags)


## Will eat it at all (favourite or liked), and it is food.
func will_eat(item: ItemData) -> bool:
	return item != null and item.has_tag(&"food") and (_matches(item, favourite_food_tags) or _matches(item, liked_food_tags))


func has_ability(ability: StringName) -> bool:
	return helper_abilities.has(ability)


static func _matches(item: ItemData, tags: Array[StringName]) -> bool:
	for tag in tags:
		if item.has_tag(tag):
			return true
	return false
