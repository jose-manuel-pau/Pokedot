extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("BattleAiController")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_ai_selects_highest_expected_damage()
	_test_ai_uses_status_then_avoids_duplicate()
	_test_ai_ignores_depleted_move()
	_test_low_hp_ai_switches_to_bench()
	_test_rooted_ai_cannot_switch()
	_test_seeded_tie_choice_is_reproducible()
	_test_manager_submits_ai_command()
	_test_ai_returns_null_without_legal_action()


func _creature(
	species_id: StringName,
	moves: Array[StringName],
	hp: int = 99999,
	suffix: String = ""
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, 20, moves, hp)
	if not suffix.is_empty():
		creature.instance_id += "-" + suffix
	return creature


func _party(creatures: Array[CreatureInstance]) -> Array[CreatureInstance]:
	return creatures


func _test_ai_selects_highest_expected_damage() -> void:
	begin_case("expected damage choice")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"gustlet", [&"updraft"]),
		_creature(&"cindermite", [&"cinder_jab", &"stonepulse"])
	)
	var command := BattleAiController.new(catalog).choose_command(manager) as UseMoveCommand
	assert_not_null(command)
	assert_equal(command.actor_side, BattleConstants.SIDE_OPPONENT)
	assert_equal(command.move_id, &"stonepulse")


func _test_ai_uses_status_then_avoids_duplicate() -> void:
	begin_case("status utility")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"reedling", [&"brook_bash"]),
		_creature(&"reedling", [&"brook_bash", &"lull_mist"], 99999, "opponent")
	)
	var ai := BattleAiController.new(catalog)
	var first := ai.choose_command(manager) as UseMoveCommand
	assert_equal(first.move_id, &"lull_mist")
	manager.status_effect_service.apply_status(
		manager.get_participant(BattleConstants.SIDE_PLAYER),
		&"drowsy",
		1
	)
	var second := ai.choose_command(manager) as UseMoveCommand
	assert_equal(second.move_id, &"brook_bash")


func _test_ai_ignores_depleted_move() -> void:
	begin_case("move uses affect choice")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"gustlet", [&"updraft"]),
		_creature(&"cindermite", [&"cinder_jab", &"stonepulse"])
	)
	manager.get_participant(&"opponent").get_move_slot(&"stonepulse").remaining_uses = 0
	var command := BattleAiController.new(catalog).choose_command(manager) as UseMoveCommand
	assert_equal(command.move_id, &"cinder_jab")


func _test_low_hp_ai_switches_to_bench() -> void:
	begin_case("low HP switch")
	var active := _creature(&"cindermite", [&"cinder_jab"], 1)
	var bench := _creature(&"reedling", [&"brook_bash"])
	var manager := BattleManager.new(catalog)
	manager.start_party_battle(
		_party([_creature(&"cindermite", [&"cinder_jab"], 99999, "player")]),
		_party([active, bench])
	)
	var command := BattleAiController.new(catalog).choose_command(manager)
	assert_true(command is SwitchCreatureCommand)
	assert_equal((command as SwitchCreatureCommand).target_instance_id, bench.instance_id)


func _test_rooted_ai_cannot_switch() -> void:
	begin_case("AI respects movement lock")
	var manager := BattleManager.new(catalog)
	manager.start_party_battle(
		_party([_creature(&"cindermite", [&"cinder_jab"], 99999, "player")]),
		_party([
			_creature(&"cindermite", [&"cinder_jab"], 1),
			_creature(&"reedling", [&"brook_bash"]),
		])
	)
	manager.status_effect_service.apply_status(
		manager.get_participant(&"opponent"),
		&"rooted",
		1
	)
	assert_true(BattleAiController.new(catalog).choose_command(manager) is UseMoveCommand)


func _test_seeded_tie_choice_is_reproducible() -> void:
	begin_case("deterministic equal-score choice")
	_add_twin_move(&"alpha_strike")
	_add_twin_move(&"beta_strike")
	var first_manager := _twin_move_battle()
	var second_manager := _twin_move_battle()
	var first := BattleAiController.new(
		catalog,
		SeededBattleRandomSource.new(771)
	).choose_command(first_manager) as UseMoveCommand
	var second := BattleAiController.new(
		catalog,
		SeededBattleRandomSource.new(771)
	).choose_command(second_manager) as UseMoveCommand
	assert_equal(first.move_id, second.move_id)
	assert_true(first.move_id == &"alpha_strike" or first.move_id == &"beta_strike")


func _test_manager_submits_ai_command() -> void:
	begin_case("manager AI submission")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"gustlet", [&"updraft"]),
		_creature(&"cindermite", [&"cinder_jab", &"stonepulse"])
	)
	assert_true(manager.submit_ai_command(BattleAiController.new(catalog)))
	assert_true(manager.pending_commands_by_side.has(BattleConstants.SIDE_OPPONENT))
	assert_equal(
		(manager.pending_commands_by_side[BattleConstants.SIDE_OPPONENT] as UseMoveCommand).move_id,
		&"stonepulse"
	)
	assert_false(manager.submit_ai_command(null))
	assert_equal(manager.last_error, &"missing_ai")


func _test_ai_returns_null_without_legal_action() -> void:
	begin_case("no legal AI command")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"gustlet", [&"updraft"]),
		_creature(&"cindermite", [&"cinder_jab"])
	)
	manager.get_participant(&"opponent").get_move_slot(&"cinder_jab").remaining_uses = 0
	var ai := BattleAiController.new(catalog)
	assert_equal(ai.choose_command(manager), null)
	assert_false(manager.submit_ai_command(ai))
	assert_equal(manager.last_error, &"ai_no_command")


func _add_twin_move(move_id: StringName) -> void:
	if catalog.get_move(move_id) != null:
		return
	var move := MoveDefinition.new()
	move.move_id = move_id
	move.display_name = str(move_id)
	move.element_type_id = &"gale"
	move.category = "special"
	move.power = 40
	move.accuracy = 100.0
	move.max_uses = 10
	catalog.add_move(move)


func _twin_move_battle() -> BattleManager:
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"], 99999, "target"),
		_creature(&"gustlet", [&"alpha_strike", &"beta_strike"], 99999, "ai")
	)
	return manager

