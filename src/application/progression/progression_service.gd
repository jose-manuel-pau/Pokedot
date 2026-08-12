class_name ProgressionService
extends RefCounted
## Owns experience mutation, multi-level growth, HP preservation, and move
## unlocks. Full movesets return pending choices rather than deleting a move.

var _catalog: ContentCatalog
var _experience := ExperienceCalculator.new()
var _stats := StatCalculator.new()


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func grant_experience(
	creature: CreatureInstance,
	amount: int
) -> ProgressionResult:
	var result := ProgressionResult.new()
	if creature == null:
		result.reason = &"missing_creature"
		return result
	result.instance_id = creature.instance_id
	if amount <= 0:
		result.reason = &"invalid_experience_amount"
		return result
	var species := _catalog.get_species(creature.species_id)
	if species == null:
		result.reason = &"unknown_species"
		return result
	var curve := _catalog.get_growth_curve(species.growth_curve_id)
	if curve == null:
		result.reason = &"unknown_growth_curve"
		return result
	var old_level := clampi(creature.level, 1, curve.max_level)
	creature.level = old_level
	var level_floor := _experience.total_experience_for_level(curve, old_level)
	var normalized_total := maxi(creature.total_experience, level_floor)
	var maximum_total := _experience.total_experience_for_level(curve, curve.max_level)
	if normalized_total >= maximum_total:
		result.reason = &"max_level_reached"
		return result

	result.success = true
	result.old_level = old_level
	result.total_experience_before = normalized_total
	result.stats_before = _stats.calculate_for_instance(species, creature)
	result.experience_gained = mini(amount, maximum_total - normalized_total)
	creature.total_experience = normalized_total + result.experience_gained
	creature.level = maxi(
		old_level,
		_experience.level_for_total_experience(curve, creature.total_experience)
	)
	result.new_level = creature.level
	result.total_experience_after = creature.total_experience
	result.stats_after = _stats.calculate_for_instance(species, creature)
	if creature.current_hp > 0:
		result.hp_gained = maxi(result.stats_after.hp - result.stats_before.hp, 0)
		creature.current_hp = mini(
			creature.current_hp + result.hp_gained,
			result.stats_after.hp
		)
	_resolve_unlocked_moves(creature, species, old_level, creature.level, result)
	return result


func resolve_move_learning(
	creature: CreatureInstance,
	new_move_id: StringName,
	forgotten_move_id: StringName = &""
) -> MoveLearningResult:
	var result := MoveLearningResult.new()
	if creature == null:
		result.reason = &"missing_creature"
		return result
	var species := _catalog.get_species(creature.species_id)
	if species == null:
		result.reason = &"unknown_species"
		return result
	if _catalog.get_move(new_move_id) == null \
		or not species.available_moves_at_level(creature.level).has(new_move_id):
		result.reason = &"move_not_available"
		return result
	if creature.learned_move_ids.has(new_move_id):
		result.reason = &"move_already_learned"
		return result
	if creature.learned_move_ids.size() < BattleParticipant.MAX_ACTIVE_MOVES:
		creature.learned_move_ids.append(new_move_id)
		result.success = true
		result.learned_move_id = new_move_id
		return result
	if str(forgotten_move_id).is_empty():
		result.success = true
		result.declined = true
		return result
	var index := creature.learned_move_ids.find(forgotten_move_id)
	if index < 0:
		result.reason = &"move_to_forget_not_learned"
		return result
	creature.learned_move_ids[index] = new_move_id
	result.success = true
	result.learned_move_id = new_move_id
	result.forgotten_move_id = forgotten_move_id
	return result


func _resolve_unlocked_moves(
	creature: CreatureInstance,
	species: CreatureSpeciesDefinition,
	old_level: int,
	new_level: int,
	result: ProgressionResult
) -> void:
	for entry in species.learnset:
		if entry.level <= old_level or entry.level > new_level:
			continue
		if creature.learned_move_ids.has(entry.move_id):
			continue
		if creature.learned_move_ids.size() < BattleParticipant.MAX_ACTIVE_MOVES:
			creature.learned_move_ids.append(entry.move_id)
			result.learned_move_ids.append(entry.move_id)
		else:
			result.pending_move_ids.append(entry.move_id)
