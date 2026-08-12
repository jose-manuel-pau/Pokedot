extends TestSuite

var catalog: ContentCatalog
var service: ProgressionService
var experience := ExperienceCalculator.new()


func _init() -> void:
	super("ProgressionService")
	catalog = BattleTestFactory.create_catalog()
	service = ProgressionService.new(catalog)


func run() -> void:
	_test_experience_without_level_up()
	_test_multi_level_growth_and_hp_preservation()
	_test_fainted_creature_stays_fainted()
	_test_open_move_slot_learns_automatically()
	_test_full_moveset_creates_pending_choice()
	_test_move_learning_resolution()
	_test_invalid_and_max_level_awards()


func _creature(
	level: int,
	moves: Array[StringName],
	hp: int = 99999
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(&"cindermite", level, moves, hp)
	creature.total_experience = experience.total_experience_for_level(
		catalog.get_growth_curve(&"standard"), level
	)
	return creature


func _xp_to_level(level: int) -> int:
	return experience.total_experience_for_level(
		catalog.get_growth_curve(&"standard"), level
	)


func _test_experience_without_level_up() -> void:
	begin_case("experience without level")
	var creature := _creature(5, [&"cinder_jab", &"stonepulse"])
	var before := creature.total_experience
	var result := service.grant_experience(creature, 10)
	assert_true(result.success)
	assert_equal(result.old_level, 5)
	assert_equal(result.new_level, 5)
	assert_equal(result.levels_gained(), 0)
	assert_equal(result.experience_gained, 10)
	assert_equal(creature.total_experience, before + 10)
	assert_equal(result.hp_gained, 0)


func _test_multi_level_growth_and_hp_preservation() -> void:
	begin_case("multi-level growth")
	var creature := _creature(4, [&"cinder_jab"], 10)
	var amount := _xp_to_level(9) - creature.total_experience
	var result := service.grant_experience(creature, amount)
	assert_true(result.success)
	assert_equal(result.old_level, 4)
	assert_equal(result.new_level, 9)
	assert_equal(result.levels_gained(), 5)
	assert_true(result.stats_after.hp > result.stats_before.hp)
	assert_equal(result.hp_gained, result.stats_after.hp - result.stats_before.hp)
	assert_equal(creature.current_hp, 10 + result.hp_gained)
	assert_equal(result.learned_move_ids, [&"stonepulse", &"ember_haze"])


func _test_fainted_creature_stays_fainted() -> void:
	begin_case("fainted growth")
	var creature := _creature(4, [&"cinder_jab"], 0)
	var result := service.grant_experience(
		creature, _xp_to_level(5) - creature.total_experience
	)
	assert_equal(result.new_level, 5)
	assert_equal(result.hp_gained, 0)
	assert_equal(creature.current_hp, 0)


func _test_open_move_slot_learns_automatically() -> void:
	begin_case("automatic move learning")
	var creature := _creature(4, [&"cinder_jab"])
	var result := service.grant_experience(
		creature, _xp_to_level(5) - creature.total_experience
	)
	assert_equal(result.learned_move_ids, [&"stonepulse"])
	assert_equal(result.pending_move_ids, [])
	assert_equal(creature.learned_move_ids, [&"cinder_jab", &"stonepulse"])


func _test_full_moveset_creates_pending_choice() -> void:
	begin_case("pending move choice")
	var creature := _creature(4, [
		&"cinder_jab", &"brook_bash", &"thorn_lance", &"updraft",
	])
	var result := service.grant_experience(
		creature, _xp_to_level(5) - creature.total_experience
	)
	assert_equal(result.learned_move_ids, [])
	assert_equal(result.pending_move_ids, [&"stonepulse"])
	assert_false(creature.learned_move_ids.has(&"stonepulse"))
	assert_equal(creature.learned_move_ids.size(), 4)


func _test_move_learning_resolution() -> void:
	begin_case("move replacement and decline")
	var full := _creature(5, [
		&"cinder_jab", &"brook_bash", &"thorn_lance", &"updraft",
	])
	var declined := service.resolve_move_learning(full, &"stonepulse")
	assert_true(declined.success)
	assert_true(declined.declined)
	assert_false(full.learned_move_ids.has(&"stonepulse"))
	assert_equal(
		service.resolve_move_learning(full, &"stonepulse", &"missing").reason,
		&"move_to_forget_not_learned"
	)
	var replaced := service.resolve_move_learning(full, &"stonepulse", &"brook_bash")
	assert_true(replaced.success)
	assert_equal(replaced.forgotten_move_id, &"brook_bash")
	assert_true(full.learned_move_ids.has(&"stonepulse"))
	assert_false(full.learned_move_ids.has(&"brook_bash"))
	assert_equal(service.resolve_move_learning(full, &"stonepulse").reason, &"move_already_learned")
	assert_equal(service.resolve_move_learning(full, &"lull_mist").reason, &"move_not_available")

	var open := _creature(5, [&"cinder_jab"])
	assert_true(service.resolve_move_learning(open, &"stonepulse").success)
	assert_true(open.learned_move_ids.has(&"stonepulse"))


func _test_invalid_and_max_level_awards() -> void:
	begin_case("award boundaries")
	assert_equal(service.grant_experience(null, 5).reason, &"missing_creature")
	var creature := _creature(5, [&"cinder_jab"])
	assert_equal(service.grant_experience(creature, 0).reason, &"invalid_experience_amount")
	creature.species_id = &"missing"
	assert_equal(service.grant_experience(creature, 5).reason, &"unknown_species")
	var max_level := catalog.get_growth_curve(&"standard").max_level
	var maximum := _creature(max_level, [&"cinder_jab"])
	assert_equal(service.grant_experience(maximum, 999).reason, &"max_level_reached")
