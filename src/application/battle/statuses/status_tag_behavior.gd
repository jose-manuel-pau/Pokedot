class_name StatusTagBehavior
extends RefCounted
## One composable hook contributed by a status tag. New mechanics add behavior
## implementations and registry entries without changing BattleManager.


func can_act(
	_participant: BattleParticipant,
	_status: BattleStatusInstance
) -> bool:
	return true


func can_switch(
	_participant: BattleParticipant,
	_status: BattleStatusInstance
) -> bool:
	return true


func modify_speed(
	_participant: BattleParticipant,
	_status: BattleStatusInstance,
	current_speed: int
) -> int:
	return current_speed


func modify_outgoing_damage(
	_participant: BattleParticipant,
	_status: BattleStatusInstance,
	_move: MoveDefinition,
	current_damage: int
) -> int:
	return current_damage


func get_end_turn_damage(
	_participant: BattleParticipant,
	_status: BattleStatusInstance
) -> int:
	return 0

