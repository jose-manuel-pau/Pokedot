class_name LearnsetEntry
extends Resource
## Declares when a species becomes eligible to learn a move.

@export_range(1, 200, 1) var level: int = 1
@export var move_id: StringName


static func from_dictionary(data: Dictionary) -> LearnsetEntry:
	var entry := LearnsetEntry.new()
	entry.level = int(data.get("level", 1))
	entry.move_id = StringName(str(data.get("move_id", "")))
	return entry

