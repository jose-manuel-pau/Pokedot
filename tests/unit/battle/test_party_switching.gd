extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("PartySwitching")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_party_validation()
	_test_manual_switch_resolves_before_attack()
	_test_switch_command_validation()
	_test_manual_switch_preserves_persistent_status()
	_test_forced_switch_clears_volatile_status()
	_test_knockout_uses_bench_before_battle_ends()


func _creature(
	species_id: StringName,
	moves: Array[StringName],
	hp: int = 99999,
	instance_suffix: String = ""
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, 20, moves, hp)
	if not instance_suffix.is_empty():
		creature.instance_id += "-" + instance_suffix
	return creature


func _typed_party(creatures: Array[CreatureInstance]) -> Array[CreatureInstance]:
	return creatures


func _test_party_validation() -> void:
	begin_case("party constraints")
	var oversized: Array[CreatureInstance] = []
	for index in 7:
		oversized.append(_creature(&"cindermite", [&"cinder_jab"], 99999, str(index)))
	var too_large := BattleManager.new(catalog)
	assert_false(too_large.start_party_battle(
		oversized,
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	))
	assert_equal(too_large.last_error, &"party_too_large")

	var duplicate := BattleManager.new(catalog)
	assert_false(duplicate.start_party_battle(
		_typed_party([
			_creature(&"cindermite", [&"cinder_jab"]),
			_creature(&"cindermite", [&"cinder_jab"]),
		]),
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	))
	assert_equal(duplicate.last_error, &"duplicate_instance_id")


func _test_manual_switch_resolves_before_attack() -> void:
	begin_case("manual switch priority")
	var outgoing := _creature(&"cindermite", [&"cinder_jab"])
	var incoming := _creature(&"reedling", [&"brook_bash"])
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_party_battle(
		_typed_party([outgoing, incoming]),
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	)
	var outgoing_hp := manager.get_participant(&"player").current_hp
	var incoming_max_hp := manager.get_party(&"player").members[1].current_hp
	manager.submit_command(SwitchCreatureCommand.new(&"player", incoming.instance_id))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.get_participant(&"player").creature.instance_id, incoming.instance_id)
	assert_equal(manager.get_party(&"player").members[0].current_hp, outgoing_hp)
	assert_true(manager.get_participant(&"player").current_hp < incoming_max_hp)
	var switches := manager.events_of_type(BattleConstants.EVENT_CREATURE_SWITCHED)
	assert_equal(switches.size(), 1)
	assert_false(switches[0].payload["forced"])


func _test_switch_command_validation() -> void:
	begin_case("switch validation")
	var active := _creature(&"cindermite", [&"cinder_jab"])
	var healthy := _creature(&"reedling", [&"brook_bash"])
	var defeated := _creature(&"gustlet", [&"updraft"], 0, "defeated")
	var manager := BattleManager.new(catalog)
	manager.start_party_battle(
		_typed_party([active, healthy, defeated]),
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	)
	assert_false(manager.submit_command(SwitchCreatureCommand.new(&"player", "")))
	assert_equal(manager.last_error, &"missing_switch_target")
	assert_false(manager.submit_command(SwitchCreatureCommand.new(&"player", active.instance_id)))
	assert_equal(manager.last_error, &"target_already_active")
	assert_false(manager.submit_command(SwitchCreatureCommand.new(&"player", "missing")))
	assert_equal(manager.last_error, &"unknown_switch_target")
	assert_false(manager.submit_command(SwitchCreatureCommand.new(&"player", defeated.instance_id)))
	assert_equal(manager.last_error, &"switch_target_defeated")
	manager.status_effect_service.apply_status(manager.get_participant(&"player"), &"rooted", 1)
	assert_false(manager.submit_command(SwitchCreatureCommand.new(&"player", healthy.instance_id)))
	assert_equal(manager.last_error, &"switch_blocked_by_status")


func _test_manual_switch_preserves_persistent_status() -> void:
	begin_case("persistent status on bench")
	var active := _creature(&"cindermite", [&"cinder_jab"])
	active.persistent_status_ids.append(&"scorch")
	var bench := _creature(&"reedling", [&"brook_bash"])
	var manager := BattleManager.new(catalog, FixedBattleRandomSource.new([0.0, 0.5, 1.0]))
	manager.start_party_battle(
		_typed_party([active, bench]),
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	)
	manager.submit_command(SwitchCreatureCommand.new(&"player", bench.instance_id))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	var outgoing := manager.get_party(&"player").members[0]
	assert_true(outgoing.has_status(&"scorch"))
	assert_true(outgoing.creature.persistent_status_ids.has(&"scorch"))
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_REMOVED).size(), 0)


func _test_forced_switch_clears_volatile_status() -> void:
	begin_case("forced switch cleanup")
	var active := _creature(&"cindermite", [&"cinder_jab"], 1)
	active.persistent_status_ids.append(&"scorch")
	var bench := _creature(&"reedling", [&"brook_bash"])
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_party_battle(
		_typed_party([active, bench]),
		_typed_party([_creature(&"gustlet", [&"updraft"])])
	)
	var outgoing := manager.get_participant(&"player")
	manager.status_effect_service.apply_status(outgoing, &"rooted", 1)
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.get_participant(&"player").creature.instance_id, bench.instance_id)
	assert_false(outgoing.has_status(&"rooted"))
	assert_true(outgoing.has_status(&"scorch"))
	var switches := manager.events_of_type(BattleConstants.EVENT_CREATURE_SWITCHED)
	assert_equal(switches.size(), 1)
	assert_true(switches[0].payload["forced"])
	var removals := manager.events_of_type(BattleConstants.EVENT_STATUS_REMOVED)
	assert_equal(removals.size(), 1)
	assert_equal(removals[0].payload["status_id"], &"rooted")


func _test_knockout_uses_bench_before_battle_ends() -> void:
	begin_case("party knockout progression")
	var manager := BattleManager.new(catalog, FixedBattleRandomSource.new([], 0.5))
	manager.start_party_battle(
		_typed_party([_creature(&"cindermite", [&"stonepulse"])]),
		_typed_party([
			_creature(&"gustlet", [&"updraft"], 1),
			_creature(&"reedling", [&"brook_bash"], 1),
		])
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"stonepulse"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.outcome, BattleConstants.OUTCOME_NONE)
	assert_equal(manager.phase, BattleConstants.PHASE_AWAITING_COMMANDS)
	assert_equal(manager.get_participant(&"opponent").species.species_id, &"reedling")
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CREATURE_SWITCHED).size(), 1)

	manager.submit_command(UseMoveCommand.new(&"player", &"stonepulse"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_equal(manager.outcome, BattleConstants.OUTCOME_PLAYER_VICTORY)
	assert_equal(manager.phase, BattleConstants.PHASE_FINISHED)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CREATURE_DEFEATED).size(), 2)

