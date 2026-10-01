class_name ShopMenu
extends ListMenu
## Buy screen for one ShopData. Presentation only: buying is Shop.buy on the session's
## PlayerState (the one inventory and wallet).

const MODAL_ID := &"shop"

var _player: PlayerState
var _shop: ShopData
var _content: Object


func _init() -> void:
	super()
	modal_id = MODAL_ID


func bind(player: PlayerState, content: Object) -> void:
	_player = player
	_content = content


func open_shop(shop: ShopData, speaker: String = "") -> bool:
	if shop == null or _player == null:
		return false
	_shop = shop
	open_menu()
	set_message(shop.greeting if speaker == "" else "%s: %s" % [speaker, shop.greeting])
	return true


func buy_selected() -> void:
	var offer := _offer_at(get_selected())
	if offer == null:
		return
	var result := Shop.buy(_player, _shop, offer.item_id, 1, _content)
	set_message(result["message"])


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _shop == null:
		return rows
	_set_title("%s   —   %d marks" % [_shop.display_name, _player.money])
	for offer in _shop.offers:
		var item: ItemData = _content.get_item(offer.item_id)
		var item_name := item.display_name if item != null else String(offer.item_id)
		rows.append({"text": "%s   %d marks   (have %d)" % [item_name, offer.price, _player.inventory.count(offer.item_id)],
				"action": buy_selected})
	rows.append({"text": "Leave", "action": close_menu})
	_set_hint("[E] buy one   [Esc] leave")
	return rows


func _update_detail() -> void:
	var offer := _offer_at(get_selected())
	var item: ItemData = _content.get_item(offer.item_id) if offer != null and _content != null else null
	_set_detail(item.description if item != null else "")


func _offer_at(index: int) -> ShopOffer:
	if _shop == null or index < 0 or index >= _shop.offers.size():
		return null
	return _shop.offers[index]
