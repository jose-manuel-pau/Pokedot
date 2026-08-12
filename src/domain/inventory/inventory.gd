class_name Inventory
extends RefCounted
## Save-friendly item quantities. All mutations are intentionally delegated to
## InventoryService so stack and slot invariants have one enforcement point.

const DEFAULT_MAX_SLOTS := 24

var max_slots: int = DEFAULT_MAX_SLOTS
var quantities_by_item_id: Dictionary = {}


func _init(slot_limit: int = DEFAULT_MAX_SLOTS) -> void:
	max_slots = maxi(slot_limit, 1)


func get_quantity(item_id: StringName) -> int:
	return int(quantities_by_item_id.get(item_id, 0))


func get_used_slots() -> int:
	return quantities_by_item_id.size()


func has(item_id: StringName, amount: int = 1) -> bool:
	return amount > 0 and get_quantity(item_id) >= amount
