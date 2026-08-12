class_name BattleAiController
extends RefCounted
## Deterministic heuristic AI. It returns commands instead of mutating the
## battle, keeping decision policy separate from command validation/resolution.

const LOW_HP_SWITCH_THRESHOLD := 0.25
const STATUS_BASE_SCORES := {
	&"drowsy": 65.0,
	&"scorch": 45.0,
	&"rooted": 35.0,
}

var _catalog: ContentCatalog
var _random: BattleRandomSource
var _type_service: TypeEffectivenessService


func _init(
	catalog: ContentCatalog,
	random_source: BattleRandomSource = null
) -> void:
	_catalog = catalog
	_random = random_source if random_source != null else SeededBattleRandomSource.new(0)
	_type_service = TypeEffectivenessService.new(catalog)


func choose_command(
	battle: BattleManager,
	side: StringName = BattleConstants.SIDE_OPPONENT
) -> BattleCommand:
	if battle == null or battle.phase != BattleConstants.PHASE_AWAITING_COMMANDS:
		return null
	var actor := battle.get_participant(side)
	var defender := battle.get_participant(BattleConstants.opposing_side(side))
	if actor == null or defender == null or actor.is_defeated():
		return null

	var switch_command := _choose_low_hp_switch(battle, side, actor, defender)
	if switch_command != null:
		return switch_command
	return _choose_move(actor, defender)


func _choose_low_hp_switch(
	battle: BattleManager,
	side: StringName,
	actor: BattleParticipant,
	defender: BattleParticipant
) -> SwitchCreatureCommand:
	if float(actor.current_hp) / float(maxi(actor.get_max_hp(), 1)) > LOW_HP_SWITCH_THRESHOLD:
		return null
	if not battle.status_effect_service.can_switch(actor):
		return null
	var party := battle.get_party(side)
	if party == null:
		return null
	var candidates := party.get_available_bench()
	if candidates.is_empty():
		return null

	var best_score := -INF
	var best_candidates: Array[BattleParticipant] = []
	for candidate in candidates:
		var score := _switch_candidate_score(candidate, defender)
		if score > best_score + 0.0001:
			best_score = score
			best_candidates = [candidate]
		elif is_equal_approx(score, best_score):
			best_candidates.append(candidate)
	var chosen := best_candidates[_random.next_int(best_candidates.size())]
	return SwitchCreatureCommand.new(side, chosen.creature.instance_id)


func _choose_move(
	actor: BattleParticipant,
	defender: BattleParticipant
) -> UseMoveCommand:
	var best_score := -INF
	var best_move_ids: Array[StringName] = []
	var move_ids: Array[StringName] = []
	for raw_move_id in actor.move_slots_by_id.keys():
		move_ids.append(StringName(str(raw_move_id)))
	move_ids.sort()
	for move_id in move_ids:
		var slot := actor.get_move_slot(move_id)
		var move := _catalog.get_move(move_id)
		if slot == null or not slot.can_use() or move == null:
			continue
		var score := _score_move(actor, defender, move)
		if score > best_score + 0.0001:
			best_score = score
			best_move_ids = [move_id]
		elif is_equal_approx(score, best_score):
			best_move_ids.append(move_id)
	if best_move_ids.is_empty():
		return null
	return UseMoveCommand.new(
		actor.side,
		best_move_ids[_random.next_int(best_move_ids.size())]
	)


func _score_move(
	actor: BattleParticipant,
	defender: BattleParticipant,
	move: MoveDefinition
) -> float:
	var hit_rate := move.accuracy / 100.0
	if move.category == "status":
		if str(move.status_effect_id).is_empty() or defender.has_status(move.status_effect_id):
			return 0.0
		return float(STATUS_BASE_SCORES.get(move.status_effect_id, 25.0)) * hit_rate

	var attack := actor.calculated_stats.attack
	var defense := defender.calculated_stats.defense
	if move.category == "special":
		attack = actor.calculated_stats.special_attack
		defense = defender.calculated_stats.special_defense
	var same_type := DamageCalculator.SAME_TYPE_BONUS \
		if actor.species.element_types.has(move.element_type_id) else 1.0
	var effectiveness := _type_service.get_multiplier(
		move.element_type_id,
		defender.species.element_types
	)
	return move.power \
		* hit_rate \
		* same_type \
		* effectiveness \
		* (float(attack) / float(maxi(defense, 1))) \
		+ move.priority * 2.0


func _switch_candidate_score(
	candidate: BattleParticipant,
	opponent: BattleParticipant
) -> float:
	var incoming_pressure := 0.0
	var incoming_count := 0
	for raw_move_id in opponent.move_slots_by_id.keys():
		var move := _catalog.get_move(StringName(str(raw_move_id)))
		if move != null and move.category != "status":
			incoming_pressure += _type_service.get_multiplier(
				move.element_type_id,
				candidate.species.element_types
			)
			incoming_count += 1
	if incoming_count > 0:
		incoming_pressure /= incoming_count
	else:
		incoming_pressure = 1.0

	var best_offense := 0.0
	for raw_move_id in candidate.move_slots_by_id.keys():
		var move := _catalog.get_move(StringName(str(raw_move_id)))
		if move != null:
			best_offense = maxf(best_offense, _score_move(candidate, opponent, move))
	return best_offense - incoming_pressure * 50.0

