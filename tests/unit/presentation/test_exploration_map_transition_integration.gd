extends TestSuite

const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationMapTransitionIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_smooth_transition_preserves_live_state()
	_test_reduced_motion_uses_short_transition()
	_test_open_trail_to_village_and_house_door()


func _screen(preferences: PlayerPreferences = null) -> ExplorationScreen:
	var screen := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, preferences if preferences != null else PlayerPreferences.new())
	screen.help_panel.hide()
	return screen


func _press_move(screen: ExplorationScreen, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	screen._unhandled_input(event)


func _test_smooth_transition_preserves_live_state() -> void:
	begin_case("smooth round trip preserves live state")
	var screen := _screen()
	var creature := screen.get_selected_battle_creature()
	creature.current_hp = 7
	screen.session.state.opened_chest_ids.append(&"trailhead_cache")
	var potion_quantity := screen._inventory.get_quantity(&"potion")
	var selected_id := screen._selected_battle_creature_id
	screen.session.state.player_position = Vector2i(16, 9)
	_press_move(screen, KEY_RIGHT)
	assert_true(screen.is_map_transitioning())
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_MAP_TRANSITION)
	assert_equal(screen.session.state.map_id, &"mosslight_crossing")
	var duration := screen.get_map_transition_duration()
	screen._process(duration * 0.5)
	assert_float_equal(screen.get_map_transition_alpha(), 0.5)
	assert_true(screen.map_transition_overlay.visible)
	_press_move(screen, KEY_LEFT)
	assert_equal(screen.session.state.player_position, Vector2i(17, 9))
	_press_move(screen, KEY_F1)
	assert_false(screen.help_panel.visible)
	screen._process(duration * 0.5)
	assert_equal(screen.session.state.map_id, &"dewstone_vale")
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	assert_equal(screen.title_label.text, "Dewstone Vale")
	assert_float_equal(screen.get_map_transition_alpha(), 1.0)
	_press_move(screen, KEY_RIGHT)
	assert_equal(screen.session.state.player_position, Vector2i(1, 9))
	screen._process(duration)
	assert_false(screen.is_map_transitioning())
	assert_false(screen.map_transition_overlay.visible)
	assert_equal(screen.get_selected_battle_creature().current_hp, 7)
	assert_equal(screen._selected_battle_creature_id, selected_id)
	assert_equal(screen._inventory.get_quantity(&"potion"), potion_quantity)
	assert_true(screen.session.state.is_chest_open(&"trailhead_cache"))
	_press_move(screen, KEY_LEFT)
	assert_true(screen.is_map_transitioning())
	screen._process(duration * 2.0)
	assert_false(screen.is_map_transitioning())
	assert_equal(screen.session.state.map_id, &"mosslight_crossing")
	assert_equal(screen.session.state.player_position, Vector2i(16, 9))
	assert_equal(screen.session.state.facing, Vector2i.LEFT)
	screen.free()


func _test_reduced_motion_uses_short_transition() -> void:
	begin_case("reduced motion transition")
	var preferences := PlayerPreferences.new()
	preferences.reduced_motion = true
	var screen := _screen(preferences)
	assert_float_equal(screen.get_map_transition_duration(), 0.05)
	screen.session.state.player_position = Vector2i(16, 9)
	_press_move(screen, KEY_RIGHT)
	screen._process(0.10)
	assert_false(screen.is_map_transitioning())
	assert_equal(screen.session.state.map_id, &"dewstone_vale")
	screen.free()


func _test_open_trail_to_village_and_house_door() -> void:
	begin_case("village trail and research-house door presentation")
	var screen := _screen()
	assert_true(screen.session.start(&"dewstone_vale"))
	screen.session.state.player_position = Vector2i(16, 9)
	_press_move(screen, KEY_RIGHT)
	assert_true(screen.status_label.text.contains("Following the trail"))
	screen._process(screen.get_map_transition_duration() * 2.0)
	assert_equal(screen.session.state.map_id, &"lumenstead_village")
	assert_equal(screen.title_label.text, "Lumenstead Village")
	screen.session.state.player_position = Vector2i(8, 4)
	_press_move(screen, KEY_UP)
	assert_true(screen.status_label.text.contains("Entering Lumen Research House"))
	assert_equal(screen.session.state.phase, ExplorationConstants.PHASE_MAP_TRANSITION)
	screen._process(screen.get_map_transition_duration() * 2.0)
	assert_equal(screen.session.state.map_id, &"lumen_research_house")
	assert_equal(screen.session.state.player_position, Vector2i(8, 8))
	assert_equal(screen.title_label.text, "Lumen Research House")
	screen.session.state.player_position = Vector2i(8, 9)
	_press_move(screen, KEY_DOWN)
	screen._process(screen.get_map_transition_duration() * 2.0)
	assert_equal(screen.session.state.map_id, &"lumenstead_village")
	assert_equal(screen.session.state.player_position, Vector2i(8, 4))
	screen.free()
