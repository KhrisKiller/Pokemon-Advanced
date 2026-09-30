class_name CropData
extends Resource
## Definition of one crop (data/crops/<id>.tres). Farming rules read only these fields, so a new
## crop is a new .tres (plus its seed and produce items) — no code changes.

@export var id: StringName = &""
@export var display_name: String = ""
## Item consumed when planting (must have the &"seed" tag).
@export var seed_item_id: StringName = &""
## Item produced on harvest.
@export var harvest_item_id: StringName = &""
@export_range(1, 99) var harvest_quantity: int = 1
## Watered days needed from planting to maturity.
@export_range(1, 60) var growth_days: int = 3
## 0 = harvested once (the crop is removed). N > 0 = regrows and is ready again N watered days later.
@export_range(0, 60) var regrow_days: int = 0
## Visual stages from seedling to mature (the sprite sheet has this many frames).
@export_range(2, 8) var stage_count: int = 4
@export var sprite_sheet: Texture2D


func regrows() -> bool:
	return regrow_days > 0
