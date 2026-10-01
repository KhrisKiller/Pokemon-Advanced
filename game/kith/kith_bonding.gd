class_name KithBonding
extends RefCounted
## Prototype bonding with a wild kith (no battles yet). Uses the approved "food path":
##   1. offer food it will eat (from the shared bag) until it is calm enough (KithData.bond_calm_needed);
##   2. offer a Bond Charm (an item) → a new KithState joins the party.
## Wild calm and "already bonded" are world facts, kept as WorldState flags so they persist.
## `world` is anything with has_flag / get_flag / set_flag (WorldState in the game).

enum Step { OFFER_FOOD, BOND, GONE }


static func calm_flag(spawn_id: StringName) -> StringName:
	return StringName("kith_calm:%s" % spawn_id)


static func bonded_flag(spawn_id: StringName) -> StringName:
	return StringName("kith_bonded:%s" % spawn_id)


static func is_bonded(world: Object, spawn_id: StringName) -> bool:
	return world.has_flag(bonded_flag(spawn_id))


static func get_calm(world: Object, spawn_id: StringName) -> int:
	return int(world.get_flag(calm_flag(spawn_id), 0))


static func next_step(species: KithData, spawn_id: StringName, world: Object) -> Step:
	if is_bonded(world, spawn_id):
		return Step.GONE
	if get_calm(world, spawn_id) >= species.bond_calm_needed:
		return Step.BOND
	return Step.OFFER_FOOD


static func prompt_for(step: Step) -> String:
	match step:
		Step.OFFER_FOOD:
			return "Offer food"
		Step.BOND:
			return "Offer a Bond Charm"
	return ""


## Performs the next step. Returns {"ok", "message", "kith": KithState or null}.
static func perform(species: KithData, spawn_id: StringName, world: Object, player: PlayerState,
		roster: KithRoster, config: KithConfig, content: Object, day: int) -> Dictionary:
	var name := species.display_name
	match next_step(species, spawn_id, world):
		Step.OFFER_FOOD:
			var foods := KithCare.compatible_foods(species, player.inventory, content)
			if foods.is_empty():
				return _result(false, "The %s sniffs your bag and backs away. It likes %s." % [name, _taste(species)])
			var food: Dictionary = foods[0]
			var item: ItemData = content.get_item(food["item_id"])
			player.inventory.remove(food["item_id"], 1)
			var calm := get_calm(world, spawn_id) + (config.favourite_food_calm if food["favourite"] else config.liked_food_calm)
			world.set_flag(calm_flag(spawn_id), calm)
			var message := "The %s eats the %s and looks calmer." % [name, item.display_name]
			if calm >= species.bond_calm_needed:
				message += " It might accept a Bond Charm now."
			return _result(true, message)
		Step.BOND:
			if roster.is_full():
				return _result(false, "Your party is full (%d kith)." % config.party_limit)
			if not player.inventory.has(config.bond_item_id):
				return _result(false, "The %s is calm, but you have no Bond Charm." % name)
			player.inventory.remove(config.bond_item_id, 1)
			var kith := roster.add_new(species.id, day, spawn_id)
			world.set_flag(bonded_flag(spawn_id))
			var result := _result(true, "The %s accepts the Bond Charm! %s joined your party." % [name, name])
			result["kith"] = kith
			return result
	return _result(false, "")


static func _taste(species: KithData) -> String:
	var tags := species.favourite_food_tags if not species.favourite_food_tags.is_empty() else species.liked_food_tags
	var words := PackedStringArray()
	for tag in tags:
		words.append(String(tag))
	return ", ".join(words) if not words.is_empty() else "something else"


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "kith": null}
