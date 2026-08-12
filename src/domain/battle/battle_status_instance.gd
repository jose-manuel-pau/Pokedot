class_name BattleStatusInstance
extends RefCounted
## Runtime state for one applied status. Definitions remain immutable content;
## duration and application turn belong to the individual battle participant.

var status_id: StringName
var remaining_turns: int = 0
var applied_turn: int = 0
var stack_count: int = 1


static func create(
	id: StringName,
	duration_turns: int,
	turn_number: int
) -> BattleStatusInstance:
	var instance := BattleStatusInstance.new()
	instance.status_id = id
	instance.remaining_turns = duration_turns
	instance.applied_turn = turn_number
	return instance


func has_finite_duration() -> bool:
	return remaining_turns > 0
