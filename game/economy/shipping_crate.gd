class_name ShippingCrate
extends Interactable
## Placeholder produce buyer: sells every crop the player carries, immediately, at Pricing prices.
## (A real vendor, overnight shipping and price modifiers come with the economy epic.)

var _player: PlayerState


func _init() -> void:
	super()
	prompt = "Sell produce"
	add_to_group(GameSession.SESSION_AWARE_GROUP)


func bind_session(session: GameSession) -> void:
	_player = session.player


func can_interact(actor: Node) -> bool:
	return super(actor) and _player != null


func _on_interact(_actor: Node) -> void:
	var result := Shipping.sell_all(_player, ContentDB)
	EventBus.dialogue_requested.emit(PackedStringArray([describe_sale(result)]))


static func describe_sale(result: Dictionary) -> String:
	if result["sold"].is_empty():
		return "Nothing to sell. Harvested crops can be sold here."
	var parts := PackedStringArray()
	for item_id: StringName in result["sold"]:
		var item := ContentDB.get_item(item_id)
		parts.append("%d %s" % [result["sold"][item_id], item.display_name if item else String(item_id)])
	return "Sold %s for %d marks." % [", ".join(parts), result["total"]]
