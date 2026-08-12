class_name SpeedReductionStatusBehavior
extends StatusTagBehavior

const SPEED_MULTIPLIER := 0.5


func modify_speed(
	_participant: BattleParticipant,
	_status: BattleStatusInstance,
	current_speed: int
) -> int:
	return maxi(floori(current_speed * SPEED_MULTIPLIER), 1)

