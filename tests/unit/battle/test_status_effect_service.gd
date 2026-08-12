extends TestSuite


func _init() -> void:
	super("StatusEffectService")


func run() -> void:
	_test_apply_remove_and_persistent_sync()
	_test_restore_persistent_statuses()
	_test_action_denial_hook()
	_test_speed_and_movement_hooks()
	_test_damage_hooks_and_end_turn_tick()
	_test_finite_duration_expiry()
	_test_volatile_clear_preserves_persistent()
	_test_stackable_status_composes_hooks()


func _context() -> Dictionary:
	var catalog := BattleTestFactory.create_catalog()
	var participant := BattleTestFactory.create_participant(
		BattleConstants.SIDE_PLAYER,
		&"cindermite",
		20,
		[&"cinder_jab", &"stonepulse"],
		catalog
	)
	return {
		"catalog": catalog,
		"participant": participant,
		"service": StatusEffectService.new(catalog),
	}


func _test_apply_remove_and_persistent_sync() -> void:
	begin_case("application and persistence sync")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	assert_equal(service.apply_status(participant, &"scorch", 1), &"applied")
	assert_true(participant.has_status(&"scorch"))
	assert_true(participant.creature.persistent_status_ids.has(&"scorch"))
	assert_equal(service.apply_status(participant, &"scorch", 1), &"already_applied")
	assert_equal(service.apply_status(participant, &"missing", 1), &"unknown_status")
	assert_true(service.remove_status(participant, &"scorch"))
	assert_false(participant.has_status(&"scorch"))
	assert_false(participant.creature.persistent_status_ids.has(&"scorch"))
	assert_false(service.remove_status(participant, &"scorch"))


func _test_restore_persistent_statuses() -> void:
	begin_case("persistent restore")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	participant.creature.persistent_status_ids = [&"drowsy", &"missing"]
	service.restore_persistent_statuses(participant)
	assert_true(participant.has_status(&"drowsy"))
	assert_false(participant.has_status(&"missing"))
	assert_equal(
		(participant.active_statuses_by_id[&"drowsy"] as BattleStatusInstance).remaining_turns,
		4
	)


func _test_action_denial_hook() -> void:
	begin_case("action denial")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	service.apply_status(participant, &"drowsy", 1)
	assert_false(service.can_act(participant))
	assert_equal(service.first_action_blocker(participant), &"drowsy")
	service.remove_status(participant, &"drowsy")
	assert_true(service.can_act(participant))
	assert_equal(service.first_action_blocker(participant), &"")


func _test_speed_and_movement_hooks() -> void:
	begin_case("rooted hooks")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	var normal_speed := participant.get_speed()
	service.apply_status(participant, &"rooted", 1)
	assert_equal(service.get_effective_speed(participant), maxi(floori(normal_speed * 0.5), 1))
	assert_false(service.can_switch(participant))
	assert_true(service.can_act(participant))


func _test_damage_hooks_and_end_turn_tick() -> void:
	begin_case("scorch damage hooks")
	var context := _context()
	var catalog := context["catalog"] as ContentCatalog
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	service.apply_status(participant, &"scorch", 1)
	assert_equal(
		service.modify_outgoing_damage(participant, catalog.get_move(&"cinder_jab"), 20),
		15
	)
	assert_equal(
		service.modify_outgoing_damage(participant, catalog.get_move(&"stonepulse"), 20),
		20
	)
	var starting_hp := participant.current_hp
	var expected_tick := maxi(floori(participant.get_max_hp() * 0.125), 1)
	var results := service.process_end_turn(participant, 1)
	assert_equal(results.size(), 1)
	assert_equal(results[0].damage, expected_tick)
	assert_equal(participant.current_hp, starting_hp - expected_tick)
	assert_false(results[0].removed)


func _test_finite_duration_expiry() -> void:
	begin_case("finite duration")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	service.apply_status(participant, &"drowsy", 1)
	for turn in range(1, 4):
		var results := service.process_end_turn(participant, turn)
		assert_false(results[0].removed)
		assert_true(participant.has_status(&"drowsy"))
	var final_results := service.process_end_turn(participant, 4)
	assert_true(final_results[0].removed)
	assert_false(participant.has_status(&"drowsy"))
	assert_false(participant.creature.persistent_status_ids.has(&"drowsy"))


func _test_volatile_clear_preserves_persistent() -> void:
	begin_case("switch cleanup")
	var context := _context()
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	service.apply_status(participant, &"rooted", 1)
	service.apply_status(participant, &"scorch", 1)
	var removed := service.clear_volatile_statuses(participant)
	assert_equal(removed, [&"rooted"])
	assert_false(participant.has_status(&"rooted"))
	assert_true(participant.has_status(&"scorch"))
	assert_true(participant.creature.persistent_status_ids.has(&"scorch"))


func _test_stackable_status_composes_hooks() -> void:
	begin_case("stacked hook composition")
	var context := _context()
	var catalog := context["catalog"] as ContentCatalog
	var participant := context["participant"] as BattleParticipant
	var service := context["service"] as StatusEffectService
	catalog.get_status(&"scorch").stackable = true
	assert_equal(service.apply_status(participant, &"scorch", 1), &"applied")
	assert_equal(service.apply_status(participant, &"scorch", 1), &"stacked")
	var status := participant.active_statuses_by_id[&"scorch"] as BattleStatusInstance
	assert_equal(status.stack_count, 2)
	assert_equal(
		service.modify_outgoing_damage(participant, catalog.get_move(&"cinder_jab"), 20),
		11
	)
	var expected_tick := maxi(floori(participant.get_max_hp() * 0.125), 1) * 2
	assert_equal(service.process_end_turn(participant, 1)[0].damage, expected_tick)

