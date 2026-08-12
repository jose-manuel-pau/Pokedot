class_name BattleManager
extends RefCounted
## Party-capable battle state machine. The one-versus-one API remains the
## simplest entry point. It validates commands, resolves deterministic turns,
## applies status hooks, evaluates party outcomes, and publishes domain events.

signal phase_changed(previous_phase: StringName, current_phase: StringName)
signal event_emitted(event: BattleEvent)

var phase: StringName = BattleConstants.PHASE_NOT_STARTED
var outcome: StringName = BattleConstants.OUTCOME_NONE
var turn_number: int = 0
var last_error: StringName = &""
var participants_by_side: Dictionary = {}
var parties_by_side: Dictionary = {}
var pending_commands_by_side: Dictionary = {}
var event_history: Array[BattleEvent] = []
var status_effect_service: StatusEffectService
var inventories_by_side: Dictionary = {}
var is_wild_encounter: bool = false

var _catalog: ContentCatalog
var _stat_calculator := StatCalculator.new()
var _random: BattleRandomSource
var _damage_calculator: DamageCalculator
var _turn_order_resolver: TurnOrderResolver
var _inventory_service: InventoryService
var _item_effect_service: ItemEffectService
var _capture_service: CaptureService
var _collection_service := CreatureCollectionService.new()
var _capture_collection: CreatureCollection
var _encounter_capture_multiplier: float = 1.0


func _init(
	catalog: ContentCatalog,
	random_source: BattleRandomSource = null
) -> void:
	_catalog = catalog
	_random = random_source if random_source != null else SeededBattleRandomSource.new(0)
	status_effect_service = StatusEffectService.new(_catalog)
	_damage_calculator = DamageCalculator.new(
		TypeEffectivenessService.new(_catalog),
		_random,
		status_effect_service
	)
	_turn_order_resolver = TurnOrderResolver.new(_random, status_effect_service)
	_inventory_service = InventoryService.new(_catalog)
	_item_effect_service = ItemEffectService.new(_catalog, status_effect_service)
	_capture_service = CaptureService.new(_catalog, _random)


func start_battle(
	player_creature: CreatureInstance,
	opponent_creature: CreatureInstance
) -> bool:
	var player_party: Array[CreatureInstance] = []
	var opponent_party: Array[CreatureInstance] = []
	if player_creature != null:
		player_party.append(player_creature)
	if opponent_creature != null:
		opponent_party.append(opponent_creature)
	return start_party_battle(player_party, opponent_party)


func start_party_battle(
	player_creatures: Array[CreatureInstance],
	opponent_creatures: Array[CreatureInstance]
) -> bool:
	last_error = &""
	if phase != BattleConstants.PHASE_NOT_STARTED:
		return _reject(&"battle_already_started")
	if player_creatures.is_empty() or opponent_creatures.is_empty():
		return _reject(&"missing_creature")
	if player_creatures.size() > BattleParty.MAX_MEMBERS \
		or opponent_creatures.size() > BattleParty.MAX_MEMBERS:
		return _reject(&"party_too_large")

	var player_party := _create_party(BattleConstants.SIDE_PLAYER, player_creatures)
	if player_party == null:
		return false
	var opponent_party := _create_party(BattleConstants.SIDE_OPPONENT, opponent_creatures)
	if opponent_party == null:
		return false
	if player_party.get_active().is_defeated() \
		or opponent_party.get_active().is_defeated():
		return _reject(&"creature_already_defeated")

	parties_by_side[BattleConstants.SIDE_PLAYER] = player_party
	parties_by_side[BattleConstants.SIDE_OPPONENT] = opponent_party
	participants_by_side[BattleConstants.SIDE_PLAYER] = player_party.get_active()
	participants_by_side[BattleConstants.SIDE_OPPONENT] = opponent_party.get_active()
	turn_number = 1
	_change_phase(BattleConstants.PHASE_AWAITING_COMMANDS)
	_emit_event(BattleConstants.EVENT_BATTLE_STARTED, {
		"player_species_id": player_party.get_active().species.species_id,
		"opponent_species_id": opponent_party.get_active().species.species_id,
		"player_party_size": player_party.members.size(),
		"opponent_party_size": opponent_party.members.size(),
	})
	_emit_event(BattleConstants.EVENT_TURN_STARTED)
	return true


