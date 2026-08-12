class_name CreatureRosterService
extends RefCounted
## Transactional party/storage organization. Party index zero is the default
## field and battle lead; a valid roster always retains at least one member.


func move_to_storage(
	collection: CreatureCollection,
	instance_id: String
) -> RosterChangeResult:
	var result := _base_result(instance_id)
	if collection == null:
		result.reason = &"missing_collection"
		return result
	var creature := _find(collection.party, instance_id)
	if creature == null:
		result.reason = &"creature_not_in_party"
		return result
	if collection.party.size() <= 1:
		result.reason = &"party_requires_member"
		return result
	collection.party.erase(creature)
	collection.storage.append(creature)
	result.success = true
	result.source = &"party"
	result.destination = &"storage"
	return result


func move_to_party(
	collection: CreatureCollection,
	instance_id: String
) -> RosterChangeResult:
	var result := _base_result(instance_id)
	if collection == null:
		result.reason = &"missing_collection"
		return result
	if collection.party.size() >= CreatureCollection.MAX_PARTY_SIZE:
		result.reason = &"party_full"
		return result
	var creature := _find(collection.storage, instance_id)
	if creature == null:
		result.reason = &"creature_not_in_storage"
		return result
	collection.storage.erase(creature)
	collection.party.append(creature)
	result.success = true
	result.source = &"storage"
	result.destination = &"party"
	result.party_index = collection.party.size() - 1
	return result


func reorder_party(
	collection: CreatureCollection,
	instance_id: String,
	target_index: int
) -> RosterChangeResult:
	var result := _base_result(instance_id)
	if collection == null:
		result.reason = &"missing_collection"
		return result
	if target_index < 0 or target_index >= collection.party.size():
		result.reason = &"invalid_party_index"
		return result
	var creature := _find(collection.party, instance_id)
	if creature == null:
		result.reason = &"creature_not_in_party"
		return result
	var current_index := collection.party.find(creature)
	if current_index == target_index:
		result.reason = &"already_at_party_index"
		return result
	collection.party.remove_at(current_index)
	collection.party.insert(target_index, creature)
	result.success = true
	result.source = &"party"
	result.destination = &"party"
	result.party_index = target_index
	return result


func _find(
	creatures: Array[CreatureInstance],
	instance_id: String
) -> CreatureInstance:
	for creature in creatures:
		if creature.instance_id == instance_id:
			return creature
	return null


func _base_result(instance_id: String) -> RosterChangeResult:
	var result := RosterChangeResult.new()
	result.instance_id = instance_id
	return result
