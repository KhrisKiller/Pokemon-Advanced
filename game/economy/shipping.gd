class_name Shipping
extends RefCounted
## Placeholder selling: turn every carried item with a sellable tag into money at Pricing prices.

const SELLABLE_TAG := &"crop"


## Sells everything tagged SELLABLE_TAG. Returns {"total": int, "sold": {item_id: quantity}}.
static func sell_all(player: PlayerState, content: Object) -> Dictionary:
	var sold := {}
	var total := 0
	for item_id in player.inventory.item_ids():
		var item: ItemData = content.get_item(item_id)
		if item == null or not item.has_tag(SELLABLE_TAG):
			continue
		var quantity := player.inventory.count(item_id)
		if player.inventory.remove(item_id, quantity):
			sold[item_id] = quantity
			total += Pricing.sell_price(item, quantity)
	player.add_money(total)
	return {"total": total, "sold": sold}
