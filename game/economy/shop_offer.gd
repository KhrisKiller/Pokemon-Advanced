class_name ShopOffer
extends Resource
## One thing a shop sells, at a fixed (provisional) price in marks.

@export var item_id: StringName = &""
@export_range(0, 100000) var price: int = 0
