class_name BattleEvent
extends RefCounted
## Presentation-agnostic record produced by battle resolution. UI, animation,
## audio, logging, and replays can observe the same event stream.

var event_type: StringName
var turn_number: int
var payload: Dictionary


static func create(
	type: StringName,
	turn: int,
	event_payload: Dictionary = {}
) -> BattleEvent:
	var event := BattleEvent.new()
	event.event_type = type
	event.turn_number = turn
	event.payload = event_payload.duplicate(true)
	return event

