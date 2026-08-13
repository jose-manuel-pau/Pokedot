class_name ExplorationState
extends RefCounted
## Mutable session state kept separate from immutable map content.

var phase: StringName = ExplorationConstants.PHASE_NOT_STARTED
var map_id: StringName
var player_position: Vector2i
var facing: Vector2i = Vector2i.DOWN
var step_count: int = 0
var encounter_cooldown_steps: int = 0
var pending_encounter: WildEncounterRequest
var opened_chest_ids: Array[StringName] = []
var pending_chest_reward_by_id: Dictionary = {}


func is_chest_open(chest_id: StringName) -> bool:
	return opened_chest_ids.has(chest_id)


func get_pending_chest_reward(chest_id: StringName) -> StringName:
	return StringName(str(pending_chest_reward_by_id.get(chest_id, "")))
