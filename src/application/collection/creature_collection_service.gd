class_name CreatureCollectionService
extends RefCounted
## Inserts a captured creature into the first valid destination.


func add_captured(
	collection: CreatureCollection,
	creature: CreatureInstance
) -> CollectionAddResult:
	var result := CollectionAddResult.new()
	if collection == null:
		result.reason = &"missing_collection"
		return result
	if creature == null:
		result.reason = &"missing_creature"
		return result
	if creature.instance_id.is_empty():
		result.reason = &"missing_instance_id"
		return result
	if collection.contains_instance(creature.instance_id):
		result.reason = &"duplicate_instance_id"
		return result
	result.success = true
	if collection.party.size() < CreatureCollection.MAX_PARTY_SIZE:
		collection.party.append(creature)
		result.destination = CollectionAddResult.DESTINATION_PARTY
	else:
		collection.storage.append(creature)
		result.destination = CollectionAddResult.DESTINATION_STORAGE
	return result
