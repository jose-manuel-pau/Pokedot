class_name NpcDefinition
extends Resource
## Immutable map placement and dialogue. Quest state can later reference npc_id.

@export var npc_id: StringName
@export var display_name: String
@export var grid_position: Vector2i
@export var facing: Vector2i = Vector2i.DOWN
@export var dialogue: Array[String] = []
