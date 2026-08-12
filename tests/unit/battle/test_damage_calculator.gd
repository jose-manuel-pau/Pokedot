extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("DamageCalculator")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_physical_damage_formula()
	_test_special_stab_and_type_damage()
	_test_critical_damage()
	_test_accuracy_boundary_misses()
	_test_status_move_hits_without_damage()
	_test_zero_effectiveness_prevents_damage()


func _participant(
	side: StringName,
	species_id: StringName,
	move_ids: Array[StringName]
) -> BattleParticipant:
	return BattleTestFactory.create_participant(
		side,
		species_id,
		20,
		move_ids,
		catalog
	)


func _test_physical_damage_formula() -> void:
	begin_case("physical damage formula")
	var random := FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	var calculator := DamageCalculator.new(TypeEffectivenessService.new(catalog), random)
	var result := calculator.resolve(
		_participant(&"player", &"cindermite", [&"cinder_jab"]),
		_participant(&"opponent", &"gustlet", [&"updraft"]),
		catalog.get_move(&"cinder_jab")
	)
	assert_true(result.hit)
	assert_false(result.critical)
	assert_equal(result.damage, 19)
	assert_float_equal(result.same_type_bonus, 1.25)
	assert_float_equal(result.type_multiplier, 1.0)
	assert_equal(random.call_count, 3)


func _test_special_stab_and_type_damage() -> void:
	begin_case("special damage with STAB and weakness")
	var calculator := DamageCalculator.new(
		TypeEffectivenessService.new(catalog),
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	var result := calculator.resolve(
		_participant(&"player", &"cindermite", [&"stonepulse"]),
		_participant(&"opponent", &"gustlet", [&"updraft"]),
		catalog.get_move(&"stonepulse")
	)
	assert_true(result.hit)
	assert_equal(result.damage, 33)
	assert_float_equal(result.same_type_bonus, 1.25)
	assert_float_equal(result.type_multiplier, 2.0)


func _test_critical_damage() -> void:
	begin_case("critical modifier")
	var calculator := DamageCalculator.new(
		TypeEffectivenessService.new(catalog),
		FixedBattleRandomSource.new([0.0, 0.0, 1.0])
	)
	var result := calculator.resolve(
		_participant(&"player", &"cindermite", [&"cinder_jab"]),
		_participant(&"opponent", &"gustlet", [&"updraft"]),
		catalog.get_move(&"cinder_jab")
	)
	assert_true(result.critical)
	assert_equal(result.damage, 28)


func _test_accuracy_boundary_misses() -> void:
	begin_case("accuracy boundary")
	var random := FixedBattleRandomSource.new([0.95])
	var calculator := DamageCalculator.new(TypeEffectivenessService.new(catalog), random)
	var result := calculator.resolve(
		_participant(&"player", &"reedling", [&"brook_bash"]),
		_participant(&"opponent", &"cindermite", [&"cinder_jab"]),
		catalog.get_move(&"brook_bash")
	)
	assert_false(result.hit, "A roll equal to 95 accuracy must miss.")
	assert_equal(result.damage, 0)
	assert_equal(random.call_count, 1, "Misses must not roll critical or variance.")


func _test_status_move_hits_without_damage() -> void:
	begin_case("status move result")
	var random := FixedBattleRandomSource.new([0.1])
	var calculator := DamageCalculator.new(TypeEffectivenessService.new(catalog), random)
	var result := calculator.resolve(
		_participant(&"player", &"reedling", [&"lull_mist"]),
		_participant(&"opponent", &"cindermite", [&"cinder_jab"]),
		catalog.get_move(&"lull_mist")
	)
	assert_true(result.hit)
	assert_equal(result.damage, 0)
	assert_equal(random.call_count, 1)


func _test_zero_effectiveness_prevents_damage() -> void:
	begin_case("zero effectiveness")
	var tide := catalog.get_type(&"tide")
	tide.effectiveness[&"ember"] = 0.0
	var calculator := DamageCalculator.new(
		TypeEffectivenessService.new(catalog),
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	var result := calculator.resolve(
		_participant(&"player", &"reedling", [&"brook_bash"]),
		_participant(&"opponent", &"cindermite", [&"cinder_jab"]),
		catalog.get_move(&"brook_bash")
	)
	assert_true(result.hit)
	assert_float_equal(result.type_multiplier, 0.0)
	assert_equal(result.damage, 0)

