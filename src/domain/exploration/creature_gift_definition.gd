class_name CreatureGiftDefinition
extends Resource
## One visible creature egg belonging to a mutually exclusive choice group.

@export var gift_id: StringName
@export var choice_group_id: StringName
@export var display_name: String
@export var grid_position: Vector2i
@export var species_id: StringName
@export_range(1, 200, 1) var level: int = 5
@export var prerequisite_npc_id: StringName
