class_name FarmActions
extends RefCounted
## What "interact" does on a plot, given the farm, the player's belongings and content.
## Pure and context-sensitive (one button in the MVP; tools come later):
##   untilled → TILL · tilled & empty → PLANT (selected seed) · dry crop → WATER
##   watered growing crop → INSPECT · mature crop → HARVEST

enum Action { NONE, TILL, PLANT, WATER, INSPECT, HARVEST }

const PROMPTS := {
	Action.NONE: "", Action.TILL: "Till", Action.PLANT: "Plant", Action.WATER: "Water",
	Action.INSPECT: "Inspect", Action.HARVEST: "Harvest",
}


static func next_action(farm: FarmState, plot_id: StringName) -> Action:
	var plot := farm.ensure_plot(plot_id)
	if not plot.tilled:
		return Action.TILL
	if not plot.has_crop():
		return Action.PLANT
	if farm.is_mature(plot_id):
		return Action.HARVEST
	if not plot.watered:
		return Action.WATER
	return Action.INSPECT


static func prompt_for(farm: FarmState, player: PlayerState, plot_id: StringName) -> String:
	var action := next_action(farm, plot_id)
	if action == Action.PLANT and player != null and player.selected_seed != &"":
		var seed: ItemData = farm.content.get_item(player.selected_seed)
		return "Plant %s" % (seed.display_name if seed != null else "seed")
	return PROMPTS[action]


## Performs the next action. Returns {"action": Action, "ok": bool, "message": String}.
## `message` is empty when the action speaks for itself (till, water, plant).
static func perform(farm: FarmState, player: PlayerState, plot_id: StringName) -> Dictionary:
	var action := next_action(farm, plot_id)
	var plot := farm.get_plot(plot_id)
	match action:
		Action.TILL:
			return _result(action, farm.till(plot_id))
		Action.PLANT:
			var seed_id := player.selected_seed
			var crop: CropData = farm.content.get_crop_for_seed(seed_id) if seed_id != &"" else null
			if crop == null or not player.inventory.has(seed_id):
				return _result(action, false, "You have no seeds to plant.")
			player.inventory.remove(seed_id, 1)
			return _result(action, farm.plant(plot_id, crop))
		Action.WATER:
			return _result(action, farm.water(plot_id))
		Action.INSPECT:
			var crop := farm.get_crop_data(plot)
			var left := plot.crop.days_left(crop)
			return _result(action, true, "%s — watered today. Ready in %d more watered day%s." % [
					crop.display_name, left, "" if left == 1 else "s"])
		Action.HARVEST:
			var crop := farm.get_crop_data(plot)
			if player.inventory.space_for(crop.harvest_item_id) < crop.harvest_quantity:
				return _result(action, false, "Your bag is full.")
			var produce := farm.harvest(plot_id)
			player.inventory.add(produce["item_id"], produce["quantity"])
			var item: ItemData = farm.content.get_item(produce["item_id"])
			return _result(action, true, "Harvested %d %s." % [produce["quantity"], item.display_name if item else produce["item_id"]])
	return _result(Action.NONE, false)


static func _result(action: Action, ok: bool, message: String = "") -> Dictionary:
	return {"action": action, "ok": ok, "message": message}
