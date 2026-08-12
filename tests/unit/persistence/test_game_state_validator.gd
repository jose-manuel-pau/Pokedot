extends TestSuite

var catalog: ContentCatalog
var validator: GameStateValidator


func _init() -> void:
	super("GameStateValidator")
	catalog = BattleTestFactory.create_catalog()
	validator = GameStateValidator.new(catalog)


func run() -> void:
	_test_valid_state_has_no_issues()
	_test_profile_and_exploration_rules()
	_test_inventory_rules()
	_test_collection_identity_rules()
	_test_creature_progression_rules()
	_test_creature_build_rules()


func _has(issues: Array[StringName], code: StringName) -> bool:
	return issues.has(code)


func _test_valid_state_has_no_issues() -> void:
	begin_case("valid aggregate")
	assert_equal(validator.validate(GameStateTestFactory.create_valid_state(catalog)), [])


func _test_profile_and_exploration_rules() -> void:
	begin_case("profile and exploration")
	var state := GameStateTestFactory.create_valid_state(catalog)
	state.player_id = ""
	state.player_name = " "
	state.play_time_seconds = -1
	state.current_map_id = &"missing"
	var issues := validator.validate(state)
	assert_true(_has(issues, &"missing_player_id"))
	assert_true(_has(issues, &"missing_player_name"))
	assert_true(_has(issues, &"invalid_play_time"))
	assert_true(_has(issues, &"unknown_save_map"))

	state = GameStateTestFactory.create_valid_state(catalog)
	state.player_position = Vector2i(0, 0)
	state.player_facing = Vector2i(1, 1)
	issues = validator.validate(state)
	assert_true(_has(issues, &"invalid_save_position"))
	assert_true(_has(issues, &"invalid_save_facing"))


func _test_inventory_rules() -> void:
	begin_case("inventory validation")
	var state := GameStateTestFactory.create_valid_state(catalog)
	state.inventory.max_slots = 1
	state.inventory.quantities_by_item_id[&"missing_item"] = 1
	state.inventory.quantities_by_item_id[&"prism_capsule"] = 99
	var issues := validator.validate(state)
	assert_true(_has(issues, &"save_inventory_over_capacity"))
	assert_true(_has(issues, &"unknown_save_item"))
	assert_true(_has(issues, &"invalid_save_item_quantity"))
	state.inventory.max_slots = 0
	assert_true(_has(validator.validate(state), &"invalid_save_slot_limit"))


func _test_collection_identity_rules() -> void:
	begin_case("collection validation")
	var state := GameStateTestFactory.create_valid_state(catalog)
	state.collection.storage[0].instance_id = state.collection.party[0].instance_id
	assert_true(_has(validator.validate(state), &"duplicate_save_instance_id"))
	state.collection.party.clear()
	assert_true(_has(validator.validate(state), &"empty_save_party"))


func _test_creature_progression_rules() -> void:
	begin_case("creature level and XP")
	var state := GameStateTestFactory.create_valid_state(catalog)
	var creature := state.collection.party[0]
	creature.total_experience = 0
	assert_true(_has(validator.validate(state), &"experience_below_saved_level"))
	creature.total_experience = ExperienceCalculator.new().total_experience_for_level(
		catalog.get_growth_curve(&"standard"), creature.level + 1
	)
	assert_true(_has(validator.validate(state), &"experience_above_saved_level"))
	creature.level = 0
	assert_true(_has(validator.validate(state), &"invalid_save_level"))

	state = GameStateTestFactory.create_valid_state(catalog)
	creature = state.collection.party[0]
	var curve := catalog.get_growth_curve(&"standard")
	creature.level = curve.max_level
	creature.total_experience = ExperienceCalculator.new().total_experience_for_level(
		curve, curve.max_level
	) + 1
	assert_true(_has(validator.validate(state), &"experience_above_saved_level"))


func _test_creature_build_rules() -> void:
	begin_case("creature build validation")
	var state := GameStateTestFactory.create_valid_state(catalog)
	var creature := state.collection.party[0]
	creature.current_hp = 99999
	creature.genetic_potential.hp = 21
	creature.training.attack = 201
	creature.aptitude_modifiers[&"attack"] = 2.0
	creature.learned_move_ids = [&"cinder_jab", &"cinder_jab", &"missing"]
	creature.persistent_status_ids = [&"rooted", &"rooted"]
	var issues := validator.validate(state)
	assert_true(_has(issues, &"invalid_save_hp"))
	assert_true(_has(issues, &"invalid_save_genetic_potential"))
	assert_true(_has(issues, &"invalid_save_training"))
	assert_true(_has(issues, &"invalid_save_aptitude"))
	assert_true(_has(issues, &"duplicate_saved_move"))
	assert_true(_has(issues, &"unavailable_saved_move"))
	assert_true(_has(issues, &"invalid_saved_status"))
	assert_true(_has(issues, &"duplicate_saved_status"))

	state = GameStateTestFactory.create_valid_state(catalog)
	creature = state.collection.party[0]
	creature.genetic_potential = null
	creature.training = null
	issues = validator.validate(state)
	assert_true(_has(issues, &"invalid_save_genetic_potential"))
	assert_true(_has(issues, &"invalid_save_training"))
