class_name UseMoveCommand
extends BattleCommand
## Selects one learned move for the actor's next turn.

var move_id: StringName


func _init(side: StringName = &"", selected_move_id: StringName = &"") -> void:
	super(side)
	move_id = selected_move_id


func get_kind() -> StringName:
	return &"use_move"


func get_priority(catalog: ContentCatalog) -> int:
	var definition := catalog.get_move(move_id)
	return definition.priority if definition != null else 0


func validate(participant: BattleParticipant, catalog: ContentCatalog) -> StringName:
	if str(move_id).is_empty() or catalog.get_move(move_id) == null:
		return &"unknown_move"
	var slot := participant.get_move_slot(move_id)
	if slot == null:
		return &"move_not_learned"
	if not slot.can_use():
		return &"no_move_uses"
	return &""