func start_wild_battle(
	player_creatures: Array[CreatureInstance],
	wild_creature: CreatureInstance,
	player_inventory: Inventory,
	collection: CreatureCollection,
	encounter_multiplier: float = 1.0
) -> bool:
	last_error = &""
	if player_inventory == null:
		return _reject(&"missing_inventory")
	if collection == null:
		return _reject(&"missing_collection")
	if wild_creature == null:
		return _reject(&"missing_creature")
	var wild_party: Array[CreatureInstance] = [wild_creature]
	if not start_party_battle(player_creatures, wild_party):
		return false
	is_wild_encounter = true
	inventories_by_side[BattleConstants.SIDE_PLAYER] = player_inventory
	_capture_collection = collection
	_encounter_capture_multiplier = maxf(encounter_multiplier, 0.0)
	return true


func assign_inventory(side: StringName, inventory: Inventory) -> bool:
	last_error = &""
	if not BattleConstants.is_valid_side(side):
		return _reject(&"unknown_side")
	if inventory == null:
		return _reject(&"missing_inventory")
	inventories_by_side[side] = inventory
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
	if command is SwitchCreatureCommand:
		validation_error = _validate_switch_command(command as SwitchCreatureCommand)
		if not str(validation_error).is_empty():
			return _reject_command(command, validation_error)
	elif command is UseItemCommand:
		validation_error = _validate_item_command(command as UseItemCommand)
		if not str(validation_error).is_empty():
			return _reject_command(command, validation_error)
	elif command is CaptureCommand:
		validation_error = _validate_capture_command(command as CaptureCommand)
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
		if phase == BattleConstants.PHASE_FINISHED:
			break

	pending_commands_by_side.clear()
	if phase == BattleConstants.PHASE_FINISHED:
		return true
	_process_end_turn_statuses()
	_resolve_forced_switches()
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


func get_party(side: StringName) -> BattleParty:
	return parties_by_side.get(side) as BattleParty


func submit_ai_command(
	ai: BattleAiController,
	side: StringName = BattleConstants.SIDE_OPPONENT
) -> bool:
	if ai == null:
		return _reject(&"missing_ai")
	var command := ai.choose_command(self, side)
	if command == null:
		return _reject(&"ai_no_command")
	return submit_command(command)


func events_of_type(event_type: StringName) -> Array[BattleEvent]:
	var matches: Array[BattleEvent] = []
	for event in event_history:
		if event.event_type == event_type:
			matches.append(event)
	return matches


func _resolve_command(command: BattleCommand) -> void:
	if command is SwitchCreatureCommand:
		_resolve_switch(command as SwitchCreatureCommand, false)
		return
	if command is UseMoveCommand:
		var actor := get_participant(command.actor_side)
		if not status_effect_service.can_act(actor):
			_emit_event(BattleConstants.EVENT_STATUS_BLOCKED_ACTION, {
				"side": command.actor_side,
				"status_id": status_effect_service.first_action_blocker(actor),
			})
			return
		_resolve_use_move(command as UseMoveCommand)
		return
	if command is UseItemCommand:
		_resolve_use_item(command as UseItemCommand)
		return
	if command is CaptureCommand:
		_resolve_capture(command as CaptureCommand)
		return
	_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
		"side": command.actor_side,
		"reason": &"unsupported_command",
	})


func _resolve_use_item(command: UseItemCommand) -> void:
	var inventory := inventories_by_side.get(command.actor_side) as Inventory
	var party := get_party(command.actor_side)
	var target := party.get_member(command.target_instance_id) if party != null else null
	var effect_error := _item_effect_service.validate(command.item_id, target)
	if not str(effect_error).is_empty():
		_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
			"side": command.actor_side,
			"reason": effect_error,
		})
		return
	var item := _catalog.get_item(command.item_id)
	if item.consumable:
		var transaction := _inventory_service.remove(inventory, command.item_id)
		if not transaction.success:
			_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
				"side": command.actor_side,
				"reason": transaction.reason,
			})
			return
	var effect := _item_effect_service.apply(command.item_id, target)
	_emit_event(BattleConstants.EVENT_ITEM_USED, {
		"side": command.actor_side,
		"item_id": command.item_id,
		"target_instance_id": command.target_instance_id,
		"healing_applied": effect.healing_applied,
		"removed_status_ids": effect.removed_status_ids,
		"quantity_after": inventory.get_quantity(command.item_id),
	})
	for status_id in effect.removed_status_ids:
		_emit_event(BattleConstants.EVENT_STATUS_REMOVED, {
			"side": target.side,
			"status_id": status_id,
			"reason": &"item_used",
		})


