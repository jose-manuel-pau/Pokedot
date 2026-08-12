class_name ContentCatalog
extends RefCounted
## In-memory, read-only-by-convention registry of validated game definitions.

var species_by_id: Dictionary = {}
var moves_by_id: Dictionary = {}
var types_by_id: Dictionary = {}
var statuses_by_id: Dictionary = {}
var growth_curves_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var maps_by_id: Dictionary = {}


func add_species(definition: CreatureSpeciesDefinition) -> bool:
	return _add_unique(species_by_id, definition.species_id, definition)


func add_move(definition: MoveDefinition) -> bool:
	return _add_unique(moves_by_id, definition.move_id, definition)


func add_type(definition: ElementTypeDefinition) -> bool:
	return _add_unique(types_by_id, definition.type_id, definition)


func add_status(definition: StatusConditionDefinition) -> bool:
	return _add_unique(statuses_by_id, definition.status_id, definition)


func add_growth_curve(definition: GrowthCurveDefinition) -> bool:
	return _add_unique(growth_curves_by_id, definition.curve_id, definition)


func add_item(definition: ItemDefinition) -> bool:
	return _add_unique(items_by_id, definition.item_id, definition)


func add_map(definition: ExplorationMapDefinition) -> bool:
	return _add_unique(maps_by_id, definition.map_id, definition)


func get_species(species_id: StringName) -> CreatureSpeciesDefinition:
	return species_by_id.get(species_id) as CreatureSpeciesDefinition


func get_move(move_id: StringName) -> MoveDefinition:
	return moves_by_id.get(move_id) as MoveDefinition


func get_type(type_id: StringName) -> ElementTypeDefinition:
	return types_by_id.get(type_id) as ElementTypeDefinition


func get_status(status_id: StringName) -> StatusConditionDefinition:
	return statuses_by_id.get(status_id) as StatusConditionDefinition


func get_growth_curve(curve_id: StringName) -> GrowthCurveDefinition:
	return growth_curves_by_id.get(curve_id) as GrowthCurveDefinition


func get_item(item_id: StringName) -> ItemDefinition:
	return items_by_id.get(item_id) as ItemDefinition


func get_map(map_id: StringName) -> ExplorationMapDefinition:
	return maps_by_id.get(map_id) as ExplorationMapDefinition


func _add_unique(target: Dictionary, content_id: StringName, definition: Resource) -> bool:
	if content_id.is_empty() or target.has(content_id):
		return false
	target[content_id] = definition
	return true

