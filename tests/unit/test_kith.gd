extends TestCase
## Kith rules without a scene tree: species data and validation, KithState, the party
## (KithRoster), Trust and feeding (KithCare), wild bonding (KithBonding).

var config: KithConfig
var roster: KithRoster
var player: PlayerState
var world: Node


func before_each() -> void:
	config = load("res://data/config/kith_config.tres")
	roster = KithRoster.new(config, ContentDB)
	player = PlayerState.new(load("res://data/config/new_game.tres"), ContentDB)
	world = WorldState  # reset by the runner before every test


# --- species data ----------------------------------------------------------------------------

func test_prototype_species_are_valid_and_varied() -> void:
	var ids := ContentDB.get_kith_ids()
	assert_true(ids.size() >= 3 and ids.size() <= 5, "3–5 prototype kith (got %d)" % ids.size())
	assert_eq(ContentDB.validate_kith(load(ContentDB.KITH_CATALOG_PATH)), PackedStringArray())
	var waterers := 0
	var diets := {}
	for id in ids:
		var species := ContentDB.get_kith(id)
		assert_eq(species.id, id)
		if species.has_ability(KithHelpers.WATER):
			waterers += 1
		diets[str(species.favourite_food_tags) + str(species.liked_food_tags)] = true
	assert_gt(waterers, 0, "at least one kith can water")
	assert_gt(diets.size(), 1, "food preferences differ between species")


func test_food_preferences_come_from_tags() -> void:
	var rillet := ContentDB.get_kith(&"rillet")
	var sprigmole := ContentDB.get_kith(&"sprigmole")
	var bluecap := ContentDB.get_item(&"bluecap")
	var pipweed := ContentDB.get_item(&"pipweed")
	var seed := ContentDB.get_item(&"pipweed_seed")
	assert_true(rillet.loves(bluecap))
	assert_true(rillet.will_eat(pipweed), "liked (any food)")
	assert_false(rillet.loves(pipweed))
	assert_true(sprigmole.loves(pipweed))
	assert_false(sprigmole.will_eat(bluecap), "sprigmole only eats roots")
	assert_false(rillet.will_eat(seed), "seeds are not food")
	assert_false(rillet.will_eat(null))


func test_validation_catches_broken_species() -> void:
	var good := ContentDB.get_kith(&"rillet")
	var no_sprite := KithData.new()
	no_sprite.id = &"blank"
	no_sprite.display_name = "Blank"
	no_sprite.liked_food_tags = [&"food"]
	var picky := good.duplicate() as KithData
	picky.id = &"picky"
	picky.favourite_food_tags = [&"moonstone"]
	picky.liked_food_tags = []
	var dreamer := good.duplicate() as KithData
	dreamer.id = &"dreamer"
	dreamer.helper_abilities = [&"fly"]
	var catalog := KithCatalog.new()
	catalog.species = [good, good, no_sprite, picky, dreamer]
	var problems := "\n".join(ContentDB.validate_kith(catalog))
	assert_true(problems.contains("duplicate kith id 'rillet'"), problems)
	assert_true(problems.contains("blank: missing name or sprite"), problems)
	assert_true(problems.contains("picky: its diet matches no food item"), problems)
	assert_true(problems.contains("dreamer: unknown helper ability 'fly'"), problems)


func test_trust_labels_follow_thresholds() -> void:
	assert_eq(config.trust_label(0), "Unfamiliar")
	assert_eq(config.trust_label(24), "Unfamiliar")
	assert_eq(config.trust_label(25), "Friendly")
	assert_eq(config.trust_label(49), "Friendly")
	assert_eq(config.trust_label(50), "Trusted")
	assert_eq(config.trust_label(74), "Trusted")
	assert_eq(config.trust_label(75), "Bonded")
	assert_eq(config.trust_label(100), "Bonded")


# --- KithState -------------------------------------------------------------------------------

