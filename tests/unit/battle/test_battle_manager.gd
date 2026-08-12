extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("BattleManager")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_start_transitions_to_awaiting_commands()
	_test_start_rejects_invalid_participant()
	_test_participant_limits_active_moves()
	_test_command_validation_and_duplicate_submission()
	_test_turn_requires_both_commands()
	_test_turn_applies_damage_and_consumes_uses()
	_test_miss_event_and_next_turn_transition()
	_test_status_move_event()
	_test_priority_knockout_finishes_battle()
	_test_opponent_victory()
	_test_seeded_battles_are_reproducible()


func _creature(
	species_id: StringName,
	move_ids: Array[StringName],
	current_hp: int = 99999,
	level: int = 20
) -> CreatureInstance:
	return BattleTestFactory.create_creature(species_id, level, move_ids, current_hp)


func _manager(sequence: Array[float] = [], fallback: float = 0.5) -> BattleManager:
	return BattleManager.new(catalog, FixedBattleRandomSource.new(sequence, fallback))


func _test_start_transitions_to_awaiting_commands() -> void:
	begin_case("battle initialization")
	var manager := _manager()
	var observed_events: Array[BattleEvent] = []
	var observed_phases: Array[StringName] = []
	manager.event_emitted.connect(func(event: BattleEvent) -> void:
		observed_events.append(event)
	)
	manager.phase_changed.connect(func(_previous: StringName, current: StringName) -> void:
		observed_phases.append(current)
	)
	var player := _creature(&"cindermite", [&"cinder_jab"])
	var opponent := _creature(&"gustlet", [&"updraft"])
	assert_true(manager.start_battle(player, opponent))
	assert_equal(manager.phase, BattleConstants.PHASE_AWAITING_COMMANDS)
	assert_equal(manager.outcome, BattleConstants.OUTCOME_NONE)
	assert_equal(manager.turn_number, 1)
	assert_equal(manager.event_history[0].event_type, BattleConstants.EVENT_BATTLE_STARTED)
	assert_equal(manager.event_history[1].event_type, BattleConstants.EVENT_TURN_STARTED)
	assert_equal(observed_events.size(), 2)
	assert_equal(observed_phases, [BattleConstants.PHASE_AWAITING_COMMANDS])
	assert_equal(player.current_hp, manager.get_participant(&"player").get_max_hp())
	assert_false(manager.start_battle(player, opponent))
	assert_equal(manager.last_error, &"battle_already_started")


func _test_start_rejects_invalid_participant() -> void:
	begin_case("invalid battle participants")
	var missing_manager := _manager()
	assert_false(missing_manager.start_battle(
		null,
		_creature(&"gustlet", [&"updraft"])
	))
	assert_equal(missing_manager.last_error, &"missing_creature")

	var unknown_manager := _manager()
	assert_false(unknown_manager.start_battle(
		_creature(&"missing_species", [&"cinder_jab"]),
		_creature(&"gustlet", [&"updraft"])
	))
	assert_equal(unknown_manager.last_error, &"unknown_species")

	var defeated_manager := _manager()
	assert_false(defeated_manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"], 0),
		_creature(&"gustlet", [&"updraft"])
	))
	assert_equal(defeated_manager.last_error, &"creature_already_defeated")

	var moves_manager := _manager()
	assert_false(moves_manager.start_battle(
		_creature(&"cindermite", [&"missing_move"]),
		_creature(&"gustlet", [&"updraft"])
	))
	assert_equal(moves_manager.last_error, &"creature_has_no_moves")


func _test_participant_limits_active_moves() -> void:
	begin_case("four active move limit")
	var manager := _manager()
	manager.start_battle(
		_creature(&"cindermite", [
			&"cinder_jab",
			&"ember_haze",
			&"brook_bash",
			&"lull_mist",
			&"thorn_lance",
		]),
		_creature(&"gustlet", [&"updraft"])
	)
	var player := manager.get_participant(BattleConstants.SIDE_PLAYER)
	assert_equal(player.move_slots_by_id.size(), BattleParticipant.MAX_ACTIVE_MOVES)
	assert_equal(player.get_move_slot(&"cinder_jab"), null)
	assert_not_null(player.get_move_slot(&"thorn_lance"))


