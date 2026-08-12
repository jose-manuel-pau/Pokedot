class_name WildBattleFactory
extends RefCounted
## Anti-corruption boundary between exploration encounter data and the battle
## state machine. Presentation code receives a ready BattleManager.

var _catalog: ContentCatalog
var _battle_random: BattleRandomSource


func _init(
	catalog: ContentCatalog,
	battle_random_source: BattleRandomSource = null
) -> void:
	_catalog = catalog
	_battle_random = battle_random_source


func create(
	request: WildEncounterRequest,
	player_party: Array[CreatureInstance],
	inventory: Inventory,
	collection: CreatureCollection
) -> BattleTransitionResult:
	var result := BattleTransitionResult.new()
	if request == null:
		result.reason = &"missing_encounter_request"
		return result
	var species := _catalog.get_species(request.species_id)
	if species == null:
		result.reason = &"unknown_encounter_species"
		return result
	if request.level < 1 or request.level > 200:
		result.reason = &"invalid_encounter_level"
		return result
	var wild := CreatureInstance.new()
	wild.instance_id = request.encounter_id
	wild.species_id = request.species_id
	wild.level = request.level
	wild.total_experience = ExperienceCalculator.new().total_experience_for_level(
		_catalog.get_growth_curve(species.growth_curve_id),
		request.level
	)
	wild.current_hp = 999999
	wild.learned_move_ids = species.available_moves_at_level(request.level)
	var manager := BattleManager.new(_catalog, _battle_random)
	if not manager.start_wild_battle(player_party, wild, inventory, collection):
		result.reason = manager.last_error
		return result
	result.success = true
	result.battle_manager = manager
	result.wild_creature = wild
	return result
