class_name SwitchCreatureCommand
extends BattleCommand
## Requests an active-party change. Switching resolves before ordinary moves.

const SWITCH_PRIORITY := 6

var target_instance_id: String


func _init(side: StringName = &"", instance_id: String = "") -> void:
	super(side)
	target_instance_id = instance_id


func get_kind() -> StringName:
	return &"switch_creature"


func get_priority(_catalog: ContentCatalog) -> int:
	return SWITCH_PRIORITY


func validate(
	_participant: BattleParticipant,
	_catalog: ContentCatalog
) -> StringName:
	return &"missing_switch_target" if target_instance_id.is_empty() else &""

