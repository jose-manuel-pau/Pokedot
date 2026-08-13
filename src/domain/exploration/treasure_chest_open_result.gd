class_name TreasureChestOpenResult
extends RefCounted
## Result of one atomic reward roll and inventory transaction.

var success: bool = false
var reason: StringName = &""
var chest_id: StringName
var item_id: StringName
var quantity: int = 0
var quantity_after: int = 0


static func accepted(
	opened_chest_id: StringName,
	reward_item_id: StringName,
	reward_quantity: int,
	new_quantity: int
) -> TreasureChestOpenResult:
	var result := TreasureChestOpenResult.new()
	result.success = true
	result.chest_id = opened_chest_id
	result.item_id = reward_item_id
	result.quantity = reward_quantity
	result.quantity_after = new_quantity
	return result


static func rejected(
	opened_chest_id: StringName,
	error: StringName,
	reward_item_id: StringName = &""
) -> TreasureChestOpenResult:
	var result := TreasureChestOpenResult.new()
	result.chest_id = opened_chest_id
	result.item_id = reward_item_id
	result.reason = error
	return result
