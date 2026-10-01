class_name Shop
extends RefCounted
## Buying from a shop with the player's existing money into the existing inventory.


## Buys `quantity` of `item_id`. All-or-nothing. Returns {"ok", "message"}.
static func buy(player: PlayerState, shop: ShopData, item_id: StringName, quantity: int, content: Object) -> Dictionary:
	var offer := shop.get_offer(item_id)
	var item: ItemData = content.get_item(item_id)
	if offer == null or item == null or quantity <= 0:
		return {"ok": false, "message": "That isn't for sale here."}
	var cost := offer.price * quantity
	if cost > player.money:
		return {"ok": false, "message": "Not enough marks (%d needed)." % cost}
	if player.inventory.space_for(item_id) < quantity:
		return {"ok": false, "message": "Your bag is full."}
	player.spend_money(cost)
	player.inventory.add(item_id, quantity)
	return {"ok": true, "message": "Bought %d %s for %d marks." % [quantity, item.display_name, cost]}
