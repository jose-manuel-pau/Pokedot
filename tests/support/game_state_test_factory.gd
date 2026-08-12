class_name GameStateTestFactory
extends RefCounted


static func create_valid_state(catalog: ContentCatalog) -> PlayerGameState:
	var state := PlayerGameState.new()
	state.player_id = "player-001"
	state.player_name = "Aster"
	state.play_time_seconds = 732
	state.current_map_id = &"mosslight_crossing"
	state.player_position = Vector2i(2, 8)
	state.player_facing = Vector2i.RIGHT
	state.inventory = Inventory.new(12)
	var inventory_service := InventoryService.new(catalog)
	inventory_service.add(state.inventory, &"basic_capsule", 3)
	inventory_service.add(state.inventory, &"field_tonic", 2)
	inventory_service.add(state.inventory, &"survey_compass", 1)
	state.collection.party.append(_creature(catalog, &"cindermite", 8, "party-1"))
	state.collection.storage.append(_creature(catalog, &"reedling", 5, "storage-1"))
	state.collection.party[0].nickname = "Coal"
	state.collection.party[0].genetic_potential.hp = 5
	state.collection.party[0].training.attack = 10
	state.collection.party[0].aptitude_modifiers[&"attack"] = 1.1
	state.collection.party[0].persistent_status_ids.append(&"scorch")
	_update_hp(catalog, state.collection.party[0])
	return state


static func _creature(
	catalog: ContentCatalog,
	species_id: StringName,
	level: int,
	instance_id: String
) -> CreatureInstance:
	var species := catalog.get_species(species_id)
	var creature := CreatureInstance.new()
	creature.instance_id = instance_id
	creature.species_id = species_id
	creature.level = level
	creature.total_experience = ExperienceCalculator.new().total_experience_for_level(
		catalog.get_growth_curve(species.growth_curve_id), level
	)
	creature.learned_move_ids = species.available_moves_at_level(level)
	_update_hp(catalog, creature)
	return creature


static func _update_hp(catalog: ContentCatalog, creature: CreatureInstance) -> void:
	creature.current_hp = StatCalculator.new().calculate_for_instance(
		catalog.get_species(creature.species_id), creature
	).hp
