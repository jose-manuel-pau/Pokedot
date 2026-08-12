class_name InventoryService
extends RefCounted
## Transaction boundary for item stacks and bag capacity.

var _catalog: ContentCatalog


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func add(
	inventory: Inventory,
	item_id: StringName,
	amount: int = 1
) -> InventoryTransactionResult:
	if inventory == null:
		return InventoryTransactionResult.rejected(item_id, &"missing_inventory", 0)
	var current := inventory.get_quantity(item_id)
	var item := _catalog.get_item(item_id)
	if item == null:
		return InventoryTransactionResult.rejected(item_id, &"unknown_item", current)
	if amount <= 0:
		return InventoryTransactionResult.rejected(item_id, &"invalid_amount", current)
	if current == 0 and inventory.get_used_slots() >= inventory.max_slots:
		return InventoryTransactionResult.rejected(item_id, &"inventory_full", current)
	if current + amount > item.max_stack:
		return InventoryTransactionResult.rejected(item_id, &"stack_limit_exceeded", current)
	inventory.quantities_by_item_id[item_id] = current + amount
	return InventoryTransactionResult.accepted(item_id, amount, current + amount)


func remove(
	inventory: Inventory,
	item_id: StringName,
	amount: int = 1
) -> InventoryTransactionResult:
	if inventory == null:
		return InventoryTransactionResult.rejected(item_id, &"missing_inventory", 0)
	var current := inventory.get_quantity(item_id)
	if _catalog.get_item(item_id) == null:
		return InventoryTransactionResult.rejected(item_id, &"unknown_item", current)
	if amount <= 0:
		return InventoryTransactionResult.rejected(item_id, &"invalid_amount", current)
	if current < amount:
		return InventoryTransactionResult.rejected(item_id, &"insufficient_quantity", current)
	var remaining := current - amount
	if remaining == 0:
		inventory.quantities_by_item_id.erase(item_id)
	else:
		inventory.quantities_by_item_id[item_id] = remaining
	return InventoryTransactionResult.accepted(item_id, -amount, remaining)
