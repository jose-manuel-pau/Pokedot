class_name BattleManager
extends RefCounted
## One-versus-one battle state machine. It validates commands, resolves turn
## order, applies deterministic move results, evaluates outcomes, and publishes
## domain events without depending on a scene or UI.

signal phase_changed(previous_phase: StringName, current_phase: StringName)
signal event_emitted(event: BattleEvent)

var phase: StringName = BattleConstants.PHASE_NOT_STARTED
var outcome: StringName = BattleConstants.OUTCOME_NONE
var turn_number: int = 0
var last_error: StringName = &""
var participants_by_side: Dictionary = {}
var pending_commands_by_side: Dictionary = {}
var event_history: Array[BattleEvent] = []

var _catalog: ContentCatalog
var _stat_calculator := StatCalculator.new()
var _random: BattleRandomSource
var _damage_calculator: DamageCalculator
var _turn_order_resolver: TurnOrderResolver


func _init(
	catalog: ContentCatalog,
	random_source: BattleRandomSource = null
) -> void:
	_catalog = catalog
	_random = random_source if random_source != null else SeededBattleRandomSource.new(0)
	_damage_calculator = DamageCalculator.new(
		TypeEffectivenessService.new(_catalog),
		_random
	)
	_turn_order_resolver = TurnOrderResolver.new(_random)


func start_battle(
	player_creature: CreatureInstance,
	opponent_creature: CreatureInstance
) -> bool:
	last_error = &""
	if phase != BattleConstants.PHASE_NOT_STARTED:
		return _reject(&"battle_already_started")
	if player_creature == null or opponent_creature == null:
		return _reject(&"missing_creature")
	var player_species := _catalog.get_species(player_creature.species_id)
	var opponent_species := _catalog.get_species(opponent_creature.species_id)
	if player_species == null or opponent_species == null:
		return _reject(&"unknown_species")

	var player := BattleParticipant.from_instance(
		BattleConstants.SIDE_PLAYER,
		player_species,
		player_creature,
		_catalog,
		_stat_calculator
	)
	var opponent := BattleParticipant.from_instance(
		BattleConstants.SIDE_OPPONENT,
		opponent_species,
		opponent_creature,
		_catalog,
		_stat_calculator
	)
	if player.is_defeated() or opponent.is_defeated():
		return _reject(&"creature_already_defeated")
	if player.move_slots_by_id.is_empty() or opponent.move_slots_by_id.is_empty():
		return _reject(&"creature_has_no_moves")

	participants_by_side[BattleConstants.SIDE_PLAYER] = player
	participants_by_side[BattleConstants.SIDE_OPPONENT] = opponent
	turn_number = 1
	_change_phase(BattleConstants.PHASE_AWAITING_COMMANDS)
	_emit_event(BattleConstants.EVENT_BATTLE_STARTED, {
		"player_species_id": player_species.species_id,
		"opponent_species_id": opponent_species.species_id,
	})
	_emit_event(BattleConstants.EVENT_TURN_STARTED)
	return true


func submit_command(command: BattleCommand) -> bool:
	last_error = &""
	if command == null:
		return _reject_command(command, &"missing_command")
	if phase != BattleConstants.PHASE_AWAITING_COMMANDS:
		return _reject_command(command, &"commands_not_accepted")
	if not BattleConstants.is_valid_side(command.actor_side):
		return _reject_command(command, &"unknown_side")
	if pending_commands_by_side.has(command.actor_side):
		return _reject_command(command, &"command_already_submitted")
	var participant := get_participant(command.actor_side)
	if participant == null:
		return _reject_command(command, &"missing_participant")
	if participant.is_defeated():
		return _reject_command(command, &"actor_defeated")
	var validation_error := command.validate(participant, _catalog)
	if not str(validation_error).is_empty():
		return _reject_command(command, validation_error)

	pending_commands_by_side[command.actor_side] = command
	_emit_event(BattleConstants.EVENT_COMMAND_SUBMITTED, {
		"side": command.actor_side,
		"command_kind": command.get_kind(),
	})
	return true


func can_resolve_turn() -> bool:
	return phase == BattleConstants.PHASE_AWAITING_COMMANDS \
		and pending_commands_by_side.has(BattleConstants.SIDE_PLAYER) \
		and pending_commands_by_side.has(BattleConstants.SIDE_OPPONENT)


