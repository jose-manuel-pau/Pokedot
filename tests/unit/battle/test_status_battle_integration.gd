extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("StatusBattleIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_status_move_applies_and_blocks_later_action()
	_test_damaging_move_status_chance_succeeds()
	_test_damaging_move_status_chance_fails()
	_test_scorch_reduces_physical_battle_damage()
	_test_rooted_changes_next_turn_order()
	_test_end_turn_status_damage_can_finish_battle()


func _creature(
	species_id: StringName,
	moves: Array[StringName],
	hp: int = 99999
) -> CreatureInstance:
	return BattleTestFactory.create_creature(species_id, 20, moves, hp)


func _test_status_move_applies_and_blocks_later_action() -> void:
	begin_case("immediate action denial")
	var player := _creature(&"reedling", [&"lull_mist"])
	player.aptitude_modifiers[&"speed"] = 1.5
	var manager := BattleManager.new(catalog, FixedBattleRandomSource.new([0.0]))
	manager.start_battle(player, _creature(&"cindermite", [&"cinder_jab"]))
	manager.submit_command(UseMoveCommand.new(&"player", &"lull_mist"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"cinder_jab"))
	manager.resolve_turn()
	var opponent := manager.get_participant(&"opponent")
	assert_true(opponent.has_status(&"drowsy"))
	assert_equal(
		(opponent.active_statuses_by_id[&"drowsy"] as BattleStatusInstance).remaining_turns,
		3
	)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_APPLIED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_BLOCKED_ACTION).size(), 1)
	assert_equal(opponent.get_move_slot(&"cinder_jab").remaining_uses, 25)


func _test_damaging_move_status_chance_succeeds() -> void:
	begin_case("secondary status success")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0, 0.05, 0.0, 0.5, 1.0])
	)
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"reedling", [&"brook_bash"])
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_true(manager.get_participant(&"opponent").has_status(&"scorch"))
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_APPLIED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_DAMAGE).size(), 1)


func _test_damaging_move_status_chance_fails() -> void:
	begin_case("secondary status failure")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0, 0.5, 0.0, 0.5, 1.0])
	)
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"reedling", [&"brook_bash"])
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_false(manager.get_participant(&"opponent").has_status(&"scorch"))
	var failures := manager.events_of_type(BattleConstants.EVENT_STATUS_APPLICATION_FAILED)
	assert_equal(failures.size(), 1)
	assert_equal(failures[0].payload["reason"], &"chance_failed")


func _test_scorch_reduces_physical_battle_damage() -> void:
	begin_case("scorch outgoing damage penalty")
	var scorched_creature := _creature(&"cindermite", [&"cinder_jab"])
	scorched_creature.persistent_status_ids.append(&"scorch")
	var scorched := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0, 0.0, 0.5, 1.0, 0.5])
	)
	scorched.start_battle(scorched_creature, _creature(&"gustlet", [&"updraft"]))
	scorched.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	scorched.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	scorched.resolve_turn()
	var scorched_damage: int = scorched.events_of_type(BattleConstants.EVENT_DAMAGE_DEALT)[1].payload["damage"]

	var clean := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0, 0.0, 0.5, 1.0, 0.5])
	)
	clean.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"gustlet", [&"updraft"])
	)
	clean.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	clean.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	clean.resolve_turn()
	var clean_damage: int = clean.events_of_type(BattleConstants.EVENT_DAMAGE_DEALT)[1].payload["damage"]
	assert_equal(clean_damage, 19)
	assert_equal(scorched_damage, 14)


func _test_rooted_changes_next_turn_order() -> void:
	begin_case("rooted speed ordering")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([
			0.0, 0.5, 1.0, 0.5,
			0.0, 0.5, 1.0, 0.1,
		], 0.5)
	)
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"reedling", [&"thorn_lance"])
	)
	for _turn in 2:
		manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
		manager.submit_command(UseMoveCommand.new(&"opponent", &"thorn_lance"))
		manager.resolve_turn()
	assert_true(manager.get_party(&"player").members[0].has_status(&"rooted"))
	var second_turn_moves: Array[BattleEvent] = []
	for event in manager.events_of_type(BattleConstants.EVENT_MOVE_USED):
		if event.turn_number == 2:
			second_turn_moves.append(event)
	assert_equal(second_turn_moves.size(), 2)
	assert_equal(second_turn_moves[0].payload["side"], BattleConstants.SIDE_OPPONENT)


func _test_end_turn_status_damage_can_finish_battle() -> void:
	begin_case("status damage knockout")
	var player := _creature(&"cindermite", [&"ember_haze"], 1)
	player.persistent_status_ids.append(&"scorch")
	var manager := BattleManager.new(catalog, FixedBattleRandomSource.new([0.0, 0.0]))
	manager.start_battle(player, _creature(&"reedling", [&"lull_mist"]))
	manager.submit_command(UseMoveCommand.new(&"player", &"ember_haze"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"lull_mist"))
	manager.resolve_turn()
	assert_equal(manager.get_participant(&"player").current_hp, 0)
	assert_equal(manager.outcome, BattleConstants.OUTCOME_OPPONENT_VICTORY)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_STATUS_DAMAGE).size(), 2)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CREATURE_DEFEATED).size(), 1)
