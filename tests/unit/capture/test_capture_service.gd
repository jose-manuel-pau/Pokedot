extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("CaptureService")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_hp_changes_capture_probability()
	_test_status_device_and_encounter_multipliers()
	_test_probability_is_clamped()
	_test_deterministic_success_and_critical()
	_test_invalid_capture_inputs_do_not_roll()


func _target(hp: int = 99999) -> BattleParticipant:
	return BattleTestFactory.create_participant(
		BattleConstants.SIDE_OPPONENT,
		&"cindermite",
		20,
		[&"cinder_jab"],
		catalog,
		hp
	)


func _test_hp_changes_capture_probability() -> void:
	begin_case("health multiplier")
	catalog.get_species(&"cindermite").catch_rate = 30
	var full := _target()
	var full_result := CaptureService.new(
		catalog,
		FixedBattleRandomSource.new([0.99, 0.99])
	).attempt(full, catalog.get_item(&"basic_capsule"))
	var half := _target(floori(full.get_max_hp() * 0.5))
	var half_result := CaptureService.new(
		catalog,
		FixedBattleRandomSource.new([0.99, 0.99])
	).attempt(half, catalog.get_item(&"basic_capsule"))
	assert_float_equal(full_result.health_multiplier, 1.0)
	assert_float_equal(full_result.chance, 30.0 / 255.0)
	assert_true(half_result.health_multiplier > full_result.health_multiplier)
	assert_true(half_result.chance > full_result.chance)


func _test_status_device_and_encounter_multipliers() -> void:
	begin_case("capture modifiers")
	catalog.get_species(&"cindermite").catch_rate = 30
	var target := _target()
	StatusEffectService.new(catalog).apply_status(target, &"drowsy", 1)
	var result := CaptureService.new(
		catalog,
		FixedBattleRandomSource.new([0.99, 0.99])
	).attempt(target, catalog.get_item(&"reinforced_capsule"), 0.5)
	assert_float_equal(result.status_multiplier, 1.6)
	assert_float_equal(result.device_multiplier, 1.5)
	assert_float_equal(result.encounter_multiplier, 0.5)
	assert_float_equal(result.chance, (30.0 / 255.0) * 1.6 * 1.5 * 0.5)


func _test_probability_is_clamped() -> void:
	begin_case("probability clamps")
	var target := _target(1)
	var service := CaptureService.new(catalog, FixedBattleRandomSource.new([0.5, 0.5]))
	assert_float_equal(
		service.attempt(target, catalog.get_item(&"prism_capsule"), 50.0).chance,
		CaptureService.MAX_CHANCE
	)
	assert_float_equal(
		service.attempt(target, catalog.get_item(&"basic_capsule"), 0.0).chance,
		CaptureService.MIN_CHANCE
	)


func _test_deterministic_success_and_critical() -> void:
	begin_case("deterministic rolls")
	catalog.get_species(&"cindermite").catch_rate = 30
	var random := FixedBattleRandomSource.new([0.1, 0.01, 0.9, 0.0])
	var service := CaptureService.new(catalog, random)
	var success := service.attempt(_target(), catalog.get_item(&"basic_capsule"))
	assert_true(success.success)
	assert_true(success.critical)
	assert_float_equal(success.success_roll, 0.1)
	assert_float_equal(success.critical_roll, 0.01)
	var failure := service.attempt(_target(), catalog.get_item(&"basic_capsule"))
	assert_false(failure.success)
	assert_false(failure.critical)
	assert_equal(random.call_count, 4)


func _test_invalid_capture_inputs_do_not_roll() -> void:
	begin_case("invalid capture inputs")
	var random := FixedBattleRandomSource.new()
	var service := CaptureService.new(catalog, random)
	assert_equal(service.attempt(null, catalog.get_item(&"basic_capsule")).reason, &"missing_capture_target")
	assert_equal(service.attempt(_target(), catalog.get_item(&"field_tonic")).reason, &"invalid_capture_device")
	assert_equal(service.attempt(_target(0), catalog.get_item(&"basic_capsule")).reason, &"capture_target_defeated")
	assert_equal(random.call_count, 0)
