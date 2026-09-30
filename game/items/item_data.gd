class_name ItemData
extends Resource
## Definition of one item kind (data/items/<id>.tres). Every carried thing is an item: seeds,
## crops, and later kith food, crafting materials and trade goods. Behaviour is driven by tags, so
## new items need no code.

## Tags in use: &"seed" (plantable; see CropData.seed_item_id), &"crop" (harvested produce, sold at
## the shipping crate), &"food" (edible; later: people and kith).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tags: Array[StringName] = []
## Value in marks when sold (before any future price modifiers).
@export_range(0, 100000) var base_value: int = 0
@export_range(1, 999) var stack_max: int = 99
## Optional until the inventory gets icons.
@export var icon: Texture2D


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
