class_name KithCare
extends RefCounted
## Looking after an owned kith: feeding from the one shared inventory, and Trust.


## Food in the bag this species will eat: [{"item_id", "favourite": bool, "count"}], favourites first.
static func compatible_foods(species: KithData, inventory: Inventory, content: Object) -> Array[Dictionary]:
	var favourites: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for item_id in inventory.item_ids():
		var item: ItemData = content.get_item(item_id)
		if species.will_eat(item):
			var entry := {"item_id": item_id, "favourite": species.loves(item), "count": inventory.count(item_id)}
			(favourites if entry["favourite"] else others).append(entry)
	favourites.append_array(others)
	return favourites


static func can_eat_today(kith: KithState, config: KithConfig) -> bool:
	return kith.fed_today < config.feeds_per_day


## Feeds one `item_id` from `inventory`. Returns {"ok", "message", "gain"}. Nothing is consumed on
## failure (refused food, already fed today, item not in the bag).
static func feed(kith: KithState, species: KithData, item_id: StringName, inventory: Inventory, content: Object, config: KithConfig) -> Dictionary:
	var name := kith.get_display_name(species)
	var item: ItemData = content.get_item(item_id)
	if item == null or not inventory.has(item_id):
		return {"ok": false, "gain": 0, "message": "You don't have that."}
	if not species.will_eat(item):
		return {"ok": false, "gain": 0, "message": "%s sniffs the %s and turns away." % [name, item.display_name]}
	if not can_eat_today(kith, config):
		return {"ok": false, "gain": 0, "message": "%s is full. Try again tomorrow." % name}
	inventory.remove(item_id, 1)
	var loved := species.loves(item)
	var before := kith.trust
	kith.trust = mini(config.trust_max, kith.trust + (config.favourite_food_trust if loved else config.liked_food_trust))
	kith.fed_today += 1
	var gain := kith.trust - before
	var reaction := "loved the %s!" % item.display_name if loved else "ate the %s." % item.display_name
	return {"ok": true, "gain": gain, "message": "%s %s Trust +%d (%d, %s)." % [name, reaction, gain, kith.trust, config.trust_label(kith.trust)]}