func test_state_round_trip_keeps_every_field() -> void:
	var kith := KithState.new(&"kith_0007", &"rillet")
	kith.nickname = "Puddle"
	kith.trust = 42
	kith.level = 3
	kith.xp = 17
	kith.fed_today = 1
	kith.helper_actions_today = 2
	kith.bonded_day = 9
	kith.origin = &"forest:50,12"
	var copy := KithState.from_dict(JSON.parse_string(JSON.stringify(kith.to_dict())))
	assert_eq(copy.to_dict(), kith.to_dict())


func test_state_from_bad_data_is_sane() -> void:
	var kith := KithState.from_dict({"uid": "kith_0001", "species_id": "rillet", "trust": -5, "level": 0})
	assert_eq(kith.trust, 0)
	assert_eq(kith.level, 1)
	assert_eq(kith.nickname, "")


func test_display_name_prefers_nickname() -> void:
	var species := ContentDB.get_kith(&"rillet")
	var kith := KithState.new(&"kith_0001", &"rillet")
	assert_eq(kith.get_display_name(species), "Rillet")
	kith.nickname = "Puddle"
	assert_eq(kith.get_display_name(species), "Puddle")


# --- the party -------------------------------------------------------------------------------

func test_new_kith_get_unique_ids_and_starting_trust() -> void:
	var a := roster.add_new(&"rillet", 3, &"forest:1,1")
	var b := roster.add_new(&"rillet")
	assert_ne(a.uid, b.uid, "two of the same species are different individuals")
	assert_eq(a.trust, config.starting_trust)
	assert_eq(a.bonded_day, 3)
	assert_eq(a.origin, &"forest:1,1")
	assert_eq(roster.active_uid, a.uid, "first kith becomes active")
	assert_eq(roster.size(), 2)


func test_unknown_species_is_refused() -> void:
	assert_eq(roster.add_new(&"griffin"), null)
	assert_eq(roster.size(), 0)


func test_party_is_capped_at_the_limit() -> void:
	for i in config.party_limit:
		assert_not_null(roster.add_new(&"bramblehog"))
	assert_true(roster.is_full())
	assert_eq(roster.add_new(&"bramblehog"), null, "seventh is refused")
	assert_eq(roster.size(), 6)


func test_select_active_and_reorder() -> void:
	var a := roster.add_new(&"rillet")
	var b := roster.add_new(&"sprigmole")
	var c := roster.add_new(&"cindercoot")
	assert_true(roster.set_active(b.uid))
	assert_eq(roster.get_active(), b)
	assert_false(roster.set_active(&"kith_9999"), "unknown uid")
	assert_eq(roster.get_active(), b)
	assert_true(roster.move(c.uid, 0))
	assert_eq(roster.get_members(), [c, a, b] as Array[KithState])
	assert_false(roster.move(c.uid, 5))


func test_removing_the_active_kith_picks_another() -> void:
	var a := roster.add_new(&"rillet")
	var b := roster.add_new(&"sprigmole")
	roster.remove(a.uid)
	assert_eq(roster.active_uid, b.uid)
	roster.remove(b.uid)
	assert_eq(roster.active_uid, &"")
	assert_eq(roster.get_active(), null)


func test_nicknames_are_trimmed_and_capped() -> void:
	var a := roster.add_new(&"rillet")
	assert_true(roster.set_nickname(a.uid, "  Puddle  "))
	assert_eq(a.nickname, "Puddle")
	roster.set_nickname(a.uid, "A very long name for a small kith")
	assert_eq(a.nickname.length(), 16)
	assert_false(roster.set_nickname(&"kith_9999", "x"))


func test_roster_save_round_trip() -> void:
	var a := roster.add_new(&"rillet", 2)
	var b := roster.add_new(&"sprigmole", 4)
	a.trust = 33
	roster.set_nickname(b.uid, "Digby")
	roster.set_active(b.uid)
	var restored := KithRoster.new(config, ContentDB)
	restored.load_save_data(JSON.parse_string(JSON.stringify(roster.to_save_data())))
	assert_eq(restored.size(), 2)
	assert_eq(restored.active_uid, b.uid)
	assert_eq(restored.get_kith(a.uid).trust, 33)
	assert_eq(restored.get_kith(b.uid).nickname, "Digby")
	assert_eq(restored.get_save_id(), &"kith")
	var c := restored.add_new(&"bramblehog")
	assert_ne(c.uid, a.uid)
	assert_ne(c.uid, b.uid)


