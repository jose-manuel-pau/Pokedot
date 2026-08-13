class_name ExplorationSession
extends RefCounted
## Headless exploration state machine. Rendering and input translate into these
## commands; map movement, collision, NPC interaction, and encounters live here.

signal event_emitted(event: ExplorationEvent)
signal phase_changed(previous_phase: StringName, current_phase: StringName)

var state := ExplorationState.new()
var event_history: Array[ExplorationEvent] = []
var last_error: StringName = &""

var _catalog: ContentCatalog
var _encounter_service: WildEncounterService
var _treasure_chest_service: TreasureChestService
var _encounter_sequence: int = 0


func _init(
	catalog: ContentCatalog,
	random_source: ExplorationRandomSource = null
) -> void:
	_catalog = catalog
	var source := random_source if random_source != null \
		else SeededExplorationRandomSource.new(0)
	_encounter_service = WildEncounterService.new(source)
	_treasure_chest_service = TreasureChestService.new(_catalog, source)


func start(map_id: StringName) -> bool:
	last_error = &""
	var map := _catalog.get_map(map_id)
	if map == null:
		return _reject(&"unknown_map")
	state = ExplorationState.new()
	state.map_id = map_id
	state.player_position = map.spawn_position
	_change_phase(ExplorationConstants.PHASE_ACTIVE)
	_emit_event(ExplorationConstants.EVENT_MAP_STARTED, {
		"map_id": map_id,
		"position": state.player_position,
	})
	return true


func attempt_move(direction: Vector2i) -> MovementResult:
	last_error = &""
	var result := MovementResult.new()
	result.from_position = state.player_position
	result.to_position = state.player_position
	if state.phase != ExplorationConstants.PHASE_ACTIVE:
		result.reason = &"exploration_not_active"
		last_error = result.reason
		return result
	if not ExplorationConstants.is_cardinal(direction):
		result.reason = &"invalid_direction"
		last_error = result.reason
		return result
	state.facing = direction
	var map := get_current_map()
	var target := state.player_position + direction
	if not map.is_walkable(target):
		result.reason = &"terrain_blocked"
		_emit_movement(result)
		return result
	if map.get_npc_at(target) != null:
		result.reason = &"npc_blocked"
		_emit_movement(result)
		return result
	if map.get_treasure_chest_at(target) != null:
		result.reason = &"treasure_chest_blocked"
		_emit_movement(result)
		return result

	state.player_position = target
	state.step_count += 1
	result.moved = true
	result.to_position = target
	if state.encounter_cooldown_steps > 0:
		state.encounter_cooldown_steps -= 1
	else:
		var zone := map.get_zone_for_cell(target)
		if zone != null:
			_encounter_sequence += 1
			result.encounter = _encounter_service.try_create(
				zone,
				state.map_id,
				target,
				_encounter_sequence
			)
			if result.encounter != null:
				state.pending_encounter = result.encounter
				state.encounter_cooldown_steps = zone.cooldown_steps
	_emit_movement(result)
	if result.encounter != null:
		_change_phase(ExplorationConstants.PHASE_BATTLE_TRANSITION)
		_emit_event(ExplorationConstants.EVENT_WILD_ENCOUNTER, {
			"encounter_id": result.encounter.encounter_id,
			"zone_id": result.encounter.zone_id,
			"species_id": result.encounter.species_id,
			"level": result.encounter.level,
			"position": result.encounter.grid_position,
		})
	return result


func interact(inventory: Inventory = null) -> InteractionResult:
	last_error = &""
	var result := InteractionResult.new()
	if state.phase != ExplorationConstants.PHASE_ACTIVE:
		result.reason = &"exploration_not_active"
		last_error = result.reason
		return result
	var interaction_position := state.player_position + state.facing
	var chest := get_current_map().get_treasure_chest_at(interaction_position)
	if chest != null:
		return _interact_with_treasure_chest(chest, inventory)
	var npc := get_current_map().get_npc_at(interaction_position)
	if npc == null:
		result.reason = &"nothing_to_interact"
		last_error = result.reason
		return result
	result.success = true
	result.interaction_type = ExplorationConstants.INTERACTION_NPC
	result.npc_id = npc.npc_id
	result.speaker_name = npc.display_name
	result.dialogue.assign(npc.dialogue)
	_emit_event(ExplorationConstants.EVENT_NPC_INTERACTED, {
		"npc_id": npc.npc_id,
		"position": npc.grid_position,
	})
	return result


func _interact_with_treasure_chest(
	chest: TreasureChestDefinition,
	inventory: Inventory
) -> InteractionResult:
	var result := InteractionResult.new()
	result.interaction_type = ExplorationConstants.INTERACTION_TREASURE_CHEST
	result.chest_id = chest.chest_id
	if state.is_chest_open(chest.chest_id):
		result.reason = &"treasure_chest_already_open"
		last_error = result.reason
		return result
	var opened := _treasure_chest_service.open(
		chest,
		inventory,
		state.get_pending_chest_reward(chest.chest_id)
	)
	result.item_id = opened.item_id
	if not opened.success:
		if not opened.item_id.is_empty():
			state.pending_chest_reward_by_id[chest.chest_id] = opened.item_id
		result.reason = opened.reason
		last_error = result.reason
		return result
	result.success = true
	result.quantity = opened.quantity
	result.quantity_after = opened.quantity_after
	state.pending_chest_reward_by_id.erase(chest.chest_id)
	state.opened_chest_ids.append(chest.chest_id)
	_emit_event(ExplorationConstants.EVENT_TREASURE_CHEST_OPENED, {
		"chest_id": chest.chest_id,
		"position": chest.grid_position,
		"item_id": opened.item_id,
		"quantity": opened.quantity,
		"quantity_after": opened.quantity_after,
	})
	return result


func resume_after_battle() -> bool:
	last_error = &""
	if state.phase != ExplorationConstants.PHASE_BATTLE_TRANSITION:
		return _reject(&"no_battle_transition")
	state.pending_encounter = null
	_change_phase(ExplorationConstants.PHASE_ACTIVE)
	_emit_event(ExplorationConstants.EVENT_EXPLORATION_RESUMED, {
		"position": state.player_position,
		"cooldown_steps": state.encounter_cooldown_steps,
	})
	return true


func get_current_map() -> ExplorationMapDefinition:
	return _catalog.get_map(state.map_id)


func events_of_type(event_type: StringName) -> Array[ExplorationEvent]:
	var matches: Array[ExplorationEvent] = []
	for event in event_history:
		if event.event_type == event_type:
			matches.append(event)
	return matches


func _emit_movement(result: MovementResult) -> void:
	_emit_event(ExplorationConstants.EVENT_MOVEMENT_RESOLVED, {
		"moved": result.moved,
		"from_position": result.from_position,
		"to_position": result.to_position,
		"reason": result.reason,
	})


func _change_phase(next_phase: StringName) -> void:
	var previous := state.phase
	state.phase = next_phase
	phase_changed.emit(previous, next_phase)


func _emit_event(event_type: StringName, payload: Dictionary = {}) -> void:
	var event := ExplorationEvent.create(event_type, state.step_count, payload)
	event_history.append(event)
	event_emitted.emit(event)


func _reject(reason: StringName) -> bool:
	last_error = reason
	return false
