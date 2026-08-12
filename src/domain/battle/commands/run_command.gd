class_name RunCommand
extends BattleCommand
## Requests escape from a wild encounter. Running resolves before captures,
## items, and regular moves so a successful retreat cannot take counterdamage.

const RUN_PRIORITY := 6


func _init(side: StringName = &"") -> void:
	super(side)


func get_kind() -> StringName:
	return &"run"


func get_priority(_catalog: ContentCatalog) -> int:
	return RUN_PRIORITY


func validate(
	_participant: BattleParticipant,
	_catalog: ContentCatalog
) -> StringName:
	return &""
