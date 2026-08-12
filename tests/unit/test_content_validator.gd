extends TestSuite


func _init() -> void:
	super("ContentValidator")


func run() -> void:
	_test_invalid_species_rules()
	_test_invalid_move_rules()
	_test_invalid_type_reference()
	_test_invalid_content_id()


func _fresh_catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


func _test_invalid_species_rules() -> void:
	begin_case("species constraints")
	var catalog := _fresh_catalog()
	var species := catalog.get_species(&"cindermite")
	species.catch_rate = 0
	species.base_stats.hp = 0
	species.element_types.append(&"missing_type")
	var unknown_move := LearnsetEntry.new()
	unknown_move.level = 101
	unknown_move.move_id = &"missing_move"
	species.learnset.append(unknown_move)
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_catch_rate")
	assert_has_issue(issues, &"invalid_base_stat")
	assert_has_issue(issues, &"invalid_species_type_count")
	assert_has_issue(issues, &"unknown_species_type")
	assert_has_issue(issues, &"invalid_learn_level")
	assert_has_issue(issues, &"unknown_learnset_move")


func _test_invalid_move_rules() -> void:
	begin_case("move constraints")
	var catalog := _fresh_catalog()
	var move := catalog.get_move(&"cinder_jab")
	move.element_type_id = &"missing_type"
	move.category = "status"
	move.accuracy = 0.0
	move.status_effect_id = &"missing_status"
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"unknown_move_type")
	assert_has_issue(issues, &"status_move_has_power")
	assert_has_issue(issues, &"invalid_accuracy")
	assert_has_issue(issues, &"unknown_status_reference")


func _test_invalid_type_reference() -> void:
	begin_case("type matrix constraints")
	var catalog := _fresh_catalog()
	var ember := catalog.get_type(&"ember")
	ember.effectiveness[&"missing_type"] = 9.0
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"unknown_type_reference")
	assert_has_issue(issues, &"invalid_effectiveness")


func _test_invalid_content_id() -> void:
	begin_case("stable content ID format")
	var catalog := _fresh_catalog()
	var type_definition := catalog.get_type(&"ember")
	catalog.types_by_id.erase(&"ember")
	type_definition.type_id = &"Ember-Type"
	catalog.types_by_id[type_definition.type_id] = type_definition
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_content_id")
