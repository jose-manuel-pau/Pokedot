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
var pending_map_transition: MapTransitionRequest
var opened_chest_ids: Array[StringName] = []
var pending_chest_reward_by_id: Dictionary = {}
var talked_npc_ids: Array[StringName] = []
var claimed_creature_gift_by_group: Dictionary = {}


func is_chest_open(chest_id: StringName) -> bool:
	return opened_chest_ids.has(chest_id)


func get_pending_chest_reward(chest_id: StringName) -> StringName:
	return StringName(str(pending_chest_reward_by_id.get(chest_id, "")))


func has_talked_to_npc(npc_id: StringName) -> bool:
	return talked_npc_ids.has(npc_id)


func get_claimed_creature_gift(choice_group_id: StringName) -> StringName:
	return StringName(str(claimed_creature_gift_by_group.get(choice_group_id, "")))
