extends TestSuite

var service := CreatureCollectionService.new()


func _init() -> void:
	super("CreatureCollectionService")


func run() -> void:
	_test_adds_to_party_when_space_exists()
	_test_routes_to_storage_when_party_is_full()
	_test_rejects_invalid_and_duplicate_creatures()


func _creature(instance_id: String) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.instance_id = instance_id
	creature.species_id = &"cindermite"
	return creature


func _test_adds_to_party_when_space_exists() -> void:
	begin_case("party insertion")
	var collection := CreatureCollection.new()
	var captured := _creature("captured-1")
	var result := service.add_captured(collection, captured)
	assert_true(result.success)
	assert_equal(result.destination, CollectionAddResult.DESTINATION_PARTY)
	assert_equal(collection.party, [captured])
	assert_true(collection.contains_instance("captured-1"))


func _test_routes_to_storage_when_party_is_full() -> void:
	begin_case("storage routing")
	var collection := CreatureCollection.new()
	for index in CreatureCollection.MAX_PARTY_SIZE:
		collection.party.append(_creature("party-%d" % index))
	var captured := _creature("captured-storage")
	var result := service.add_captured(collection, captured)
	assert_true(result.success)
	assert_equal(result.destination, CollectionAddResult.DESTINATION_STORAGE)
	assert_equal(collection.party.size(), CreatureCollection.MAX_PARTY_SIZE)
	assert_equal(collection.storage, [captured])


func _test_rejects_invalid_and_duplicate_creatures() -> void:
	begin_case("collection validation")
	var collection := CreatureCollection.new()
	assert_equal(service.add_captured(null, _creature("valid")).reason, &"missing_collection")
	assert_equal(service.add_captured(collection, null).reason, &"missing_creature")
	assert_equal(service.add_captured(collection, _creature("")).reason, &"missing_instance_id")
	assert_true(service.add_captured(collection, _creature("same-id")).success)
	var duplicate := service.add_captured(collection, _creature("same-id"))
	assert_false(duplicate.success)
	assert_equal(duplicate.reason, &"duplicate_instance_id")