func resolve_turn() -> bool:
	last_error = &""
	if not can_resolve_turn():
		return _reject(&"turn_not_ready")
	_change_phase(BattleConstants.PHASE_RESOLVING_TURN)

	var commands: Array[BattleCommand] = [
		pending_commands_by_side[BattleConstants.SIDE_PLAYER],
		pending_commands_by_side[BattleConstants.SIDE_OPPONENT],
	]
	var ordered_commands := _turn_order_resolver.resolve(
		commands,
		participants_by_side,
		_catalog
	)
	for command in ordered_commands:
		var actor := get_participant(command.actor_side)
		if actor == null or actor.is_defeated():
			_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
				"side": command.actor_side,
				"reason": &"actor_defeated",
			})
			continue
		_resolve_command(command)

	pending_commands_by_side.clear()
	_evaluate_outcome()
	if phase == BattleConstants.PHASE_FINISHED:
		return true
	_emit_event(BattleConstants.EVENT_TURN_ENDED)
	turn_number += 1
	_change_phase(BattleConstants.PHASE_AWAITING_COMMANDS)
	_emit_event(BattleConstants.EVENT_TURN_STARTED)
	return true


func get_participant(side: StringName) -> BattleParticipant:
	return participants_by_side.get(side) as BattleParticipant


func events_of_type(event_type: StringName) -> Array[BattleEvent]:
	var matches: Array[BattleEvent] = []
	for event in event_history:
		if event.event_type == event_type:
			matches.append(event)
	return matches


func _resolve_command(command: BattleCommand) -> void:
	if command is UseMoveCommand:
		_resolve_use_move(command as UseMoveCommand)
		return
	_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
		"side": command.actor_side,
		"reason": &"unsupported_command",
	})


func _resolve_use_move(command: UseMoveCommand) -> void:
	var attacker := get_participant(command.actor_side)
	var defender := get_participant(BattleConstants.opposing_side(command.actor_side))
	var move := _catalog.get_move(command.move_id)
	var slot := attacker.get_move_slot(command.move_id)
	if move == null or slot == null or not slot.consume():
		_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
			"side": command.actor_side,
			"reason": &"move_became_unavailable",
		})
		return

	_emit_event(BattleConstants.EVENT_MOVE_USED, {
		"side": command.actor_side,
		"move_id": move.move_id,
		"remaining_uses": slot.remaining_uses,
	})
	var damage_result := _damage_calculator.resolve(attacker, defender, move)
	if not damage_result.hit:
		_emit_event(BattleConstants.EVENT_MOVE_MISSED, {
			"side": command.actor_side,
			"move_id": move.move_id,
			"accuracy_roll": damage_result.accuracy_roll,
		})
		return
	if move.category == "status":
		_emit_event(BattleConstants.EVENT_STATUS_MOVE_RESOLVED, {
			"side": command.actor_side,
			"move_id": move.move_id,
			"status_effect_id": move.status_effect_id,
		})
		return

	var applied_damage := defender.apply_damage(damage_result.damage)
	_emit_event(BattleConstants.EVENT_DAMAGE_DEALT, {
		"source_side": command.actor_side,
		"target_side": defender.side,
		"move_id": move.move_id,
		"damage": applied_damage,
		"target_hp": defender.current_hp,
		"critical": damage_result.critical,
		"type_multiplier": damage_result.type_multiplier,
	})
	if defender.is_defeated():
		_emit_event(BattleConstants.EVENT_CREATURE_DEFEATED, {
			"side": defender.side,
			"species_id": defender.species.species_id,
		})


func _evaluate_outcome() -> void:
	var player_defeated := get_participant(BattleConstants.SIDE_PLAYER).is_defeated()
	var opponent_defeated := get_participant(BattleConstants.SIDE_OPPONENT).is_defeated()
	if not player_defeated and not opponent_defeated:
		return
	if player_defeated and opponent_defeated:
		outcome = BattleConstants.OUTCOME_DRAW
	elif opponent_defeated:
		outcome = BattleConstants.OUTCOME_PLAYER_VICTORY
	else:
		outcome = BattleConstants.OUTCOME_OPPONENT_VICTORY
	_change_phase(BattleConstants.PHASE_FINISHED)
	_emit_event(BattleConstants.EVENT_BATTLE_FINISHED, {"outcome": outcome})


func _change_phase(next_phase: StringName) -> void:
	var previous_phase := phase
	phase = next_phase
	phase_changed.emit(previous_phase, phase)


func _emit_event(event_type: StringName, payload: Dictionary = {}) -> void:
	var event := BattleEvent.create(event_type, turn_number, payload)
	event_history.append(event)
	event_emitted.emit(event)


func _reject(error: StringName) -> bool:
	last_error = error
	return false


func _reject_command(command: BattleCommand, error: StringName) -> bool:
	last_error = error
	if turn_number > 0:
		var rejected_side: StringName = &""
		if command != null:
			rejected_side = command.actor_side
		_emit_event(BattleConstants.EVENT_COMMAND_REJECTED, {
			"side": rejected_side,
			"reason": error,
		})
	return false
