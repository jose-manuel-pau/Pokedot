extends TestSuite

var catalog: ContentCatalog
var calculator := ExperienceRewardCalculator.new()


func _init() -> void:
	super("ExperienceRewardCalculator")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_wild_reward_formula()
	_test_trainer_reward_formula()
	_test_invalid_reward_inputs()


func _test_wild_reward_formula() -> void:
	begin_case("wild reward")
	assert_equal(calculator.calculate(catalog.get_species(&"gustlet"), 5), 60)
	assert_equal(calculator.calculate(catalog.get_species(&"cindermite"), 1), 12)


func _test_trainer_reward_formula() -> void:
	begin_case("trainer premium")
	assert_equal(calculator.calculate(catalog.get_species(&"gustlet"), 5, true), 75)
	assert_true(
		calculator.calculate(catalog.get_species(&"reedling"), 8, true) \
		> calculator.calculate(catalog.get_species(&"reedling"), 8, false)
	)


func _test_invalid_reward_inputs() -> void:
	begin_case("invalid reward")
	assert_equal(calculator.calculate(null, 5), 0)
	assert_equal(calculator.calculate(catalog.get_species(&"gustlet"), 0), 0)
