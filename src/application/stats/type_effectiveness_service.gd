class_name TypeEffectivenessService
extends RefCounted
## Computes attack-type effectiveness. Dual types multiply, so two weaknesses
## produce 4x and a resistance combined with a weakness produces neutral damage.

var _catalog: ContentCatalog


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func get_multiplier(
	attacking_type_id: StringName,
	defending_type_ids: Array[StringName]
) -> float:
	var attacking_type := _catalog.get_type(attacking_type_id)
	if attacking_type == null:
		return 1.0

	var result := 1.0
	for defending_type_id in defending_type_ids:
		result *= attacking_type.multiplier_against(defending_type_id)
	return result

