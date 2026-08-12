class_name MovementResult
extends RefCounted

var moved: bool = false
var from_position: Vector2i
var to_position: Vector2i
var reason: StringName = &""
var encounter: WildEncounterRequest
