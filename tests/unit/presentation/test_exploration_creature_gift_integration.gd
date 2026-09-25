extends TestSuite

const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationCreatureGiftIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_professor_dialogue_unlocks_exactly_one_live_egg_choice()


func _screen() -> ExplorationScreen:
	var screen := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, PlayerPreferences.new())
	screen.help_panel.hide()
	assert_true(screen.session.start(&"lumen_research_house"))
	screen.title_label.text = screen.session.get_current_map().display_name
	return screen


func _press_interact(screen: ExplorationScreen) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	screen._unhandled_input(event)


func _test_professor_dialogue_unlocks_exactly_one_live_egg_choice() -> void:
	begin_case("live professor egg selection")
	var screen := _screen()
	var initial_species_id := screen.get_selected_battle_creature().species_id
	for gift_definition in screen.session.get_current_map().creature_gifts:
		assert_true(gift_definition.species_id != initial_species_id)
	var current_reedling := BattleTestFactory.create_creature(&"reedling", 5, [&"reed_whip"])
	current_reedling.instance_id = "current-reedling"
	screen._collection.party.append(current_reedling)
	var original_party_size := screen._collection.party.size()
	screen.session.state.player_position = Vector2i(8, 6)
	screen.session.state.facing = Vector2i.UP
	_press_interact(screen)
	assert_true(screen.status_label.text.contains("Professor Lumen"))
	assert_equal(screen._collection.party.size(), original_party_size)
	screen.session.state.player_position = Vector2i(8, 3)
	screen.session.state.facing = Vector2i.UP
	_press_interact(screen)
	assert_true(screen.dialogue_panel.visible)
	assert_equal(screen.speaker_label.text, "Professor Lumen")
	assert_true(screen.session.state.has_talked_to_npc(&"professor_lumen"))
	while screen.dialogue_panel.visible:
		_press_interact(screen)
	screen.session.state.player_position = Vector2i(8, 6)
	screen.session.state.facing = Vector2i.UP
	_press_interact(screen)
	assert_equal(screen._collection.party.size(), original_party_size)
	assert_true(screen.status_label.text.contains("already in your active team"))
	assert_equal(screen.session.state.get_claimed_creature_gift(&"lumen_first_clutch"), &"")
	screen.session.state.player_position = Vector2i(11, 6)
	screen.session.state.facing = Vector2i.UP
	_press_interact(screen)
	assert_equal(screen._collection.party.size(), original_party_size + 1)
	var gift := screen._collection.find_instance("gift-gustlet_egg")
	assert_not_null(gift)
	assert_equal(gift.species_id, &"gustlet")
	assert_equal(screen._selected_battle_creature_id, gift.instance_id)
	assert_true(screen.status_label.text.contains("hatched"))
	assert_equal(screen.session.state.get_claimed_creature_gift(&"lumen_first_clutch"), &"gustlet_egg")
	screen.session.state.player_position = Vector2i(5, 6)
	_press_interact(screen)
	assert_equal(screen._collection.party.size(), original_party_size + 1)
	assert_true(screen.status_label.text.contains("already chose"))
	assert_equal(screen.session.events_of_type(
		ExplorationConstants.EVENT_CREATURE_GIFT_CLAIMED
	).size(), 1)
	screen.free()
