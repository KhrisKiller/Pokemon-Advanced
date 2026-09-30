class_name Pricing
extends RefCounted
## Price rules. MVP: an item sells for its base value. This is the single place where the modifier
## stack (season, supply, war tension, relationship — TECHNICAL_DESIGN.md §8) will be applied later.

static func sell_price(item: ItemData, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return 0
	return item.base_value * quantity