func _test_command_validation_and_duplicate_submission() -> void:
	begin_case("command validation")
	var manager := _manager()
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"gustlet", [&"updraft"])
	)
	assert_false(manager.submit_command(null))
	assert_equal(manager.last_error, &"missing_command")
	assert_false(manager.submit_command(UseMoveCommand.new(&"invalid_side", &"cinder_jab")))
	assert_equal(manager.last_error, &"unknown_side")
	assert_false(manager.submit_command(UseMoveCommand.new(&"player", &"brook_bash")))
	assert_equal(manager.last_error, &"move_not_learned")
	assert_false(manager.submit_command(UseMoveCommand.new(&"player", &"missing_move")))
	assert_equal(manager.last_error, &"unknown_move")
	var slot := manager.get_participant(&"player").get_move_slot(&"cinder_jab")
	slot.remaining_uses = 0
	assert_false(manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab")))
	assert_equal(manager.last_error, &"no_move_uses")
	slot.remaining_uses = 1
	assert_true(manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab")))
	assert_false(manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab")))
	assert_equal(manager.last_error, &"command_already_submitted")
	assert_equal(manager.events_of_type(BattleConstants.EVENT_COMMAND_REJECTED).size(), 6)


func _test_turn_requires_both_commands() -> void:
	begin_case("turn readiness")
	var manager := _manager()
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"gustlet", [&"updraft"])
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	assert_false(manager.can_resolve_turn())
	assert_false(manager.resolve_turn())
	assert_equal(manager.last_error, &"turn_not_ready")
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	assert_true(manager.can_resolve_turn())


func _test_turn_applies_damage_and_consumes_uses() -> void:
	begin_case("damage turn resolution")
	# Accuracy, critical, variance are consumed once for each damaging command.
	var manager := _manager([0.0, 0.5, 1.0, 0.0, 0.5, 1.0])
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"reedling", [&"brook_bash"])
	)
	var player_hp := manager.get_participant(&"player").current_hp
	var opponent_hp := manager.get_participant(&"opponent").current_hp
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	assert_true(manager.resolve_turn())
	assert_true(manager.get_participant(&"player").current_hp < player_hp)
	assert_true(manager.get_participant(&"opponent").current_hp < opponent_hp)
	assert_equal(manager.get_participant(&"player").get_move_slot(&"cinder_jab").remaining_uses, 24)
	assert_equal(manager.get_participant(&"opponent").get_move_slot(&"brook_bash").remaining_uses, 24)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_DAMAGE_DEALT).size(), 2)
	assert_equal(manager.turn_number, 2)
	assert_equal(manager.phase, BattleConstants.PHASE_AWAITING_COMMANDS)
	assert_true(manager.pending_commands_by_side.is_empty())


func _test_miss_event_and_next_turn_transition() -> void:
	begin_case("move miss")
	# Updraft resolves first due to priority; brook_bash then rolls exactly 95.
	var manager := _manager([0.0, 0.5, 1.0, 0.95])
	manager.start_battle(
		_creature(&"reedling", [&"brook_bash"]),
		_creature(&"gustlet", [&"updraft"])
	)
	var opponent_hp := manager.get_participant(&"opponent").current_hp
	manager.submit_command(UseMoveCommand.new(&"player", &"brook_bash"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.get_participant(&"opponent").current_hp, opponent_hp)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_MOVE_MISSED).size(), 1)
	assert_equal(manager.get_participant(&"player").get_move_slot(&"brook_bash").remaining_uses, 24)
	assert_equal(manager.turn_number, 2)


func _test_status_move_event() -> void:
	begin_case("status move vertical-slice event")
	# The faster opponent consumes accuracy, critical, and variance first; the
	# final zero is the player's status-move accuracy roll.
	var manager := _manager([0.0, 0.5, 1.0, 0.0])
	manager.start_battle(
		_creature(&"reedling", [&"lull_mist"]),
		_creature(&"cindermite", [&"cinder_jab"])
	)
	var opponent_hp := manager.get_participant(&"opponent").current_hp
	manager.submit_command(UseMoveCommand.new(&"player", &"lull_mist"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"cinder_jab"))
	manager.resolve_turn()
	assert_equal(manager.get_participant(&"opponent").current_hp, opponent_hp)
	var events := manager.events_of_type(BattleConstants.EVENT_STATUS_MOVE_RESOLVED)
	assert_equal(events.size(), 1)
	if not events.is_empty():
		assert_equal(events[0].payload["status_effect_id"], &"drowsy")


func _test_priority_knockout_finishes_battle() -> void:
	begin_case("player victory and skipped counterattack")
	var manager := _manager([0.0, 0.5, 1.0])
	manager.start_battle(
		_creature(&"cindermite", [&"updraft"]),
		_creature(&"reedling", [&"brook_bash"], 1)
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"updraft"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	assert_true(manager.resolve_turn())
	assert_equal(manager.phase, BattleConstants.PHASE_FINISHED)
	assert_equal(manager.outcome, BattleConstants.OUTCOME_PLAYER_VICTORY)
	assert_equal(manager.get_participant(&"opponent").current_hp, 0)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CREATURE_DEFEATED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_BATTLE_FINISHED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_MOVE_USED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_COMMAND_SKIPPED).size(), 1)
	assert_equal(manager.event_history[-1].event_type, BattleConstants.EVENT_BATTLE_FINISHED)
	assert_false(manager.submit_command(UseMoveCommand.new(&"player", &"updraft")))
	assert_equal(manager.last_error, &"commands_not_accepted")


func _test_opponent_victory() -> void:
	begin_case("opponent victory")
	var manager := _manager([0.0, 0.5, 1.0])
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"], 1),
		_creature(&"gustlet", [&"updraft"])
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.outcome, BattleConstants.OUTCOME_OPPONENT_VICTORY)
	assert_equal(manager.phase, BattleConstants.PHASE_FINISHED)


func _test_seeded_battles_are_reproducible() -> void:
	begin_case("seeded battle replay")
	var first := BattleManager.new(catalog, SeededBattleRandomSource.new(4401))
	var second := BattleManager.new(catalog, SeededBattleRandomSource.new(4401))
	for manager in [first, second]:
		manager.start_battle(
			_creature(&"cindermite", [&"cinder_jab"]),
			_creature(&"reedling", [&"brook_bash"])
		)
		manager.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
		manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
		manager.resolve_turn()
	assert_equal(first.get_participant(&"player").current_hp, second.get_participant(&"player").current_hp)
	assert_equal(first.get_participant(&"opponent").current_hp, second.get_participant(&"opponent").current_hp)
	assert_equal(first.event_history.size(), second.event_history.size())
	for index in first.event_history.size():
		assert_equal(first.event_history[index].event_type, second.event_history[index].event_type)
