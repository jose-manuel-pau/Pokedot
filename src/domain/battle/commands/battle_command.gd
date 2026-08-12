class_name BattleCommand
extends RefCounted
## Command base class. Future capture, item, switch, and run commands can extend
## this contract without modifying the turn-order service.

var actor_side: StringName


func _init(side: StringName = &"") -> void:
	actor_side = side


func get_kind() -> StringName:
	return &"unsupported"


func get_priority(_catalog: ContentCatalog) -> int:
	return 0


func validate(
	_participant: BattleParticipant,
	_catalog: ContentCatalog
) -> StringName:
	return &"unsupported_command"

