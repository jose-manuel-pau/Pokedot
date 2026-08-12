class_name StatusEffectService
extends RefCounted
## Coordinates status lifecycle while delegating individual mechanics to tag
## behaviors. It is the only service that synchronizes persistent status IDs.

var _catalog: ContentCatalog
var _registry: StatusBehaviorRegistry


func _init(
	catalog: ContentCatalog,
	registry: StatusBehaviorRegistry = null
) -> void:
	_catalog = catalog
	_registry = registry if registry != null else StatusBehaviorRegistry.new()


func restore_persistent_statuses(participant: BattleParticipant) -> void:
	for status_id in participant.creature.persistent_status_ids:
		var definition := _catalog.get_status(status_id)
		if definition != null and definition.category == "persistent":
			participant.active_statuses_by_id[status_id] = BattleStatusInstance.create(
				status_id,
				definition.max_duration_turns,
				0
			)


func apply_status(
	participant: BattleParticipant,
	status_id: StringName,
	turn_number: int
) -> StringName:
	var definition := _catalog.get_status(status_id)
	if definition == null:
		return &"unknown_status"
	if participant.active_statuses_by_id.has(status_id):
		var existing := participant.active_statuses_by_id[status_id] as BattleStatusInstance
		if not definition.stackable:
			return &"already_applied"
		existing.stack_count = mini(existing.stack_count + 1, 99)
		existing.remaining_turns = definition.max_duration_turns
		existing.applied_turn = turn_number
		return &"stacked"
	participant.active_statuses_by_id[status_id] = BattleStatusInstance.create(
		status_id,
		definition.max_duration_turns,
		turn_number
	)
	if definition.category == "persistent" \
		and not participant.creature.persistent_status_ids.has(status_id):
		participant.creature.persistent_status_ids.append(status_id)
	return &"applied"


func remove_status(
	participant: BattleParticipant,
	status_id: StringName
) -> bool:
	if not participant.active_statuses_by_id.erase(status_id):
		return false
	participant.creature.persistent_status_ids.erase(status_id)
	return true


func clear_volatile_statuses(participant: BattleParticipant) -> Array[StringName]:
	var removed: Array[StringName] = []
	for raw_status in participant.active_statuses_by_id.values():
		var status := raw_status as BattleStatusInstance
		var definition := _catalog.get_status(status.status_id)
		if definition != null and definition.category == "volatile":
			removed.append(status.status_id)
	for status_id in removed:
		remove_status(participant, status_id)
	return removed


func can_act(participant: BattleParticipant) -> bool:
	for status in _statuses(participant):
		for behavior in _behaviors(status):
			if not behavior.can_act(participant, status):
				return false
	return true


func first_action_blocker(participant: BattleParticipant) -> StringName:
	for status in _statuses(participant):
		for behavior in _behaviors(status):
			if not behavior.can_act(participant, status):
				return status.status_id
	return &""


func can_switch(participant: BattleParticipant) -> bool:
	for status in _statuses(participant):
		for behavior in _behaviors(status):
			if not behavior.can_switch(participant, status):
				return false
	return true


func get_effective_speed(participant: BattleParticipant) -> int:
	var speed := participant.get_speed()
	for status in _statuses(participant):
		for behavior in _behaviors(status):
			speed = behavior.modify_speed(participant, status, speed)
	return speed


func modify_outgoing_damage(
	participant: BattleParticipant,
	move: MoveDefinition,
	damage: int
) -> int:
	var modified := damage
	for status in _statuses(participant):
		for behavior in _behaviors(status):
			modified = behavior.modify_outgoing_damage(
				participant,
				status,
				move,
				modified
			)
	return modified


func process_end_turn(
	participant: BattleParticipant,
	turn_number: int
) -> Array[StatusTickResult]:
	var results: Array[StatusTickResult] = []
	for status in _statuses(participant):
		var result := StatusTickResult.create(status.status_id)
		for behavior in _behaviors(status):
			result.damage += behavior.get_end_turn_damage(participant, status)
		if result.damage > 0 and not participant.is_defeated():
			result.damage = participant.apply_damage(result.damage)

		if status.has_finite_duration():
			status.remaining_turns -= 1
			if status.remaining_turns <= 0:
				result.removed = remove_status(participant, status.status_id)
		results.append(result)
	return results


func _statuses(participant: BattleParticipant) -> Array[BattleStatusInstance]:
	var statuses: Array[BattleStatusInstance] = []
	for raw_status in participant.active_statuses_by_id.values():
		statuses.append(raw_status as BattleStatusInstance)
	statuses.sort_custom(func(left: BattleStatusInstance, right: BattleStatusInstance) -> bool:
		return str(left.status_id) < str(right.status_id)
	)
	return statuses


func _behaviors(status: BattleStatusInstance) -> Array[StatusTagBehavior]:
	var definition := _catalog.get_status(status.status_id)
	if definition == null:
		return []
	var base_behaviors := _registry.get_behaviors(definition.tags)
	var stacked_behaviors: Array[StatusTagBehavior] = []
	for _stack in status.stack_count:
		stacked_behaviors.append_array(base_behaviors)
	return stacked_behaviors
