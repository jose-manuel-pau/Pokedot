class_name BattleTestFactory
extends RefCounted


static func create_catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


static func create_creature(
	species_id: StringName,
	level: int,
	move_ids: Array[StringName],
	current_hp: int = 99999
) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.instance_id = "%s-test" % species_id
	creature.species_id = species_id
	creature.level = level
	creature.current_hp = current_hp
	creature.learned_move_ids.assign(move_ids)
	return creature


static func create_participant(
	side: StringName,
	species_id: StringName,
	level: int,
	move_ids: Array[StringName],
	catalog: ContentCatalog,
	current_hp: int = 99999
) -> BattleParticipant:
	return BattleParticipant.from_instance(
		side,
		catalog.get_species(species_id),
		create_creature(species_id, level, move_ids, current_hp),
		catalog,
		StatCalculator.new()
	)

