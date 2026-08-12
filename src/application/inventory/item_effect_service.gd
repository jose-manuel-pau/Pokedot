class_name ItemEffectService
extends RefCounted
## Applies battle-usable restorative effects. Inventory ownership remains a
## separate concern so failed effects never consume an item.

var _catalog: ContentCatalog
var _status_service: StatusEffectService


func _init(catalog: ContentCatalog, status_service: StatusEffectService) -> void:
	_catalog = catalog
	_status_service = status_service


func apply(item_id: StringName, target: BattleParticipant) -> ItemUseResult:
	var validation_error := validate(item_id, target)
	if not str(validation_error).is_empty():
		return ItemUseResult.rejected(validation_error)
	var item := _catalog.get_item(item_id)
	if item.is_healing_item():
		return _apply_healing(item, target)
	return _apply_remedy(item, target)


func validate(item_id: StringName, target: BattleParticipant) -> StringName:
	var item := _catalog.get_item(item_id)
	if item == null:
		return &"unknown_item"
	if target == null:
		return &"missing_item_target"
	if not item.battle_usable:
		return &"item_not_battle_usable"
	if item.is_healing_item():
		if target.is_defeated():
			return &"target_defeated"
		if target.current_hp >= target.get_max_hp():
			return &"target_at_full_hp"
		return &""
	if item.is_status_remedy():
		for status_id in item.cured_status_ids:
			if target.has_status(status_id):
				return &""
		return &"no_matching_status"
	return &"unsupported_item_effect"


func _apply_healing(
	item: ItemDefinition,
	target: BattleParticipant
) -> ItemUseResult:
	var requested := item.healing_amount
	if item.healing_fraction > 0.0:
		requested += ceili(target.get_max_hp() * item.healing_fraction)
	var result := ItemUseResult.accepted()
	result.healing_applied = target.restore_hp(requested)
	return result


func _apply_remedy(
	item: ItemDefinition,
	target: BattleParticipant
) -> ItemUseResult:
	var removable: Array[StringName] = []
	for status_id in item.cured_status_ids:
		if target.has_status(status_id):
			removable.append(status_id)
	var result := ItemUseResult.accepted()
	for status_id in removable:
		if _status_service.remove_status(target, status_id):
			result.removed_status_ids.append(status_id)
	return result