func _resolve_capture(command: CaptureCommand) -> void:
	var inventory := inventories_by_side.get(command.actor_side) as Inventory
	var transaction := _inventory_service.remove(inventory, command.device_item_id)
	if not transaction.success:
		_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
			"side": command.actor_side,
			"reason": transaction.reason,
		})
		return
	var target := get_participant(BattleConstants.SIDE_OPPONENT)
	var result := _capture_service.attempt(
		target,
		_catalog.get_item(command.device_item_id),
		_encounter_capture_multiplier
	)
	_emit_event(BattleConstants.EVENT_CAPTURE_ATTEMPTED, {
		"side": command.actor_side,
		"device_item_id": command.device_item_id,
		"target_instance_id": target.creature.instance_id,
		"chance": result.chance,
		"success_roll": result.success_roll,
		"critical": result.critical,
		"success": result.success,
		"quantity_after": transaction.quantity_after,
	})
	if not result.success:
		return
	var addition := _collection_service.add_captured(
		_capture_collection,
		target.creature
	)
	if not addition.success:
		_emit_event(BattleConstants.EVENT_COMMAND_SKIPPED, {
			"side": command.actor_side,
			"reason": addition.reason,
		})
		return
	outcome = BattleConstants.OUTCOME_OPPONENT_CAPTURED
	_emit_event(BattleConstants.EVENT_CREATURE_CAPTURED, {
		"species_id": target.species.species_id,
		"instance_id": target.creature.instance_id,
		"destination": addition.destination,
		"critical": result.critical,
	})
	_change_phase(BattleConstants.PHASE_FINISHED)
	_emit_event(BattleConstants.EVENT_BATTLE_FINISHED, {"outcome": outcome})


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
		_try_apply_move_status(defender, move)
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
		_emit_defeat(defender)
	else:
		_try_apply_move_status(defender, move)


func _try_apply_move_status(
	target: BattleParticipant,
	move: MoveDefinition
) -> void:
	if str(move.status_effect_id).is_empty() or move.status_chance <= 0.0:
		return
	var applied_by_chance := move.status_chance >= 100.0 \
		or _random.next_float() * 100.0 < move.status_chance
	if not applied_by_chance:
		_emit_event(BattleConstants.EVENT_STATUS_APPLICATION_FAILED, {
			"side": target.side,
			"status_id": move.status_effect_id,
			"reason": &"chance_failed",
		})
		return
	var result := status_effect_service.apply_status(
		target,
		move.status_effect_id,
		turn_number
	)
	if result == &"applied" or result == &"stacked":
		_emit_event(BattleConstants.EVENT_STATUS_APPLIED, {
			"side": target.side,
			"status_id": move.status_effect_id,
			"result": result,
		})
	else:
		_emit_event(BattleConstants.EVENT_STATUS_APPLICATION_FAILED, {
			"side": target.side,
			"status_id": move.status_effect_id,
			"reason": result,
		})


func _process_end_turn_statuses() -> void:
	for side in [BattleConstants.SIDE_PLAYER, BattleConstants.SIDE_OPPONENT]:
		var participant := get_participant(side)
		if participant == null or participant.is_defeated():
			continue
		for result in status_effect_service.process_end_turn(participant, turn_number):
			if result.damage > 0:
				_emit_event(BattleConstants.EVENT_STATUS_DAMAGE, {
					"side": side,
					"status_id": result.status_id,
					"damage": result.damage,
					"target_hp": participant.current_hp,
				})
			if result.removed:
				_emit_event(BattleConstants.EVENT_STATUS_REMOVED, {
					"side": side,
					"status_id": result.status_id,
					"reason": &"duration_expired",
				})
		if participant.is_defeated():
			_emit_defeat(participant)


func _resolve_switch(command: SwitchCreatureCommand, forced: bool) -> bool:
	var party := get_party(command.actor_side)
	if party == null or not party.can_switch_to(command.target_instance_id):
		return false
	var outgoing := party.get_active()
	for status_id in status_effect_service.clear_volatile_statuses(outgoing):
		_emit_event(BattleConstants.EVENT_STATUS_REMOVED, {
			"side": command.actor_side,
			"status_id": status_id,
			"reason": &"switched_out",
		})
	if not party.switch_to(command.target_instance_id):
		return false
	var incoming := party.get_active()
	participants_by_side[command.actor_side] = incoming
	_emit_event(BattleConstants.EVENT_CREATURE_SWITCHED, {
		"side": command.actor_side,
		"outgoing_instance_id": outgoing.creature.instance_id,
		"incoming_instance_id": incoming.creature.instance_id,
		"incoming_species_id": incoming.species.species_id,
		"forced": forced,
	})
	return true


