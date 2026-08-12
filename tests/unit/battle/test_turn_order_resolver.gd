extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("TurnOrderResolver")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_move_priority_beats_speed()
	_test_speed_breaks_equal_priority()
	_test_seeded_tie_break_is_repeatable()


func _test_move_priority_beats_speed() -> void:
	begin_case("move priority before speed")
	var participants := {
		BattleConstants.SIDE_PLAYER: _participant_with_speed(BattleConstants.SIDE_PLAYER, 10),
		BattleConstants.SIDE_OPPONENT: _participant_with_speed(BattleConstants.SIDE_OPPONENT, 999),
	}
	var commands: Array[BattleCommand] = [
		UseMoveCommand.new(BattleConstants.SIDE_PLAYER, &"updraft"),
		UseMoveCommand.new(BattleConstants.SIDE_OPPONENT, &"brook_bash"),
	]
	var ordered := TurnOrderResolver.new(FixedBattleRandomSource.new()).resolve(
		commands, participants, catalog
	)
	assert_equal(ordered[0].actor_side, BattleConstants.SIDE_PLAYER)


func _test_speed_breaks_equal_priority() -> void:
	begin_case("speed within same priority")
	var participants := {
		BattleConstants.SIDE_PLAYER: _participant_with_speed(BattleConstants.SIDE_PLAYER, 80),
		BattleConstants.SIDE_OPPONENT: _participant_with_speed(BattleConstants.SIDE_OPPONENT, 40),
	}
	var commands: Array[BattleCommand] = [
		UseMoveCommand.new(BattleConstants.SIDE_OPPONENT, &"brook_bash"),
		UseMoveCommand.new(BattleConstants.SIDE_PLAYER, &"cinder_jab"),
	]
	var ordered := TurnOrderResolver.new(FixedBattleRandomSource.new()).resolve(
		commands, participants, catalog
	)
	assert_equal(ordered[0].actor_side, BattleConstants.SIDE_PLAYER)
	assert_equal(ordered[1].actor_side, BattleConstants.SIDE_OPPONENT)


func _test_seeded_tie_break_is_repeatable() -> void:
	begin_case("deterministic exact tie")
	var participants := {
		BattleConstants.SIDE_PLAYER: _participant_with_speed(BattleConstants.SIDE_PLAYER, 50),
		BattleConstants.SIDE_OPPONENT: _participant_with_speed(BattleConstants.SIDE_OPPONENT, 50),
	}
	var commands: Array[BattleCommand] = [
		UseMoveCommand.new(BattleConstants.SIDE_PLAYER, &"cinder_jab"),
		UseMoveCommand.new(BattleConstants.SIDE_OPPONENT, &"brook_bash"),
	]
	var first := TurnOrderResolver.new(SeededBattleRandomSource.new(913)).resolve(
		commands, participants, catalog
	)
	var second := TurnOrderResolver.new(SeededBattleRandomSource.new(913)).resolve(
		commands, participants, catalog
	)
	assert_equal(first[0].actor_side, second[0].actor_side)
	assert_equal(first[1].actor_side, second[1].actor_side)


func _participant_with_speed(side: StringName, speed: int) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.side = side
	participant.calculated_stats = CreatureStats.new()
	participant.calculated_stats.speed = speed
	return participant

