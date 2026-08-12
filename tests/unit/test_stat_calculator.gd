extends TestSuite

var calculator := StatCalculator.new()


func _init() -> void:
	super("StatCalculator")


func run() -> void:
	_test_known_hp_formula()
	_test_known_non_hp_formula()
	_test_instance_calculation()
	_test_input_bounds()
	_test_training_limits()


func _test_known_hp_formula() -> void:
	begin_case("known HP formula")
	assert_equal(calculator.calculate_stat(60, 20, 10, 50, true), 62)


func _test_known_non_hp_formula() -> void:
	begin_case("known non-HP formula and aptitude")
	assert_equal(calculator.calculate_stat(60, 20, 10, 50), 32)
	assert_equal(calculator.calculate_stat(60, 20, 10, 50, false, 1.1), 35)
	assert_equal(calculator.calculate_stat(60, 20, 10, 50, false, 0.9), 28)


func _test_instance_calculation() -> void:
	begin_case("full creature instance")
	var species := CreatureSpeciesDefinition.new()
	species.base_stats = CreatureStats.from_dictionary({
		"hp": 60,
		"attack": 60,
		"defense": 60,
		"special_attack": 60,
		"special_defense": 60,
		"speed": 60,
	})
	var creature := CreatureInstance.new()
	creature.level = 20
	creature.genetic_potential = CreatureStats.from_dictionary({
		"hp": 10,
		"attack": 10,
		"defense": 10,
		"special_attack": 10,
		"special_defense": 10,
		"speed": 10,
	})
	creature.training = CreatureStats.from_dictionary({
		"hp": 50,
		"attack": 50,
		"defense": 50,
		"special_attack": 50,
		"special_defense": 50,
		"speed": 50,
	})
	creature.aptitude_modifiers[&"speed"] = 1.1
	var calculated := calculator.calculate_for_instance(species, creature)
	assert_equal(calculated.hp, 62)
	assert_equal(calculated.attack, 32)
	assert_equal(calculated.speed, 35)


func _test_input_bounds() -> void:
	begin_case("invalid inputs are bounded")
	assert_equal(calculator.calculate_stat(-10, 0, -4, 999, true), 16)
	assert_equal(calculator.calculate_stat(-10, 0, -4, 999, false, 9.0), 7)


func _test_training_limits() -> void:
	begin_case("training allocation constraints")
	var valid := CreatureStats.from_dictionary({
		"hp": 100, "attack": 100, "defense": 100,
		"special_attack": 100, "special_defense": 50, "speed": 50,
	})
	assert_true(calculator.is_training_valid(valid))
	valid.speed = 51
	assert_false(calculator.is_training_valid(valid), "Total training above 500 should fail.")
	valid.speed = 0
	valid.attack = 201
	assert_false(calculator.is_training_valid(valid), "Per-stat training above 200 should fail.")