func _resolve_forced_switches() -> void:
	for side in [BattleConstants.SIDE_PLAYER, BattleConstants.SIDE_OPPONENT]:
		var party := get_party(side)
		if party == null or not party.get_active().is_defeated():
			continue
		var replacement := party.first_available_bench()
		if replacement != null:
			_resolve_switch(
				SwitchCreatureCommand.new(side, replacement.creature.instance_id),
				true
			)


func _evaluate_outcome() -> void:
	var player_party := get_party(BattleConstants.SIDE_PLAYER)
	var opponent_party := get_party(BattleConstants.SIDE_OPPONENT)
	var player_defeated := player_party == null or not player_party.has_usable_members()
	var opponent_defeated := opponent_party == null or not opponent_party.has_usable_members()
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


func _validate_switch_command(command: SwitchCreatureCommand) -> StringName:
	var party := get_party(command.actor_side)
	if party == null:
		return &"missing_party"
	if party.get_active().creature.instance_id == command.target_instance_id:
		return &"target_already_active"
	var target := party.get_member(command.target_instance_id)
	if target == null:
		return &"unknown_switch_target"
	if target.is_defeated():
		return &"switch_target_defeated"
	if not status_effect_service.can_switch(party.get_active()):
		return &"switch_blocked_by_status"
	return &""


func _validate_item_command(command: UseItemCommand) -> StringName:
	var item := _catalog.get_item(command.item_id)
	if item == null:
		return &"unknown_item"
	if not item.battle_usable:
		return &"item_not_battle_usable"
	if item.is_capture_device():
		return &"capture_device_requires_capture_command"
	var inventory := inventories_by_side.get(command.actor_side) as Inventory
	if inventory == null:
		return &"missing_inventory"
	if not inventory.has(command.item_id):
		return &"insufficient_quantity"
	var party := get_party(command.actor_side)
	var target := party.get_member(command.target_instance_id) if party != null else null
	if target == null:
		return &"unknown_item_target"
	return _item_effect_service.validate(command.item_id, target)


func _validate_capture_command(command: CaptureCommand) -> StringName:
	if command.actor_side != BattleConstants.SIDE_PLAYER:
		return &"capture_player_only"
	if not is_wild_encounter:
		return &"capture_not_allowed"
	var inventory := inventories_by_side.get(command.actor_side) as Inventory
	if inventory == null:
		return &"missing_inventory"
	if not inventory.has(command.device_item_id):
		return &"insufficient_quantity"
	if _capture_collection == null:
		return &"missing_collection"
	var target := get_participant(BattleConstants.SIDE_OPPONENT)
	if target == null or target.is_defeated():
		return &"invalid_capture_target"
	if _capture_collection.contains_instance(target.creature.instance_id):
		return &"duplicate_instance_id"
	return &""


func _create_party(
	side: StringName,
	creatures: Array[CreatureInstance]
) -> BattleParty:
	var party := BattleParty.new()
	party.side = side
	var seen_instance_ids: Dictionary = {}
	for index in creatures.size():
		var creature := creatures[index]
		if creature == null:
			_reject(&"missing_creature")
			return null
		var species := _catalog.get_species(creature.species_id)
		if species == null:
			_reject(&"unknown_species")
			return null
		if creature.instance_id.is_empty():
			creature.instance_id = "%s_%d" % [side, index]
		if seen_instance_ids.has(creature.instance_id):
			_reject(&"duplicate_instance_id")
			return null
		seen_instance_ids[creature.instance_id] = true
		var participant := BattleParticipant.from_instance(
			side,
			species,
			creature,
			_catalog,
			_stat_calculator
		)
		status_effect_service.restore_persistent_statuses(participant)
		if not participant.is_defeated() and participant.move_slots_by_id.is_empty():
			_reject(&"creature_has_no_moves")
			return null
		party.members.append(participant)
	return party


func _emit_defeat(participant: BattleParticipant) -> void:
	_emit_event(BattleConstants.EVENT_CREATURE_DEFEATED, {
		"side": participant.side,
		"species_id": participant.species.species_id,
		"instance_id": participant.creature.instance_id,
	})


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
