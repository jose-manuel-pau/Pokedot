class_name GameStateValidator
extends RefCounted
## Validates a complete deserialized aggregate before it can replace live game
## state. Issues are stable codes suitable for tests and user-facing mapping.

var _catalog: ContentCatalog
var _experience := ExperienceCalculator.new()
var _stats := StatCalculator.new()


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func validate(state: PlayerGameState) -> Array[StringName]:
	var issues: Array[StringName] = []
	if state == null:
		issues.append(&"missing_game_state")
		return issues
	if state.player_id.strip_edges().is_empty():
		issues.append(&"missing_player_id")
	if state.player_name.strip_edges().is_empty():
		issues.append(&"missing_player_name")
	if state.play_time_seconds < 0:
		issues.append(&"invalid_play_time")
	_validate_exploration(state, issues)
	_validate_inventory(state.inventory, issues)
	_validate_collection(state.collection, issues)
	return issues


func _validate_exploration(
	state: PlayerGameState,
	issues: Array[StringName]
) -> void:
	var map := _catalog.get_map(state.current_map_id)
	if map == null:
		issues.append(&"unknown_save_map")
		return
	if not map.is_walkable(state.player_position) \
		or map.get_npc_at(state.player_position) != null:
		issues.append(&"invalid_save_position")
	if not ExplorationConstants.is_cardinal(state.player_facing):
		issues.append(&"invalid_save_facing")


func _validate_inventory(
	inventory: Inventory,
	issues: Array[StringName]
) -> void:
	if inventory == null:
		issues.append(&"missing_save_inventory")
		return
	if inventory.max_slots < 1:
		issues.append(&"invalid_save_slot_limit")
	if inventory.get_used_slots() > inventory.max_slots:
		issues.append(&"save_inventory_over_capacity")
	for raw_item_id in inventory.quantities_by_item_id.keys():
		var item_id := StringName(str(raw_item_id))
		var item := _catalog.get_item(item_id)
		if item == null:
			issues.append(&"unknown_save_item")
			continue
		var quantity := inventory.get_quantity(item_id)
		if quantity < 1 or quantity > item.max_stack:
			issues.append(&"invalid_save_item_quantity")


func _validate_collection(
	collection: CreatureCollection,
	issues: Array[StringName]
) -> void:
	if collection == null:
		issues.append(&"missing_save_collection")
		return
	if collection.party.size() > CreatureCollection.MAX_PARTY_SIZE:
		issues.append(&"save_party_too_large")
	if collection.party.is_empty():
		issues.append(&"empty_save_party")
	var seen_ids: Dictionary = {}
	for creature in collection.party:
		_validate_creature(creature, seen_ids, issues)
	for creature in collection.storage:
		_validate_creature(creature, seen_ids, issues)


func _validate_creature(
	creature: CreatureInstance,
	seen_ids: Dictionary,
	issues: Array[StringName]
) -> void:
	if creature == null:
		issues.append(&"missing_save_creature")
		return
	if creature.instance_id.is_empty():
		issues.append(&"missing_save_instance_id")
	elif seen_ids.has(creature.instance_id):
		issues.append(&"duplicate_save_instance_id")
	seen_ids[creature.instance_id] = true
	var species := _catalog.get_species(creature.species_id)
	if species == null:
		issues.append(&"unknown_save_species")
		return
	var curve := _catalog.get_growth_curve(species.growth_curve_id)
	if curve == null or creature.level < 1 or creature.level > curve.max_level:
		issues.append(&"invalid_save_level")
		return
	var minimum_xp := _experience.total_experience_for_level(curve, creature.level)
	if creature.total_experience < minimum_xp:
		issues.append(&"experience_below_saved_level")
	if creature.level < curve.max_level:
		var next_xp := _experience.total_experience_for_level(curve, creature.level + 1)
		if creature.total_experience >= next_xp:
			issues.append(&"experience_above_saved_level")
	elif creature.total_experience > minimum_xp:
		issues.append(&"experience_above_saved_level")
	if creature.genetic_potential != null and creature.training != null:
		var maximum_hp := _stats.calculate_for_instance(species, creature).hp
		if creature.current_hp < 0 or creature.current_hp > maximum_hp:
			issues.append(&"invalid_save_hp")
	if creature.genetic_potential == null:
		issues.append(&"invalid_save_genetic_potential")
	else:
		for stat_id in CreatureStats.STAT_IDS:
			var potential := creature.genetic_potential.get_value(stat_id)
			if potential < 0 or potential > StatCalculator.MAX_GENETIC_POTENTIAL:
				issues.append(&"invalid_save_genetic_potential")
				break
	if creature.training == null or not _stats.is_training_valid(creature.training):
		issues.append(&"invalid_save_training")
	for raw_stat_id in creature.aptitude_modifiers.keys():
		var stat_id := StringName(str(raw_stat_id))
		var value := float(creature.aptitude_modifiers[raw_stat_id])
		if stat_id not in CreatureStats.STAT_IDS \
			or value < StatCalculator.MIN_APTITUDE_MODIFIER \
			or value > StatCalculator.MAX_APTITUDE_MODIFIER:
			issues.append(&"invalid_save_aptitude")
			break
	_validate_saved_moves(creature, species, issues)
	_validate_saved_statuses(creature, issues)


func _validate_saved_moves(
	creature: CreatureInstance,
	species: CreatureSpeciesDefinition,
	issues: Array[StringName]
) -> void:
	if creature.learned_move_ids.is_empty() \
		or creature.learned_move_ids.size() > BattleParticipant.MAX_ACTIVE_MOVES:
		issues.append(&"invalid_saved_move_count")
	var available := species.available_moves_at_level(creature.level)
	var seen: Dictionary = {}
	for move_id in creature.learned_move_ids:
		if seen.has(move_id):
			issues.append(&"duplicate_saved_move")
		if _catalog.get_move(move_id) == null or not available.has(move_id):
			issues.append(&"unavailable_saved_move")
		seen[move_id] = true


func _validate_saved_statuses(
	creature: CreatureInstance,
	issues: Array[StringName]
) -> void:
	var seen: Dictionary = {}
	for status_id in creature.persistent_status_ids:
		var status := _catalog.get_status(status_id)
		if status == null or status.category != "persistent":
			issues.append(&"invalid_saved_status")
		if seen.has(status_id):
			issues.append(&"duplicate_saved_status")
		seen[status_id] = true
