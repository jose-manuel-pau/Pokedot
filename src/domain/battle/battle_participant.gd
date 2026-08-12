class_name BattleParticipant
extends RefCounted
## Mutable battle projection for one creature. It owns battle-only move uses and
## synchronizes HP back to the underlying CreatureInstance.

const MAX_ACTIVE_MOVES := 4

var side: StringName
var species: CreatureSpeciesDefinition
var creature: CreatureInstance
var calculated_stats: CreatureStats
var current_hp: int
var move_slots_by_id: Dictionary = {}


static func from_instance(
	participant_side: StringName,
	species_definition: CreatureSpeciesDefinition,
	creature_instance: CreatureInstance,
	catalog: ContentCatalog,
	stat_calculator: StatCalculator
) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.side = participant_side
	participant.species = species_definition
	participant.creature = creature_instance
	participant.calculated_stats = stat_calculator.calculate_for_instance(
		species_definition,
		creature_instance
	)
	participant.current_hp = clampi(
		creature_instance.current_hp,
		0,
		participant.calculated_stats.hp
	)
	participant.creature.current_hp = participant.current_hp
	participant._initialize_move_slots(catalog)
	return participant


func get_max_hp() -> int:
	return calculated_stats.hp


func get_speed() -> int:
	return calculated_stats.speed


func is_defeated() -> bool:
	return current_hp <= 0


func apply_damage(requested_damage: int) -> int:
	var applied_damage := mini(maxi(requested_damage, 0), current_hp)
	current_hp -= applied_damage
	creature.current_hp = current_hp
	return applied_damage


func get_move_slot(move_id: StringName) -> BattleMoveSlot:
	return move_slots_by_id.get(move_id) as BattleMoveSlot


func _initialize_move_slots(catalog: ContentCatalog) -> void:
	move_slots_by_id.clear()
	var move_ids: Array[StringName] = []
	if creature.learned_move_ids.is_empty():
		move_ids = species.available_moves_at_level(creature.level)
	else:
		move_ids.assign(creature.learned_move_ids)

	var first_index := maxi(move_ids.size() - MAX_ACTIVE_MOVES, 0)
	for index in range(first_index, move_ids.size()):
		var move_id := move_ids[index]
		var definition := catalog.get_move(move_id)
		if definition != null and not move_slots_by_id.has(move_id):
			move_slots_by_id[move_id] = BattleMoveSlot.from_definition(definition)

