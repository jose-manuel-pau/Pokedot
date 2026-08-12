class_name ExplorationEvent
extends RefCounted
## Serializable observer event emitted by ExplorationSession.

var event_type: StringName
var step_number: int = 0
var payload: Dictionary = {}


static func create(
	type: StringName,
	step: int,
	data: Dictionary = {}
) -> ExplorationEvent:
	var event := ExplorationEvent.new()
	event.event_type = type
	event.step_number = step
	event.payload = data.duplicate(true)
	return event
