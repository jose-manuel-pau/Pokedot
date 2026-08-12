extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationSession")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_start_and_unknown_map()
	_test_movement_and_collision()
	_test_npc_collision_and_interaction()
	_test_encounter_transition_and_resume()
	_test_encounter_cooldown_suppresses_rolls()
	_test_seeded_sessions_are_reproducible()


func _test_start_and_unknown_map() -> void:
	begin_case("session start")
	var session := ExplorationSession.new(catalog)
	assert_false(session.start(&"missing_map"))
	assert_equal(session.last_error, &"unknown_map")
	assert_true(session.start(&"mosslight_crossing"))
	assert_equal(session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	assert_equal(session.state.player_position, Vector2i(2, 8))
	assert_equal(session.events_of_type(ExplorationConstants.EVENT_MAP_STARTED).size(), 1)


func _test_movement_and_collision() -> void:
	begin_case("movement collision")
	var session := ExplorationSession.new(catalog, FixedExplorationRandomSource.new([0.99]))
	session.start(&"mosslight_crossing")
	assert_equal(session.attempt_move(Vector2i.ZERO).reason, &"invalid_direction")
	assert_equal(session.state.step_count, 0)
	session.state.player_position = Vector2i(1, 1)
	var blocked := session.attempt_move(Vector2i.LEFT)
	assert_false(blocked.moved)
	assert_equal(blocked.reason, &"terrain_blocked")
	assert_equal(session.state.facing, Vector2i.LEFT)
	assert_equal(session.state.step_count, 0)
	var moved := session.attempt_move(Vector2i.RIGHT)
	assert_true(moved.moved)
	assert_equal(moved.from_position, Vector2i(1, 1))
	assert_equal(moved.to_position, Vector2i(2, 1))
	assert_equal(session.state.step_count, 1)
	assert_equal(session.events_of_type(ExplorationConstants.EVENT_MOVEMENT_RESOLVED).size(), 2)


func _test_npc_collision_and_interaction() -> void:
	begin_case("npc interaction")
	var session := ExplorationSession.new(catalog)
	session.start(&"mosslight_crossing")
	session.state.player_position = Vector2i(13, 7)
	var blocked := session.attempt_move(Vector2i.RIGHT)
	assert_equal(blocked.reason, &"npc_blocked")
	assert_equal(session.state.player_position, Vector2i(13, 7))
	var interaction := session.interact()
	assert_true(interaction.success)
	assert_equal(interaction.npc_id, &"ranger_mira")
	assert_equal(interaction.speaker_name, "Ranger Mira")
	assert_equal(interaction.dialogue.size(), 2)
	assert_equal(session.events_of_type(ExplorationConstants.EVENT_NPC_INTERACTED).size(), 1)
	session.state.facing = Vector2i.DOWN
	assert_equal(session.interact().reason, &"nothing_to_interact")


func _test_encounter_transition_and_resume() -> void:
	begin_case("encounter transition")
	var random := FixedExplorationRandomSource.new([0.0, 0.0, 0.0])
	var session := ExplorationSession.new(catalog, random)
	session.start(&"mosslight_crossing")
	session.state.player_position = Vector2i(4, 8)
	var movement := session.attempt_move(Vector2i.RIGHT)
	assert_true(movement.moved)
	assert_not_null(movement.encounter)
	assert_equal(movement.encounter.species_id, &"cindermite")
	assert_equal(movement.encounter.level, 3)
	assert_equal(session.state.phase, ExplorationConstants.PHASE_BATTLE_TRANSITION)
	assert_equal(session.state.pending_encounter, movement.encounter)
	assert_equal(session.events_of_type(ExplorationConstants.EVENT_WILD_ENCOUNTER).size(), 1)
	assert_equal(session.attempt_move(Vector2i.RIGHT).reason, &"exploration_not_active")
	assert_true(session.resume_after_battle())
	assert_equal(session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	assert_equal(session.state.pending_encounter, null)
	assert_equal(session.state.encounter_cooldown_steps, 3)
	assert_false(session.resume_after_battle())
	assert_equal(session.last_error, &"no_battle_transition")


func _test_encounter_cooldown_suppresses_rolls() -> void:
	begin_case("encounter cooldown")
	var random := FixedExplorationRandomSource.new([0.0, 0.0, 0.0, 0.0])
	var session := ExplorationSession.new(catalog, random)
	session.start(&"mosslight_crossing")
	session.state.player_position = Vector2i(4, 8)
	session.attempt_move(Vector2i.RIGHT)
	session.resume_after_battle()
	assert_equal(random.call_count, 3)
	for _step in 3:
		assert_equal(session.attempt_move(Vector2i.RIGHT).encounter, null)
	assert_equal(session.state.encounter_cooldown_steps, 0)
	assert_equal(random.call_count, 3)


func _test_seeded_sessions_are_reproducible() -> void:
	begin_case("seeded exploration")
	var first := ExplorationSession.new(catalog, SeededExplorationRandomSource.new(88))
	var second := ExplorationSession.new(catalog, SeededExplorationRandomSource.new(88))
	for session in [first, second]:
		session.start(&"mosslight_crossing")
		session.state.player_position = Vector2i(4, 8)
	assert_equal(
		first.attempt_move(Vector2i.RIGHT).encounter == null,
		second.attempt_move(Vector2i.RIGHT).encounter == null
	)
	assert_equal(first.state.phase, second.state.phase)
	assert_equal(first.event_history.size(), second.event_history.size())
