class_name DamageOverTimeStatusBehavior
extends StatusTagBehavior

const MAX_HP_FRACTION := 0.125


func get_end_turn_damage(
	participant: BattleParticipant,
	_status: BattleStatusInstance
) -> int:
	return maxi(floori(participant.get_max_hp() * MAX_HP_FRACTION), 1)

