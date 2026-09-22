extends TestSuite

var catalog: ContentCatalog
var service: CreatureGiftService
var gift: CreatureGiftDefinition


func _init() -> void:
	super("CreatureGiftService")
	catalog = BattleTestFactory.create_catalog()
	service = CreatureGiftService.new(catalog)
	gift = catalog.get_map(&"lumen_research_house").creature_gifts[0]


func run() -> void:
	_test_claim_initializes_creature_and_adds_to_party()
	_test_full_party_routes_gift_to_storage()
	_test_invalid_and_duplicate_claims_are_rejected()


func _test_claim_initializes_creature_and_adds_to_party() -> void:
	begin_case("initialized egg gift")
	var collection := CreatureCollection.new()
	var result := service.claim(gift, collection)
	assert_true(result.success)
	assert_equal(result.destination, CollectionAddResult.DESTINATION_PARTY)
	assert_not_null(result.creature)
	assert_equal(result.creature.instance_id, "gift-cindermite_egg")
	assert_equal(result.creature.species_id, &"cindermite")
	assert_equal(result.creature.level, 5)
	assert_true(result.creature.total_experience > 0)
	assert_true(result.creature.current_hp > 0)
	assert_true(not result.creature.learned_move_ids.is_empty())
	assert_equal(collection.party, [result.creature])


func _test_full_party_routes_gift_to_storage() -> void:
	begin_case("gift storage routing")
	var collection := CreatureCollection.new()
	for index in CreatureCollection.MAX_PARTY_SIZE:
		collection.party.append(BattleTestFactory.create_creature(
			&"reedling", 3, [&"reed_whip"]
		))
		collection.party[index].instance_id = "party-%d" % index
	var result := service.claim(gift, collection)
	assert_true(result.success)
	assert_equal(result.destination, CollectionAddResult.DESTINATION_STORAGE)
	assert_equal(collection.storage.size(), 1)


func _test_invalid_and_duplicate_claims_are_rejected() -> void:
	begin_case("gift validation")
	var collection := CreatureCollection.new()
	assert_equal(service.claim(null, collection).reason, &"missing_creature_gift")
	assert_equal(service.claim(gift, null).reason, &"missing_collection")
	var invalid := CreatureGiftDefinition.new()
	invalid.gift_id = &"invalid"
	invalid.species_id = &"missing_species"
	assert_equal(service.claim(invalid, collection).reason, &"unknown_gift_species")
	assert_true(service.claim(gift, collection).success)
	assert_equal(service.claim(gift, collection).reason, &"duplicate_instance_id")
