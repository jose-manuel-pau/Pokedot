class_name ProgressionResult
extends RefCounted
## Complete growth evidence for UI animation, telemetry, and tests.

var success: bool = false
var reason: StringName = &""
var instance_id: String
var experience_gained: int = 0
var total_experience_before: int = 0
var total_experience_after: int = 0
var old_level: int = 1
var new_level: int = 1
var hp_gained: int = 0
var stats_before: CreatureStats
var stats_after: CreatureStats
var learned_move_ids: Array[StringName] = []
var pending_move_ids: Array[StringName] = []


func levels_gained() -> int:
	return new_level - old_level