func test_missing_section_gives_an_empty_party() -> void:
	roster.add_new(&"rillet")
	roster.load_save_data({})
	assert_eq(roster.size(), 0)
	assert_eq(roster.active_uid, &"")


func test_load_is_defensive() -> void:
	roster.load_save_data({"version": 1, "next_uid": 1, "active_uid": "kith_0042", "members": [
		{"uid": "kith_0005", "species_id": "rillet", "trust": 999},
		{"uid": "kith_0005", "species_id": "rillet"},  # duplicate uid
		{"uid": "kith_0006", "species_id": "dragon"},  # unknown species
		"garbage",
	]})
	assert_eq(roster.size(), 1)
	assert_eq(roster.get_kith(&"kith_0005").trust, config.trust_max, "trust clamped")
	assert_eq(roster.active_uid, &"kith_0005", "missing active falls back to the first member")
	assert_eq(roster.add_new(&"rillet").uid, &"kith_0007", "never reuses a saved id")


# --- feeding and Trust -----------------------------------------------------------------------

func test_feeding_a_favourite_consumes_one_and_raises_trust() -> void:
	var kith := roster.add_new(&"rillet")
	var species := roster.get_species(kith)
	player.inventory.add(&"bluecap", 2)
	var result := KithCare.feed(kith, species, &"bluecap", player.inventory, ContentDB, config)
	assert_true(result["ok"])
	assert_eq(result["gain"], config.favourite_food_trust)
	assert_eq(kith.trust, config.starting_trust + config.favourite_food_trust)
	assert_eq(player.inventory.count(&"bluecap"), 1, "one item consumed from the shared bag")
	assert_true(String(result["message"]).contains("loved"), result["message"])


func test_liked_food_gives_less_trust() -> void:
	var kith := roster.add_new(&"rillet")
	player.inventory.add(&"pipweed", 1)
	var result := KithCare.feed(kith, roster.get_species(kith), &"pipweed", player.inventory, ContentDB, config)
	assert_eq(result["gain"], config.liked_food_trust)
	assert_eq(player.inventory.count(&"pipweed"), 0)


func test_refused_food_is_not_consumed() -> void:
	var kith := roster.add_new(&"sprigmole")
	player.inventory.add(&"bluecap", 1)
	var result := KithCare.feed(kith, roster.get_species(kith), &"bluecap", player.inventory, ContentDB, config)
	assert_false(result["ok"])
	assert_eq(kith.trust, config.starting_trust)
	assert_eq(player.inventory.count(&"bluecap"), 1)
	assert_true(String(result["message"]).contains("turns away"), result["message"])


func test_one_feeding_per_day_then_reset_by_the_daily_tick() -> void:
	var kith := roster.add_new(&"sprigmole")
	player.inventory.add(&"pipweed", 3)
	assert_true(KithCare.feed(kith, roster.get_species(kith), &"pipweed", player.inventory, ContentDB, config)["ok"])
	var second := KithCare.feed(kith, roster.get_species(kith), &"pipweed", player.inventory, ContentDB, config)
	assert_false(second["ok"])
	assert_eq(player.inventory.count(&"pipweed"), 2, "nothing consumed when full")
	roster.start_new_day()
	assert_true(KithCare.feed(kith, roster.get_species(kith), &"pipweed", player.inventory, ContentDB, config)["ok"])


func test_trust_is_capped() -> void:
	var kith := roster.add_new(&"rillet")
	kith.trust = config.trust_max - 1
	player.inventory.add(&"bluecap", 1)
	var result := KithCare.feed(kith, roster.get_species(kith), &"bluecap", player.inventory, ContentDB, config)
	assert_eq(kith.trust, config.trust_max)
	assert_eq(result["gain"], 1)


