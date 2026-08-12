class_name ExplorationConstants
extends RefCounted

const PHASE_NOT_STARTED: StringName = &"not_started"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_BATTLE_TRANSITION: StringName = &"battle_transition"

const EVENT_MAP_STARTED: StringName = &"map_started"
const EVENT_MOVEMENT_RESOLVED: StringName = &"movement_resolved"
const EVENT_NPC_INTERACTED: StringName = &"npc_interacted"
const EVENT_WILD_ENCOUNTER: StringName = &"wild_encounter"
const EVENT_EXPLORATION_RESUMED: StringName = &"exploration_resumed"


static func is_cardinal(direction: Vector2i) -> bool:
	return direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
