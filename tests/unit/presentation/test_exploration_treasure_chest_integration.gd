extends TestSuite

const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ExplorationTreasureChestIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_interaction_adds_one_reward_and_opens_chest()
	_test_opened_chest_cannot_award_twice()


func _screen() -> ExplorationScreen:
	var screen := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, PlayerPreferences.new())
	screen.help_panel.hide()
	screen.session.state.player_position = Vector2i(3, 9)
	screen.session.state.facing = Vector2i.RIGHT
	return screen


func _restorative_total(screen: ExplorationScreen) -> int:
	var total := 0
	for item_id in [&"potion", &"mega_potion", &"ultra_potion", &"elixir"]:
		total += screen._inventory.get_quantity(item_id)
	return total


func _press_interact(screen: ExplorationScreen) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	screen._unhandled_input(event)


func _test_interaction_adds_one_reward_and_opens_chest() -> void:
	begin_case("map chest awards live inventory")
	var screen := _screen()
	var before := _restorative_total(screen)
	_press_interact(screen)
	assert_equal(_restorative_total(screen), before + 1)
	assert_true(screen.session.state.is_chest_open(&"trailhead_cache"))
	assert_true(screen.status_label.text.contains("Treasure found"))
	var events := screen.session.events_of_type(
		ExplorationConstants.EVENT_TREASURE_CHEST_OPENED
	)
	assert_equal(events.size(), 1)
	var reward_id := StringName(str(events[0].payload["item_id"]))
	assert_true(reward_id in [&"potion", &"mega_potion", &"ultra_potion", &"elixir"])
	assert_equal(events[0].payload["quantity"], 1)
	screen.open_object_menu()
	assert_true(screen.object_menu.visible)
	assert_true(screen.object_menu.get_item_ids().has(reward_id))
	assert_true(screen.object_menu.get_item_button(reward_id).text.contains(
		"x%d" % screen._inventory.get_quantity(reward_id)
	))
	screen.free()


func _test_opened_chest_cannot_award_twice() -> void:
	begin_case("opened chest is one-time")
	var screen := _screen()
	_press_interact(screen)
	var after_first := _restorative_total(screen)
	_press_interact(screen)
	assert_equal(_restorative_total(screen), after_first)
	assert_true(screen.status_label.text.contains("empty"))
	assert_equal(screen.session.events_of_type(
		ExplorationConstants.EVENT_TREASURE_CHEST_OPENED
	).size(), 1)
	screen.free()
