class_name InventoryTransactionResult
extends RefCounted
## Immutable-style result returned by inventory mutations.

var success: bool = false
var item_id: StringName
var amount_changed: int = 0
var quantity_after: int = 0
var reason: StringName = &""


static func accepted(
	changed_item_id: StringName,
	changed_amount: int,
	new_quantity: int
) -> InventoryTransactionResult:
	var result := InventoryTransactionResult.new()
	result.success = true
	result.item_id = changed_item_id
	result.amount_changed = changed_amount
	result.quantity_after = new_quantity
	return result

static func rejected(
	changed_item_id: StringName,
	error: StringName,
	current_quantity: int
) -> InventoryTransactionResult:
	var result := InventoryTransactionResult.new()
	result.item_id = changed_item_id
	result.reason = error
	result.quantity_after = current_quantity
	return result
