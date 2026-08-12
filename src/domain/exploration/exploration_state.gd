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
