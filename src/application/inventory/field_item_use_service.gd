class_name FieldItemUseService
extends RefCounted
## Atomic field-use boundary for restorative items. Presentation chooses an
## item and owned creature; this service validates, consumes, and applies it.

var _catalog: ContentCatalog
var _inventory_service: InventoryService
var _item_effect_service: ItemEffectService
var _stats := StatCalculator.new()


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog
	_inventory_service = InventoryService.new(catalog)
	_item_effect_service = ItemEffectService.new(
		catalog,
		StatusEffectService.new(catalog)
	)


func use_on_creature(
	inventory: Inventory,
	item_id: StringName,
	creature: CreatureInstance
) -> ItemUseResult:
	if inventory == null:
		return ItemUseResult.rejected(&"missing_inventory")
	var item := _catalog.get_item(item_id)
	if item == null:
		return ItemUseResult.rejected(&"unknown_item")
	if not item.is_healing_item() and not item.is_revival_item():
		return ItemUseResult.rejected(&"unsupported_field_item")
	if creature == null:
		return ItemUseResult.rejected(&"missing_item_target")
	var species := _catalog.get_species(creature.species_id)
	if species == null:
		return ItemUseResult.rejected(&"unknown_species")
	if not inventory.has(item_id):
		return ItemUseResult.rejected(&"insufficient_quantity")

	var target := BattleParticipant.from_instance(
		BattleConstants.SIDE_PLAYER,
		species,
		creature,
		_catalog,
		_stats
	)
	var validation_error := _item_effect_service.validate(item_id, target)
	if not str(validation_error).is_empty():
		return ItemUseResult.rejected(validation_error)

	var transaction := _inventory_service.remove(inventory, item_id)
	if not transaction.success:
		return ItemUseResult.rejected(transaction.reason)
	var effect := _item_effect_service.apply(item_id, target)
	if not effect.success:
		# Keep stock and HP atomic if a future effect adds a second validation step.
		_inventory_service.add(inventory, item_id)
	return effect
