class_name CreatureGiftService
extends RefCounted
## Creates a fully initialized creature from authored gift content and delegates
## party/storage placement to the shared collection service.

var _catalog: ContentCatalog
var _collection_service := CreatureCollectionService.new()


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func claim(
	definition: CreatureGiftDefinition,
	collection: CreatureCollection
) -> CreatureGiftClaimResult:
	var result := CreatureGiftClaimResult.new()
	if definition == null:
		result.reason = &"missing_creature_gift"
		return result
	if collection == null:
		result.reason = &"missing_collection"
		return result
	var species := _catalog.get_species(definition.species_id)
	if species == null:
		result.reason = &"unknown_gift_species"
		return result
	if definition.level < 1 or definition.level > 200:
		result.reason = &"invalid_gift_level"
		return result
	for party_creature in collection.party:
		if party_creature.species_id == definition.species_id:
			result.reason = &"gift_species_already_in_party"
			return result
	var creature := CreatureInstance.new()
	creature.instance_id = "gift-%s" % definition.gift_id
	creature.species_id = definition.species_id
	creature.level = definition.level
	creature.total_experience = ExperienceCalculator.new().total_experience_for_level(
		_catalog.get_growth_curve(species.growth_curve_id),
		definition.level
	)
	creature.learned_move_ids = species.available_moves_at_level(definition.level)
	creature.current_hp = StatCalculator.new().calculate_for_instance(
		species,
		creature
	).hp
	var added := _collection_service.add_captured(collection, creature)
	if not added.success:
		result.reason = added.reason
		return result
	result.success = true
	result.creature = creature
	result.destination = added.destination
	return result
