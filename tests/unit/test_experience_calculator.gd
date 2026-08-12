extends TestSuite

var calculator := ExperienceCalculator.new()
var curve := GrowthCurveDefinition.new()


func _init() -> void:
	super("ExperienceCalculator")
	curve.curve_id = &"test_standard"
	curve.max_level = 100
	curve.scale = 1.0
	curve.exponent = 3.0


func run() -> void:
	_test_level_thresholds()
	_test_reverse_level_lookup()
	_test_next_level_progress()
	_test_boundary_behavior()


func _test_level_thresholds() -> void:
	begin_case("total XP thresholds")
	assert_equal(calculator.total_experience_for_level(curve, 1), 0)
	assert_equal(calculator.total_experience_for_level(curve, 10), 999)


func _test_reverse_level_lookup() -> void:
	begin_case("XP to level lookup")
	assert_equal(calculator.level_for_total_experience(curve, 998), 9)
	assert_equal(calculator.level_for_total_experience(curve, 999), 10)
	assert_equal(calculator.level_for_total_experience(curve, 1329), 10)
	assert_equal(calculator.level_for_total_experience(curve, 1330), 11)


func _test_next_level_progress() -> void:
	begin_case("XP remaining")
	assert_equal(calculator.experience_to_next_level(curve, 999), 331)
	assert_equal(calculator.experience_to_next_level(curve, 1100), 230)


func _test_boundary_behavior() -> void:
	begin_case("level and XP bounds")
	assert_equal(calculator.total_experience_for_level(curve, -5), 0)
	assert_equal(calculator.level_for_total_experience(curve, -50), 1)
	var max_xp := calculator.total_experience_for_level(curve, curve.max_level)
	assert_equal(calculator.level_for_total_experience(curve, max_xp + 999999), 100)
	assert_equal(calculator.experience_to_next_level(curve, max_xp), 0)

