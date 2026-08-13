extends TestSuite

const BATTLE_SCENE := preload("res://src/presentation/battle/battle_screen.tscn")
const EXPLORATION_SCENE := preload("res://src/presentation/exploration/exploration_screen.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("BattleScreen")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_scene_presents_live_combatants_and_actions()
	_test_every_creature_stays_visible_and_clear_of_interface()
	_test_move_button_resolves_a_complete_turn()
	_test_victory_awards_experience_and_updates_level_bar()
	_test_run_shows_result_and_emits_close()
	_test_exploration_encounter_opens_playable_battle()


func _battle_fixture(sequence: Array[float] = []) -> Dictionary:
	var inventory := Inventory.new()
	var inventory_service := InventoryService.new(catalog)
	inventory_service.add(inventory, &"basic_capsule", 5)
	inventory_service.add(inventory, &"potion", 2)
	var player := BattleTestFactory.create_creature(
		&"cindermite", 10, [&"cinder_jab", &"stonepulse"]
	)
	var wild := BattleTestFactory.create_creature(
		&"reedling", 8, [&"brook_bash", &"lull_mist"]
	)
	wild.instance_id = "wild-reedling-ui"
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new(sequence, 0.2)
	)
	manager.start_wild_battle(
		[player], wild, inventory, CreatureCollection.new()
	)
	var screen := BATTLE_SCENE.instantiate() as BattleScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, manager, inventory, PlayerPreferences.new())
	return {
		"screen": screen,
		"manager": manager,
		"inventory": inventory,
	}


func _test_scene_presents_live_combatants_and_actions() -> void:
	begin_case("graphical battle presentation")
	var fixture := _battle_fixture()
	var screen := fixture["screen"] as BattleScreen
	assert_true(screen.visible)
	assert_not_null(screen.arena)
	assert_not_null(screen.arena.player)
	assert_not_null(screen.arena.opponent)
	assert_equal(screen.player_name.text, "Cindermite   Lv. 10")
	assert_equal(screen.opponent_name.text, "Reedling   Lv. 8")
	assert_equal(screen.get_move_button_count(), 2)
	assert_true(screen.capture_button.text.contains("x5"))
	assert_true(screen.item_button.text.contains("POTION"))
	assert_true(screen.item_button.text.contains("x2"))
	assert_true(screen.battle_log.text.contains("wild Reedling appeared"))
	screen.free()


func _test_every_creature_stays_visible_and_clear_of_interface() -> void:
	begin_case("all creature silhouettes are unobscured")
	var fixture := _battle_fixture()
	var screen := fixture["screen"] as BattleScreen
	var species_ids: Array[StringName] = []
	for raw_species_id in catalog.species_by_id.keys():
		species_ids.append(StringName(str(raw_species_id)))
	species_ids.sort()
	assert_equal(species_ids.size(), 5)
	for species_id in species_ids:
		for side in [BattleConstants.SIDE_PLAYER, BattleConstants.SIDE_OPPONENT]:
			var bounds := screen.arena.get_creature_screen_bounds(side, species_id)
			assert_true(
				screen.arena.get_rect().encloses(bounds),
				"%s must stay inside the viewport on the %s side." % [species_id, side]
			)
			assert_true(
				screen.is_creature_unobscured(side, species_id),
				"%s must not be covered by a HUD on the %s side." % [species_id, side]
			)
	var large_text := PlayerPreferences.new()
	large_text.text_scale = 1.5
	screen.set_preferences(large_text)
	for species_id in species_ids:
		for side in [BattleConstants.SIDE_PLAYER, BattleConstants.SIDE_OPPONENT]:
			assert_true(
				screen.is_creature_unobscured(side, species_id),
				"%s must remain clear at 150%% text size on the %s side." % [species_id, side]
			)
	var cindermite_bounds := screen.arena.get_creature_screen_bounds(
		BattleConstants.SIDE_PLAYER,
		&"cindermite"
	)
	assert_false(
		screen.player_hud.get_rect().intersects(cindermite_bounds),
		"The player name/HP panel must not cover Cindermite."
	)
	screen.free()


