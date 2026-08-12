class_name CreatureCollection
extends RefCounted
## Player-owned creatures split into an active party and unlimited storage.

const MAX_PARTY_SIZE := 6

var party: Array[CreatureInstance] = []
var storage: Array[CreatureInstance] = []


func contains_instance(instance_id: String) -> bool:
	for creature in party:
		if creature.instance_id == instance_id:
			return true
	for creature in storage:
		if creature.instance_id == instance_id:
			return true
	return false


func get_all_creatures() -> Array[CreatureInstance]:
	var creatures: Array[CreatureInstance] = []
	creatures.append_array(party)
	creatures.append_array(storage)
	return creatures


func find_instance(instance_id: String) -> CreatureInstance:
	for creature in party:
		if creature.instance_id == instance_id:
			return creature
	for creature in storage:
		if creature.instance_id == instance_id:
			return creature
	return null


func get_location(instance_id: String) -> StringName:
	for creature in party:
		if creature.instance_id == instance_id:
			return &"party"
	for creature in storage:
		if creature.instance_id == instance_id:
			return &"storage"
	return &""
