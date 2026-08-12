class_name BattleProgressionResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var reward_pool: int = 0
var experience_by_instance_id: Dictionary = {}
var progression_by_instance_id: Dictionary = {}


func total_experience_applied() -> int:
	var total := 0
	for amount in experience_by_instance_id.values():
		total += int(amount)
	return total
