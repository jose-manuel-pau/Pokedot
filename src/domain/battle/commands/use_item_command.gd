class_name UseItemCommand
extends BattleCommand
## Uses one restorative item on a member of the actor's battle party.

const ITEM_PRIORITY := 4

var item_id: StringName
var target_instance_id: String


func _init(
	side: StringName = &"",
	selected_item_id: StringName = &"",
	selected_target_instance_id: String = ""
) -> void:
	super(side)
	item_id = selected_item_id
	target_instance_id = selected_target_instance_id


func get_kind() -> StringName:
	return &"use_item"


func get_priority(_catalog: ContentCatalog) -> int:
	return ITEM_PRIORITY


func validate(
	_participant: BattleParticipant,
	catalog: ContentCatalog
) -> StringName:
	if str(item_id).is_empty() or catalog.get_item(item_id) == null:
		return &"unknown_item"
	if target_instance_id.is_empty():
		return &"missing_item_target"
	return &""
