class_name GameStateSerializer
extends RefCounted
## Converts the aggregate to JSON-compatible dictionaries and back. It performs
## no policy validation; GameStateValidator owns acceptance rules.


func to_dictionary(state: PlayerGameState) -> Dictionary:
	return {
		"schema_version": SaveGameMigrator.CURRENT_VERSION,
		"profile": {
			"player_id": state.player_id,
			"player_name": state.player_name,
		},
		"play_time_seconds": state.play_time_seconds,
		"exploration": {
			"map_id": str(state.current_map_id),
			"position": [state.player_position.x, state.player_position.y],
			"facing": [state.player_facing.x, state.player_facing.y],
		},
		"inventory": _inventory_to_dictionary(state.inventory),
		"collection": {
			"party": _creatures_to_array(state.collection.party),
			"storage": _creatures_to_array(state.collection.storage),
		},
	}


func from_dictionary(data: Dictionary) -> PlayerGameState:
	var state := PlayerGameState.new()
	var profile := _as_dictionary(data.get("profile", {}))
	state.player_id = str(profile.get("player_id", ""))
	state.player_name = str(profile.get("player_name", ""))
	state.play_time_seconds = int(data.get("play_time_seconds", -1))
	var exploration := _as_dictionary(data.get("exploration", {}))
	state.current_map_id = StringName(str(exploration.get("map_id", "")))
	state.player_position = _to_vector2i(exploration.get("position", []))
	state.player_facing = _to_vector2i(exploration.get("facing", []))
	state.inventory = _inventory_from_dictionary(
		_as_dictionary(data.get("inventory", {}))
	)
	var collection := _as_dictionary(data.get("collection", {}))
	state.collection.party = _creatures_from_array(collection.get("party", []))
	state.collection.storage = _creatures_from_array(collection.get("storage", []))
	return state


func _inventory_to_dictionary(inventory: Inventory) -> Dictionary:
	var quantities: Dictionary = {}
	for raw_item_id in inventory.quantities_by_item_id.keys():
		quantities[str(raw_item_id)] = inventory.get_quantity(raw_item_id)
	return {
		"max_slots": inventory.max_slots,
		"quantities": quantities,
	}


func _inventory_from_dictionary(data: Dictionary) -> Inventory:
	var inventory := Inventory.new()
	inventory.max_slots = int(data.get("max_slots", -1))
	var quantities := _as_dictionary(data.get("quantities", {}))
	for raw_item_id in quantities.keys():
		inventory.quantities_by_item_id[StringName(str(raw_item_id))] = int(
			quantities[raw_item_id]
		)
	return inventory


func _creatures_to_array(creatures: Array[CreatureInstance]) -> Array:
	var output: Array = []
	for creature in creatures:
		output.append(_creature_to_dictionary(creature))
	return output


func _creature_to_dictionary(creature: CreatureInstance) -> Dictionary:
	var aptitudes: Dictionary = {}
	for raw_stat_id in creature.aptitude_modifiers.keys():
		aptitudes[str(raw_stat_id)] = float(creature.aptitude_modifiers[raw_stat_id])
	return {
		"instance_id": creature.instance_id,
		"species_id": str(creature.species_id),
		"nickname": creature.nickname,
		"level": creature.level,
		"total_experience": creature.total_experience,
		"current_hp": creature.current_hp,
		"genetic_potential": creature.genetic_potential.to_dictionary(),
		"training": creature.training.to_dictionary(),
		"aptitude_modifiers": aptitudes,
		"learned_move_ids": _string_name_array_to_array(creature.learned_move_ids),
		"persistent_status_ids": _string_name_array_to_array(creature.persistent_status_ids),
	}


func _creatures_from_array(value: Variant) -> Array[CreatureInstance]:
	var creatures: Array[CreatureInstance] = []
	if not value is Array:
		return creatures
	for raw_creature in value:
		if raw_creature is Dictionary:
			creatures.append(_creature_from_dictionary(raw_creature))
	return creatures


func _creature_from_dictionary(data: Dictionary) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.instance_id = str(data.get("instance_id", ""))
	creature.species_id = StringName(str(data.get("species_id", "")))
	creature.nickname = str(data.get("nickname", ""))
	creature.level = int(data.get("level", 0))
	creature.total_experience = int(data.get("total_experience", -1))
	creature.current_hp = int(data.get("current_hp", -1))
	creature.genetic_potential = CreatureStats.from_dictionary(
		_as_dictionary(data.get("genetic_potential", {}))
	)
	creature.training = CreatureStats.from_dictionary(
		_as_dictionary(data.get("training", {}))
	)
	var aptitudes := _as_dictionary(data.get("aptitude_modifiers", {}))
	for raw_stat_id in aptitudes.keys():
		creature.aptitude_modifiers[StringName(str(raw_stat_id))] = float(
			aptitudes[raw_stat_id]
		)
	creature.learned_move_ids = _to_string_name_array(
		data.get("learned_move_ids", [])
	)
	creature.persistent_status_ids = _to_string_name_array(
		data.get("persistent_status_ids", [])
	)
	return creature


func _to_vector2i(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var output: Array[StringName] = []
	if value is Array:
		for item in value:
			output.append(StringName(str(item)))
	return output


func _string_name_array_to_array(value: Array[StringName]) -> Array:
	var output: Array = []
	for item in value:
		output.append(str(item))
	return output
