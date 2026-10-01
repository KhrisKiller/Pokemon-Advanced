extends TestCase
## The seed shop: data-driven offers, buying with the existing money into the existing inventory.

var player: PlayerState
var shop: ShopData


func before_each() -> void:
	player = PlayerState.new(load("res://data/config/new_game.tres"), ContentDB)
	shop = ContentDB.get_shop(&"seed_shop")


func test_seed_shop_sells_every_crop_seed() -> void:
	assert_not_null(shop)
	assert_eq(ContentDB.validate_shops(load(ContentDB.SHOP_CATALOG_PATH)), PackedStringArray())
	for crop_id in ContentDB.get_crop_ids():
		var offer := shop.get_offer(ContentDB.get_crop(crop_id).seed_item_id)
		assert_not_null(offer, "%s seeds for sale" % crop_id)
		assert_gt(offer.price, 0)


func test_buying_spends_money_and_adds_to_the_bag() -> void:
	player.add_money(100)
	var money := player.money
	var seeds := player.inventory.count(&"pipweed_seed")
	var price := shop.get_offer(&"pipweed_seed").price
	var result := Shop.buy(player, shop, &"pipweed_seed", 2, ContentDB)
	assert_true(result["ok"], result["message"])
	assert_eq(player.money, money - 2 * price)
	assert_eq(player.inventory.count(&"pipweed_seed"), seeds + 2)


func test_not_enough_money_changes_nothing() -> void:
	player.spend_money(player.money)
	var result := Shop.buy(player, shop, &"emberroot_seed", 1, ContentDB)
	assert_false(result["ok"])
	assert_true(String(result["message"]).contains("Not enough"), result["message"])
	assert_eq(player.inventory.count(&"emberroot_seed"), 3)


func test_full_bag_keeps_the_money() -> void:
	player.add_money(1000)
	var small := PlayerState.new(NewGameConfig.new(), ContentDB)
	small.inventory = Inventory.new(1, ContentDB)
	small.add_money(1000)
	small.inventory.add(&"bluecap", 1)
	var result := Shop.buy(small, shop, &"pipweed_seed", 1, ContentDB)
	assert_false(result["ok"])
	assert_eq(result["message"], "Your bag is full.")
	assert_eq(small.money, 1000)


func test_items_not_offered_cannot_be_bought() -> void:
	player.add_money(1000)
	assert_false(Shop.buy(player, shop, &"bond_charm", 1, ContentDB)["ok"])
	assert_false(Shop.buy(player, shop, &"pipweed_seed", 0, ContentDB)["ok"])
	assert_false(Shop.buy(player, shop, &"nonsense", 1, ContentDB)["ok"])


func test_validation_catches_broken_shops() -> void:
	var bad := ShopData.new()
	bad.id = &"bad"
	var free := ShopOffer.new()
	free.item_id = &"pipweed_seed"
	free.price = 0
	var ghost := ShopOffer.new()
	ghost.item_id = &"ghost_seed"
	ghost.price = 5
	bad.offers = [free, ghost]
	var catalog := ShopCatalog.new()
	catalog.shops = [bad, bad]
	var problems := "\n".join(ContentDB.validate_shops(catalog))
	assert_true(problems.contains("bad: pipweed_seed has no price"), problems)
	assert_true(problems.contains("unknown item 'ghost_seed'"), problems)
	assert_true(problems.contains("duplicate"), problems)
