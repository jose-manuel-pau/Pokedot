class_name PhysicalDamagePenaltyStatusBehavior
extends StatusTagBehavior

const DAMAGE_MULTIPLIER := 0.75


func modify_outgoing_damage(
	_participant: BattleParticipant,
	_status: BattleStatusInstance,
	move: MoveDefinition,
	current_damage: int
) -> int:
	if move.category != "physical":
		return current_damage
	return maxi(floori(current_damage * DAMAGE_MULTIPLIER), 1)

