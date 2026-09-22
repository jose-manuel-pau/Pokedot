class_name MapExitDefinition
extends Resource
## Data-driven connection between two exploration maps. The destination is a
## safe arrival cell rather than the reciprocal exit cell, preventing loops.

const STYLE_OPEN_PATH: StringName = &"open_path"
const STYLE_DOOR: StringName = &"door"

@export var exit_id: StringName
@export var grid_position: Vector2i
@export var destination_map_id: StringName
@export var destination_position: Vector2i
@export var destination_facing: Vector2i = Vector2i.DOWN
@export var transition_style: StringName = STYLE_OPEN_PATH