func test_feeding_something_not_in_the_bag_fails() -> void:
	var kith := roster.add_new(&"rillet")
	assert_false(KithCare.feed(kith, roster.get_species(kith), &"bluecap", player.inventory, ContentDB, config)["ok"])


func test_compatible_foods_lists_favourites_first() -> void:
	player.inventory.add(&"pipweed", 2)
	player.inventory.add(&"bluecap", 1)
	var foods := KithCare.compatible_foods(ContentDB.get_kith(&"rillet"), player.inventory, ContentDB)
	assert_eq(foods.size(), 2)
	assert_eq(foods[0]["item_id"], &"bluecap")
	assert_true(foods[0]["favourite"])
	assert_eq(foods[1]["count"], 2)


# --- bonding a wild kith ---------------------------------------------------------------------

func _bond_step(species_id: StringName, spawn: StringName) -> Dictionary:
	return KithBonding.perform(ContentDB.get_kith(species_id), spawn, world, player, roster, config, ContentDB, 5)


func test_bonding_flow_food_then_charm() -> void:
	var spawn := &"forest:50,12"
	var rillet := ContentDB.get_kith(&"rillet")
	player.inventory.add(&"pipweed", 2)
	var charms := player.inventory.count(&"bond_charm")
	assert_eq(KithBonding.next_step(rillet, spawn, world), KithBonding.Step.OFFER_FOOD)
	assert_true(_bond_step(&"rillet", spawn)["ok"])  # liked food: +1 calm
	assert_eq(KithBonding.next_step(rillet, spawn, world), KithBonding.Step.OFFER_FOOD, "needs 2 calm")
	assert_true(_bond_step(&"rillet", spawn)["ok"])
	assert_eq(player.inventory.count(&"pipweed"), 0)
	assert_eq(KithBonding.next_step(rillet, spawn, world), KithBonding.Step.BOND)
	var result := _bond_step(&"rillet", spawn)
	assert_true(result["ok"], result["message"])
	var kith: KithState = result["kith"]
	assert_not_null(kith)
	assert_eq(kith.species_id, &"rillet")
	assert_eq(kith.origin, spawn)
	assert_eq(kith.bonded_day, 5)
	assert_eq(player.inventory.count(&"bond_charm"), charms - 1, "the charm is used up")
	assert_eq(roster.size(), 1)
	assert_eq(KithBonding.next_step(rillet, spawn, world), KithBonding.Step.GONE)
	assert_false(_bond_step(&"rillet", spawn)["ok"], "can't bond the same wild kith twice")
	assert_eq(roster.size(), 1)


func test_favourite_food_calms_faster() -> void:
	player.inventory.add(&"bluecap", 1)
	_bond_step(&"rillet", &"spot")
	assert_eq(KithBonding.get_calm(world, &"spot"), config.favourite_food_calm)
	assert_eq(player.inventory.count(&"bluecap"), 0)


func test_bonding_without_food_or_charm_changes_nothing() -> void:
	var result := _bond_step(&"sprigmole", &"spot")
	assert_false(result["ok"])
	assert_true(String(result["message"]).contains("root"), result["message"])
	WorldState.set_flag(KithBonding.calm_flag(&"spot"), 5)
	player.inventory.remove(&"bond_charm", player.inventory.count(&"bond_charm"))
	result = _bond_step(&"sprigmole", &"spot")
	assert_false(result["ok"])
	assert_true(String(result["message"]).contains("no Bond Charm"), result["message"])
	assert_eq(roster.size(), 0)
	assert_false(KithBonding.is_bonded(world, &"spot"))


func test_bonding_with_a_full_party_keeps_the_charm() -> void:
	for i in config.party_limit:
		roster.add_new(&"bramblehog")
	WorldState.set_flag(KithBonding.calm_flag(&"spot"), 5)
	var charms := player.inventory.count(&"bond_charm")
	var result := _bond_step(&"rillet", &"spot")
	assert_false(result["ok"])
	assert_true(String(result["message"]).contains("full"), result["message"])
	assert_eq(player.inventory.count(&"bond_charm"), charms)
	assert_false(KithBonding.is_bonded(world, &"spot"))
