extends TestSuite

const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationObjectMenuIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_battle_damage_persists_and_field_potion_restores_hp()
	_test_object_menu_input_and_state_guards()


func _screen() -> ExplorationScreen:
	var screen := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, PlayerPreferences.new())
	screen.help_panel.hide()
	return screen


func _request() -> WildEncounterRequest:
	var request := WildEncounterRequest.new()
	request.encounter_id = "object-menu-hp-persistence"
	request.map_id = &"mosslight_crossing"
	request.zone_id = &"sunmeadow_grass"
	request.grid_position = Vector2i(5, 8)
	request.species_id = &"gustlet"
	request.level = 5
	return request


func _test_battle_damage_persists_and_field_potion_restores_hp() -> void:
	begin_case("battle damage to map potion loop")
	var screen := _screen()
	var starter := screen.get_selected_battle_creature()
	var maximum := StatCalculator.new().calculate_for_instance(
		catalog.get_species(starter.species_id),
		starter
	).hp
	screen.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	screen._begin_battle_transition(_request())
	var participant := screen.active_battle.get_participant(BattleConstants.SIDE_PLAYER)
	assert_equal(participant.creature, starter)
	participant.apply_damage(17)
	var damaged_hp := maximum - 17
	assert_equal(starter.current_hp, damaged_hp)
	assert_true(screen.battle_screen.choose_run())
	screen.battle_screen.close_battle()
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	assert_equal(starter.current_hp, damaged_hp, "Map return must not refill battle damage.")
	screen.open_object_menu()
	assert_true(screen.object_menu.visible)
	assert_equal(screen.object_menu.get_item_ids().slice(0, 3), [
		&"potion", &"mega_potion", &"ultra_potion",
	])
	assert_equal(screen.object_menu.get_selected_target_id(), starter.instance_id)
	assert_equal(screen._inventory.get_quantity(&"potion"), 5)
	assert_true(screen.object_menu.use_selected_item())
	assert_equal(starter.current_hp, maximum)
	assert_equal(screen._inventory.get_quantity(&"potion"), 4)
	assert_true(screen.object_menu.feedback_label.text.contains("restored 17 HP"))
	screen.object_menu.close_menu()
	assert_true(screen.status_label.text.contains("Potion restored 17 HP"))
	screen.free()


func _test_object_menu_input_and_state_guards() -> void:
	begin_case("object menu input and field guards")
	var screen := _screen()
	var open_key := InputEventKey.new()
	open_key.keycode = KEY_B
	open_key.pressed = true
	screen._unhandled_input(open_key)
	assert_true(screen.object_menu.visible)
	var position_before := screen.session.state.player_position
	var movement_key := InputEventKey.new()
	movement_key.keycode = KEY_W
	movement_key.pressed = true
	screen._unhandled_input(movement_key)
	assert_equal(screen.session.state.player_position, position_before)
	screen.object_menu._unhandled_input(open_key)
	assert_false(screen.object_menu.visible)
	screen.open_creature_roster()
	assert_true(screen.creature_roster_menu.visible)
	screen.open_object_menu()
	assert_false(screen.object_menu.visible)
	screen.creature_roster_menu.close_roster()
	screen.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	screen.open_object_menu()
	assert_false(screen.object_menu.visible)
	screen.session.state.phase = ExplorationConstants.PHASE_ACTIVE
	screen.dialogue_panel.show()
	screen.open_object_menu()
	assert_false(screen.object_menu.visible)
	screen.free()
