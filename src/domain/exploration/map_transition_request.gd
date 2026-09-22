class_name MapTransitionRequest
extends RefCounted
## Immutable hand-off data created when the player enters a map exit.

var exit_id: StringName
var source_map_id: StringName
var source_position: Vector2i
var destination_map_id: StringName
var destination_position: Vector2i
var destination_facing: Vector2i
var transition_style: StringName


static func create(
	exit_definition: MapExitDefinition,
	source_map: StringName,
	source_cell: Vector2i
) -> MapTransitionRequest:
	var request := MapTransitionRequest.new()
	request.exit_id = exit_definition.exit_id
	request.source_map_id = source_map
	request.source_position = source_cell
	request.destination_map_id = exit_definition.destination_map_id
	request.destination_position = exit_definition.destination_position
	request.destination_facing = exit_definition.destination_facing
	request.transition_style = exit_definition.transition_style
	return request

