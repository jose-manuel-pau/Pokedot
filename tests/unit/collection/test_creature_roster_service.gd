extends TestSuite

var service := CreatureRosterService.new()


func _init() -> void:
	super("CreatureRosterService")


func run() -> void:
	_test_move_between_party_and_storage()
	_test_last_party_member_cannot_be_stored()
	_test_full_party_rejects_withdrawal()
	_test_party_reordering_changes_lead()
	_test_invalid_roster_requests_are_atomic()


func _creature(instance_id: String) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.instance_id = instance_id
	creature.species_id = &"cindermite"
	return creature


func _test_move_between_party_and_storage() -> void:
	begin_case("party storage transfer")
	var collection := CreatureCollection.new()
	var lead := _creature("lead")
	var reserve := _creature("reserve")
	collection.party = [lead, reserve]
	var stored := service.move_to_storage(collection, "reserve")
	assert_true(stored.success)
	assert_equal(stored.source, &"party")
	assert_equal(stored.destination, &"storage")
	assert_equal(collection.party, [lead])
	assert_equal(collection.storage, [reserve])
	var withdrawn := service.move_to_party(collection, "reserve")
	assert_true(withdrawn.success)
	assert_equal(withdrawn.party_index, 1)
	assert_equal(collection.party, [lead, reserve])
	assert_equal(collection.storage, [])


func _test_last_party_member_cannot_be_stored() -> void:
	begin_case("minimum party")
	var collection := CreatureCollection.new()
	collection.party.append(_creature("only"))
	var result := service.move_to_storage(collection, "only")
	assert_false(result.success)
	assert_equal(result.reason, &"party_requires_member")
	assert_equal(collection.party.size(), 1)
	assert_equal(collection.storage.size(), 0)


func _test_full_party_rejects_withdrawal() -> void:
	begin_case("party capacity")
	var collection := CreatureCollection.new()
	for index in CreatureCollection.MAX_PARTY_SIZE:
		collection.party.append(_creature("party-%d" % index))
	collection.storage.append(_creature("stored"))
	var result := service.move_to_party(collection, "stored")
	assert_false(result.success)
	assert_equal(result.reason, &"party_full")
	assert_equal(collection.party.size(), CreatureCollection.MAX_PARTY_SIZE)
	assert_equal(collection.storage.size(), 1)


func _test_party_reordering_changes_lead() -> void:
	begin_case("party ordering")
	var collection := CreatureCollection.new()
	var first := _creature("first")
	var second := _creature("second")
	var third := _creature("third")
	collection.party = [first, second, third]
	var result := service.reorder_party(collection, "third", 0)
	assert_true(result.success)
	assert_equal(result.party_index, 0)
	assert_equal(collection.party, [third, first, second])
	assert_equal(service.reorder_party(collection, "third", 0).reason, &"already_at_party_index")


func _test_invalid_roster_requests_are_atomic() -> void:
	begin_case("invalid roster request")
	var collection := CreatureCollection.new()
	var first := _creature("first")
	var stored := _creature("stored")
	collection.party.append(first)
	collection.storage.append(stored)
	assert_equal(service.move_to_party(collection, "missing").reason, &"creature_not_in_storage")
	assert_equal(service.move_to_storage(collection, "missing").reason, &"creature_not_in_party")
	assert_equal(service.reorder_party(collection, "first", 3).reason, &"invalid_party_index")
	assert_equal(service.move_to_party(null, "stored").reason, &"missing_collection")
	assert_equal(collection.party, [first])
	assert_equal(collection.storage, [stored])
