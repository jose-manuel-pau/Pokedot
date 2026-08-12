class_name BattleMoveSlot
extends RefCounted
## Per-battle move resource state. Move definitions remain immutable in the
## content catalog.

var move_id: StringName
var remaining_uses: int
var maximum_uses: int


static func from_definition(definition: MoveDefinition) -> BattleMoveSlot:
	var slot := BattleMoveSlot.new()
	slot.move_id = definition.move_id
	slot.maximum_uses = definition.max_uses
	slot.remaining_uses = definition.max_uses
	return slot


func can_use() -> bool:
	return remaining_uses > 0


func consume() -> bool:
	if not can_use():
		return false
	remaining_uses -= 1
	return true

