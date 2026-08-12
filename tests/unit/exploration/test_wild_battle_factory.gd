extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("WildBattleFactory")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_valid_transition_starts_wild_battle()
	_test_request_validation()
	_test_battle_start_failure_is_forwarded()


func _request(species_id: StringName = &"gustlet", level: int = 5) -> WildEncounterRequest:
	var request := WildEncounterRequest.new()
	request.encounter_id = "map_zone_1"
	request.map_id = &"mosslight_crossing"
	request.zone_id = &"sunmeadow_grass"
	request.grid_position = Vector2i(5, 8)
	request.species_id = species_id
	request.level = level
	return request


func _party() -> Array[CreatureInstance]:
	return [BattleTestFactory.create_creature(
		&"cindermite", 8, [&"cinder_jab", &"stonepulse"]
	)]


func _test_valid_transition_starts_wild_battle() -> void:
	begin_case("wild battle creation")
	var result := WildBattleFactory.new(catalog).create(
		_request(), _party(), Inventory.new(), CreatureCollection.new()
	)
	assert_true(result.success)
	assert_not_null(result.battle_manager)
	assert_true(result.battle_manager.is_wild_encounter)
	assert_equal(result.battle_manager.phase, BattleConstants.PHASE_AWAITING_COMMANDS)
	assert_equal(result.wild_creature.instance_id, "map_zone_1")
	assert_equal(result.wild_creature.species_id, &"gustlet")
	assert_equal(result.wild_creature.level, 5)
	assert_equal(
		result.wild_creature.total_experience,
		ExperienceCalculator.new().total_experience_for_level(
			catalog.get_growth_curve(&"patient"), 5
		)
	)
	assert_equal(result.wild_creature.learned_move_ids, [&"updraft"])
	assert_equal(result.battle_manager.get_participant(&"opponent").creature, result.wild_creature)


func _test_request_validation() -> void:
	begin_case("request validation")
	var factory := WildBattleFactory.new(catalog)
	assert_equal(factory.create(null, _party(), Inventory.new(), CreatureCollection.new()).reason, &"missing_encounter_request")
	assert_equal(factory.create(_request(&"missing"), _party(), Inventory.new(), CreatureCollection.new()).reason, &"unknown_encounter_species")
	assert_equal(factory.create(_request(&"gustlet", 0), _party(), Inventory.new(), CreatureCollection.new()).reason, &"invalid_encounter_level")


func _test_battle_start_failure_is_forwarded() -> void:
	begin_case("battle start failure")
	var result := WildBattleFactory.new(catalog).create(
		_request(), [], Inventory.new(), CreatureCollection.new()
	)
	assert_false(result.success)
	assert_equal(result.reason, &"missing_creature")
