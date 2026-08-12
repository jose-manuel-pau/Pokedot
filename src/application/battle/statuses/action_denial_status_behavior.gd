class_name ActionDenialStatusBehavior
extends StatusTagBehavior


func can_act(
	_participant: BattleParticipant,
	_status: BattleStatusInstance
) -> bool:
	return false

