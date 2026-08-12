class_name MovementLockStatusBehavior
extends StatusTagBehavior


func can_switch(
	_participant: BattleParticipant,
	_status: BattleStatusInstance
) -> bool:
	return false

