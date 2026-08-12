extends TestSuite

const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationRosterIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_storage_capture_can_lead_next_encounter()
	_test_victory_progress_persists_into_roster()
	_test_menu_is_only_available_during_active_exploration()


func _captured_creature() -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(
		&"reedling",
		9,
		[&"brook_bash", &"thorn_lance", &"lull_mist"]
	)
	creature.instance_id = "captured-reedling"
	return creature


func _request() -> WildEncounterRequest:
	var request := WildEncounterRequest.new()
	request.encounter_id = "roster-integration-wild"
	request.map_id = &"mosslight_crossing"
	request.zone_id = &"sunmeadow_grass"
	request.grid_position = Vector2i(5, 8)
	request.species_id = &"gustlet"
	request.level = 5
	return request


func _screen() -> ExplorationScreen:
	var screen := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, PlayerPreferences.new())
	screen.help_panel.hide()
	return screen


func _test_storage_capture_can_lead_next_encounter() -> void:
	begin_case("selected capture enters next battle")
	var screen := _screen()
	var captured := _captured_creature()
	screen._collection.storage.append(captured)
	screen.open_creature_roster()
	assert_true(screen.creature_roster_menu.visible, "Roster should open from active exploration.")
	assert_true(
		screen.creature_roster_menu.get_entry_instance_ids().has(captured.instance_id),
		"Storage capture should appear in the complete roster."
	)
	assert_true(
		screen.creature_roster_menu.choose_creature(captured.instance_id),
		"Storage capture should be selectable."
	)
	assert_equal(screen.get_selected_battle_creature(), captured)
	screen.creature_roster_menu.close_roster()
	screen.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	screen._begin_battle_transition(_request())
	assert_true(screen.battle_screen.visible, "Selected lead should enter a visible battle.")
	var player := screen.active_battle.get_participant(BattleConstants.SIDE_PLAYER)
	assert_equal(player.creature, captured)
	assert_equal(player.species.species_id, &"reedling")
	assert_equal(
		screen.active_battle.get_party(BattleConstants.SIDE_PLAYER).members.size(),
		1
	)
	assert_true(screen.battle_screen.choose_run(), "Run should finish the verification encounter.")
	screen.battle_screen.close_battle()
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	assert_equal(screen.get_selected_battle_creature(), captured)
	assert_true(
		screen.status_label.text.contains("Reedling"),
		"Exploration status should retain the selected lead name."
	)
	screen.free()


func _test_victory_progress_persists_into_roster() -> void:
	begin_case("battle progression persists into roster")
	var screen := _screen()
	var starter := screen.get_selected_battle_creature()
	starter.level = 1
	starter.total_experience = 0
	starter.learned_move_ids = [&"cinder_jab"]
	starter.current_hp = StatCalculator.new().calculate_for_instance(
		catalog.get_species(starter.species_id),
		starter
	).hp
	var request := _request()
	request.level = 1
	screen.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	screen._begin_battle_transition(request)
	var opponent := screen.active_battle.get_participant(BattleConstants.SIDE_OPPONENT)
	opponent.apply_damage(opponent.current_hp - 1)
	assert_true(screen.battle_screen.choose_move(&"cinder_jab"))
	assert_equal(screen.active_battle.outcome, BattleConstants.OUTCOME_PLAYER_VICTORY)
	assert_equal(starter.total_experience, 12)
	assert_equal(starter.level, 2)
	screen.battle_screen.close_battle()
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	screen.open_creature_roster()
	assert_true(screen.creature_roster_menu.visible)
	assert_true(screen.creature_roster_menu.detail_meta.text.contains("LEVEL 2"))
	assert_true(screen.creature_roster_menu.experience_label.text.contains("Total 12"))
	assert_true(screen.creature_roster_menu.experience_bar.value > 0.0)
	screen.free()


func _test_menu_is_only_available_during_active_exploration() -> void:
	begin_case("exploration menu state guard")
	var screen := _screen()
	var open_key := InputEventKey.new()
	open_key.keycode = KEY_P
	open_key.pressed = true
	screen._unhandled_input(open_key)
	assert_true(screen.creature_roster_menu.visible)
	var position_before := screen.session.state.player_position
	var movement_key := InputEventKey.new()
	movement_key.keycode = KEY_W
	movement_key.pressed = true
	screen._unhandled_input(movement_key)
	assert_equal(screen.session.state.player_position, position_before)
	screen.creature_roster_menu.close_roster()
	screen.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	screen.open_creature_roster()
	assert_false(screen.creature_roster_menu.visible)
	screen.session.state.phase = ExplorationConstants.PHASE_ACTIVE
	screen.dialogue_panel.show()
	screen.open_creature_roster()
	assert_false(screen.creature_roster_menu.visible)
	screen.free()
