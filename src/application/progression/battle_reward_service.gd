class_name BattleRewardService
extends RefCounted
## Awards defeated-opponent XP once to player creatures that actually entered
## battle. Integer remainder is assigned in participation order.

signal progression_applied(instance_id: String, result: ProgressionResult)

var _progression: ProgressionService
var _reward_calculator := ExperienceRewardCalculator.new()


func _init(catalog: ContentCatalog) -> void:
	_progression = ProgressionService.new(catalog)


func award_player_victory(battle: BattleManager) -> BattleProgressionResult:
	var result := BattleProgressionResult.new()
	if battle == null:
		result.reason = &"missing_battle"
		return result
	if battle.phase != BattleConstants.PHASE_FINISHED \
		or battle.outcome != BattleConstants.OUTCOME_PLAYER_VICTORY:
		result.reason = &"battle_not_rewardable"
		return result
	if battle.progression_rewards_claimed:
		result.reason = &"rewards_already_claimed"
		return result
	var player_party := battle.get_party(BattleConstants.SIDE_PLAYER)
	var opponent_party := battle.get_party(BattleConstants.SIDE_OPPONENT)
	if player_party == null or opponent_party == null:
		result.reason = &"missing_battle_party"
		return result
	var participant_ids := battle.get_participating_instance_ids(
		BattleConstants.SIDE_PLAYER
	)
	if participant_ids.is_empty():
		result.reason = &"no_player_participants"
		return result
	for opponent in opponent_party.members:
		if opponent.is_defeated():
			result.reward_pool += _reward_calculator.calculate(
				opponent.species,
				opponent.creature.level,
				not battle.is_wild_encounter
			)
	if result.reward_pool <= 0:
		result.reason = &"no_defeated_opponents"
		return result

	var share := floori(float(result.reward_pool) / participant_ids.size())
	var remainder := result.reward_pool % participant_ids.size()
	for index in participant_ids.size():
		var instance_id := participant_ids[index]
		var participant := player_party.get_member(instance_id)
		if participant == null:
			continue
		var requested := share + (1 if index < remainder else 0)
		var progression_result := _progression.grant_experience(
			participant.creature,
			requested
		)
		result.experience_by_instance_id[instance_id] = progression_result.experience_gained
		result.progression_by_instance_id[instance_id] = progression_result
		progression_applied.emit(instance_id, progression_result)
	battle.progression_rewards_claimed = true
	result.success = true
	return result
