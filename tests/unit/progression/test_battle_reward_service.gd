extends TestSuite

var catalog: ContentCatalog
var experience := ExperienceCalculator.new()


func _init() -> void:
	super("BattleRewardService")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_wild_victory_awards_participant_once()
	_test_trainer_reward_is_shared_by_participants()
	_test_unfinished_and_non_victory_battles_are_rejected()


func _creature(
	species_id: StringName,
	level: int,
	moves: Array[StringName],
	hp: int = 99999,
	suffix: String = ""
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, level, moves, hp)
	if not suffix.is_empty():
		creature.instance_id += "-" + suffix
	var species := catalog.get_species(species_id)
	creature.total_experience = experience.total_experience_for_level(
		catalog.get_growth_curve(species.growth_curve_id), level
	)
	return creature


func _typed_party(creatures: Array[CreatureInstance]) -> Array[CreatureInstance]:
	return creatures


func _test_wild_victory_awards_participant_once() -> void:
	begin_case("wild victory reward")
	var player := _creature(&"cindermite", 1, [&"updraft"])
	var opponent := _creature(&"gustlet", 5, [&"brook_bash"], 1, "wild")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_wild_battle(
		_typed_party([player]), opponent, Inventory.new(), CreatureCollection.new()
	)
	manager.submit_command(UseMoveCommand.new(&"player", &"updraft"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_equal(manager.outcome, BattleConstants.OUTCOME_PLAYER_VICTORY)
	var observed: Array[String] = []
	var service := BattleRewardService.new(catalog)
	service.progression_applied.connect(func(instance_id: String, _result: ProgressionResult) -> void:
		observed.append(instance_id)
	)
	var reward := service.award_player_victory(manager)
	assert_true(reward.success)
	assert_equal(reward.reward_pool, 60)
	assert_equal(reward.experience_by_instance_id[player.instance_id], 60)
	assert_equal(reward.total_experience_applied(), 60)
	assert_equal(observed, [player.instance_id])
	assert_true(manager.progression_rewards_claimed)
	assert_equal(
		service.award_player_victory(manager).reason,
		&"rewards_already_claimed"
	)


func _test_trainer_reward_is_shared_by_participants() -> void:
	begin_case("trainer participation sharing")
	var first := _creature(&"cindermite", 20, [&"cinder_jab"], 99999, "first")
	var second := _creature(&"reedling", 20, [&"updraft"], 99999, "second")
	var opponent := _creature(&"gustlet", 1, [&"brook_bash"], 1, "trainer")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([
			0.0, 0.5, 1.0,
			0.0, 0.5, 1.0,
		])
	)
	manager.start_party_battle(
		_typed_party([first, second]),
		_typed_party([opponent])
	)
	manager.submit_command(SwitchCreatureCommand.new(&"player", second.instance_id))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	manager.submit_command(UseMoveCommand.new(&"player", &"updraft"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_equal(manager.get_participating_instance_ids(&"player"), [
		first.instance_id, second.instance_id,
	])
	var reward := BattleRewardService.new(catalog).award_player_victory(manager)
	assert_true(reward.success)
	assert_equal(reward.reward_pool, 15)
	assert_equal(reward.experience_by_instance_id[first.instance_id], 8)
	assert_equal(reward.experience_by_instance_id[second.instance_id], 7)
	assert_equal(reward.total_experience_applied(), 15)
	assert_equal(reward.progression_by_instance_id.size(), 2)


func _test_unfinished_and_non_victory_battles_are_rejected() -> void:
	begin_case("non-rewardable battle")
	var service := BattleRewardService.new(catalog)
	assert_equal(service.award_player_victory(null).reason, &"missing_battle")
	var manager := BattleManager.new(catalog)
	assert_equal(service.award_player_victory(manager).reason, &"battle_not_rewardable")
	manager.start_battle(
		_creature(&"cindermite", 1, [&"cinder_jab"]),
		_creature(&"gustlet", 1, [&"updraft"])
	)
	assert_equal(service.award_player_victory(manager).reason, &"battle_not_rewardable")
