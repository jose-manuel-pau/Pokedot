class_name TreasureChestService
extends RefCounted
## Selects one deterministic random reward and adds it through the shared
## inventory transaction boundary. Failed transactions do not open the chest.

var _catalog: ContentCatalog
var _random: ExplorationRandomSource
var _inventory_service: InventoryService


func _init(
	catalog: ContentCatalog,
	random_source: ExplorationRandomSource
) -> void:
	_catalog = catalog
	_random = random_source
	_inventory_service = InventoryService.new(catalog)


func open(
	chest: TreasureChestDefinition,
	inventory: Inventory,
	reserved_item_id: StringName = &""
) -> TreasureChestOpenResult:
	if chest == null:
		return TreasureChestOpenResult.rejected(&"", &"missing_treasure_chest")
	if inventory == null:
		return TreasureChestOpenResult.rejected(chest.chest_id, &"missing_inventory")
	if chest.reward_item_ids.is_empty():
		return TreasureChestOpenResult.rejected(chest.chest_id, &"empty_chest_reward_pool")
	if chest.reward_quantity < 1 or chest.reward_quantity > 99:
		return TreasureChestOpenResult.rejected(chest.chest_id, &"invalid_chest_reward_quantity")
	if not reserved_item_id.is_empty() \
		and not chest.reward_item_ids.has(reserved_item_id):
		return TreasureChestOpenResult.rejected(
			chest.chest_id,
			&"invalid_reserved_chest_reward",
			reserved_item_id
		)
	var reward_item_id := reserved_item_id
	if reward_item_id.is_empty():
		reward_item_id = chest.reward_item_ids[
			_random.next_int(chest.reward_item_ids.size())
		]
	if _catalog.get_item(reward_item_id) == null:
		return TreasureChestOpenResult.rejected(
			chest.chest_id,
			&"unknown_chest_reward",
			reward_item_id
		)
	var transaction := _inventory_service.add(
		inventory,
		reward_item_id,
		chest.reward_quantity
	)
	if not transaction.success:
		return TreasureChestOpenResult.rejected(
			chest.chest_id,
			transaction.reason,
			reward_item_id
		)
	return TreasureChestOpenResult.accepted(
		chest.chest_id,
		reward_item_id,
		chest.reward_quantity,
		transaction.quantity_after
	)