func _test_move_button_resolves_a_complete_turn() -> void:
	begin_case("move selection resolves battle turn")
	var fixture := _battle_fixture([0.0, 0.5, 1.0, 0.0, 0.5, 1.0])
	var screen := fixture["screen"] as BattleScreen
	var manager := fixture["manager"] as BattleManager
	var opponent_hp := manager.get_participant(BattleConstants.SIDE_OPPONENT).current_hp
	assert_true(screen.choose_move(&"cinder_jab"))
	assert_equal(manager.turn_number, 2)
	assert_true(manager.get_participant(BattleConstants.SIDE_OPPONENT).current_hp < opponent_hp)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_MOVE_USED).size(), 2)
	assert_true(screen.battle_log.text.contains("Cinder Jab"))
	assert_true(screen.opponent_health.value < 100.0)
	screen.free()


func _test_victory_awards_experience_and_updates_level_bar() -> void:
	begin_case("victory XP and level-up presentation")
	var inventory := Inventory.new()
	var player := BattleTestFactory.create_creature(&"cindermite", 1, [&"updraft"])
	player.total_experience = 0
	var wild := BattleTestFactory.create_creature(&"gustlet", 1, [&"brook_bash"], 1)
	wild.instance_id = "wild-gustlet-xp-ui"
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0], 0.2)
	)
	manager.start_wild_battle(
		[player], wild, inventory, CreatureCollection.new()
	)
	var screen := BATTLE_SCENE.instantiate() as BattleScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.initialize(catalog, manager, inventory, PlayerPreferences.new())
	assert_float_equal(screen.player_experience.value, 0.0)
	assert_true(screen.choose_move(&"updraft"))
	assert_equal(manager.outcome, BattleConstants.OUTCOME_PLAYER_VICTORY)
	assert_true(manager.progression_rewards_claimed)
	assert_not_null(screen.last_battle_progression)
	assert_true(screen.last_battle_progression.success)
	assert_equal(screen.last_battle_progression.reward_pool, 12)
	assert_equal(player.total_experience, 12)
	assert_equal(player.level, 2)
	assert_equal(screen.player_name.text, "Cindermite   Lv. 2")
	assert_true(screen.player_experience_text.text.contains("XP  5 / 19"))
	assert_true(screen.player_experience_text.text.contains("Total 12"))
	assert_float_equal(screen.player_experience.value, 5.0 / 19.0 * 100.0, 0.01)
	assert_true(screen.battle_log.text.contains("gained 12 XP"))
	assert_true(screen.battle_log.text.contains("Level up! 1 → 2"))
	assert_true(screen.finish_detail.text.contains("+12 XP"))
	assert_true(screen.finish_detail.text.contains("LEVEL UP!  1 → 2"))
	screen.free()


func _test_run_shows_result_and_emits_close() -> void:
	begin_case("run result and close signal")
	var fixture := _battle_fixture()
	var screen := fixture["screen"] as BattleScreen
	var manager := fixture["manager"] as BattleManager
	var emitted_outcome: Array[StringName] = []
	screen.battle_closed.connect(func(outcome: StringName) -> void:
		emitted_outcome.append(outcome)
	)
	assert_true(screen.choose_run())
	assert_equal(manager.outcome, BattleConstants.OUTCOME_PLAYER_ESCAPED)
	assert_true(screen.finish_panel.visible)
	assert_equal(screen.finish_title.text, "SAFE RETREAT")
	screen.close_battle()
	assert_false(screen.visible)
	assert_equal(emitted_outcome, [BattleConstants.OUTCOME_PLAYER_ESCAPED])
	screen.free()


func _test_exploration_encounter_opens_playable_battle() -> void:
	begin_case("encounter to playable battle bridge")
	var exploration := EXPLORATION_SCENE.instantiate() as ExplorationScreen
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(exploration)
	exploration.initialize(catalog, PlayerPreferences.new())
	var request := WildEncounterRequest.new()
	request.encounter_id = "ui-integration-encounter"
	request.map_id = &"mosslight_crossing"
	request.zone_id = &"sunmeadow_grass"
	request.grid_position = Vector2i(5, 8)
	request.species_id = &"gustlet"
	request.level = 5
	exploration.session.state.phase = ExplorationConstants.PHASE_BATTLE_TRANSITION
	exploration._begin_battle_transition(request)
	assert_true(exploration.battle_screen.visible)
	assert_not_null(exploration.active_battle)
	assert_equal(
		exploration.active_battle.phase,
		BattleConstants.PHASE_AWAITING_COMMANDS
	)
	assert_true(exploration.battle_screen.get_move_button_count() > 0)
	assert_true(exploration.battle_screen.choose_run())
	exploration.battle_screen.close_battle()
	assert_equal(exploration.active_battle, null)
	assert_equal(exploration.session.state.phase, ExplorationConstants.PHASE_ACTIVE)
	exploration.free()
