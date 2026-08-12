class_name TurnOrderEntry
extends RefCounted

var command: BattleCommand
var priority: int
var speed: int


static func create(
	battle_command: BattleCommand,
	action_priority: int,
	actor_speed: int
) -> TurnOrderEntry:
	var entry := TurnOrderEntry.new()
	entry.command = battle_command
	entry.priority = action_priority
	entry.speed = actor_speed
	return entry

