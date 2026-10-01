class_name ShopData
extends Resource
## A shop (data/shops/<id>.tres): what it sells and for how much. No stock, no dynamic prices.

@export var id: StringName = &""
@export var display_name: String = ""
@export var greeting: String = ""
@export var offers: Array[ShopOffer] = []


func get_offer(item_id: StringName) -> ShopOffer:
	for offer in offers:
		if offer != null and offer.item_id == item_id:
			return offer
	return null
