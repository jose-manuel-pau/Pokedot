class_name JsonContentRepository
extends RefCounted
## Infrastructure adapter that converts versioned JSON documents into typed
## domain resources. All filesystem and JSON concerns stop at this boundary.

const SCHEMA_VERSION := 1


func load_catalog(base_path: String) -> ContentLoadResult:
	var result := ContentLoadResult.new()
	_load_types(_read_items(base_path.path_join("types.json"), result), result)
	_load_statuses(_read_items(base_path.path_join("statuses.json"), result), result)
	_load_items(_read_items(base_path.path_join("items.json"), result), result)
	_load_growth_curves(_read_items(base_path.path_join("growth_curves.json"), result), result)
	_load_moves(_read_items(base_path.path_join("moves.json"), result), result)
	_load_species(_read_items(base_path.path_join("species.json"), result), result)
	result.issues.append_array(ContentValidator.new().validate(result.catalog))
	return result


func _read_items(file_path: String, result: ContentLoadResult) -> Array:
	if not FileAccess.file_exists(file_path):
		_add_error(result, &"missing_content_file", file_path, "Required content file was not found.")
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_add_error(result, &"content_file_unreadable", file_path, "File could not be opened.")
		return []

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		_add_error(
			result,
			&"invalid_json",
			file_path,
			"Line %d: %s" % [json.get_error_line(), json.get_error_message()]
		)
		return []

	if not json.data is Dictionary:
		_add_error(result, &"invalid_document_root", file_path, "Root must be an object.")
		return []
	var document: Dictionary = json.data
	if int(document.get("schema_version", -1)) != SCHEMA_VERSION:
		_add_error(
			result,
			&"unsupported_schema_version",
			file_path + ".schema_version",
			"Expected version %d." % SCHEMA_VERSION
		)
	var items_value: Variant = document.get("items", [])
	if not items_value is Array:
		_add_error(result, &"invalid_items", file_path + ".items", "Expected an array.")
		return []
	return items_value as Array


func _load_types(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "types.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := ElementTypeDefinition.new()
		definition.type_id = _read_id(data, "id", "types.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.color_hex = str(data.get("color_hex", "#FFFFFF"))
		var raw_effectiveness: Variant = data.get("effectiveness", {})
		if raw_effectiveness is Dictionary:
			for raw_type_id in raw_effectiveness.keys():
				definition.effectiveness[StringName(str(raw_type_id))] = float(raw_effectiveness[raw_type_id])
		else:
			_add_error(result, &"invalid_field_type", "types.items[%d].effectiveness" % index, "Expected an object.")
		_add_type(definition, "types.items[%d].id" % index, result)


func _load_statuses(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "statuses.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := StatusConditionDefinition.new()
		definition.status_id = _read_id(data, "id", "statuses.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.category = str(data.get("category", "persistent"))
		definition.capture_multiplier = float(data.get("capture_multiplier", 1.0))
		definition.max_duration_turns = int(data.get("max_duration_turns", 0))
		definition.stackable = bool(data.get("stackable", false))
		definition.tags = _to_string_name_array(data.get("tags", []))
		_add_status(definition, "statuses.items[%d].id" % index, result)


func _load_growth_curves(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "growth_curves.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := GrowthCurveDefinition.new()
		definition.curve_id = _read_id(data, "id", "growth_curves.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.max_level = int(data.get("max_level", 100))
		definition.scale = float(data.get("scale", 1.0))
		definition.exponent = float(data.get("exponent", 3.0))
		_add_growth_curve(definition, "growth_curves.items[%d].id" % index, result)


func _load_items(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "items.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := ItemDefinition.new()
		definition.item_id = _read_id(data, "id", "items.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.description = str(data.get("description", ""))
		definition.category = str(data.get("category", ItemDefinition.CATEGORY_BATTLE_CONSUMABLE))
		definition.max_stack = int(data.get("max_stack", 99))
		definition.consumable = bool(data.get("consumable", true))
		definition.battle_usable = bool(data.get("battle_usable", true))
		definition.purchase_price = int(data.get("purchase_price", 0))
		definition.capture_multiplier = float(data.get("capture_multiplier", 1.0))
		definition.healing_amount = int(data.get("healing_amount", 0))
		definition.healing_fraction = float(data.get("healing_fraction", 0.0))
		definition.cured_status_ids = _to_string_name_array(data.get("cured_status_ids", []))
		_add_item(definition, "items.items[%d].id" % index, result)


func _load_moves(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "moves.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := MoveDefinition.new()
		definition.move_id = _read_id(data, "id", "moves.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.element_type_id = StringName(str(data.get("type_id", "")))
		definition.category = str(data.get("category", "physical"))
		definition.power = int(data.get("power", 0))
		definition.accuracy = float(data.get("accuracy", 100.0))
		definition.max_uses = int(data.get("max_uses", 10))
		definition.priority = int(data.get("priority", 0))
		definition.status_effect_id = StringName(str(data.get("status_effect_id", "")))
		definition.status_chance = float(data.get("status_chance", 0.0))
		_add_move(definition, "moves.items[%d].id" % index, result)


func _load_species(items: Array, result: ContentLoadResult) -> void:
	for index in items.size():
		var data := _as_dictionary(items[index], "species.items[%d]" % index, result)
		if data.is_empty():
			continue
		var definition := CreatureSpeciesDefinition.new()
		definition.species_id = _read_id(data, "id", "species.items[%d].id" % index, result)
		definition.display_name = str(data.get("display_name", ""))
		definition.description = str(data.get("description", ""))
		var raw_stats: Variant = data.get("base_stats", {})
		if raw_stats is Dictionary:
			definition.base_stats = CreatureStats.from_dictionary(raw_stats)
		else:
			_add_error(result, &"invalid_field_type", "species.items[%d].base_stats" % index, "Expected an object.")
		definition.element_types = _to_string_name_array(data.get("types", []))
		definition.catch_rate = int(data.get("catch_rate", 0))
		definition.growth_curve_id = StringName(str(data.get("growth_curve_id", "")))
		var raw_learnset: Variant = data.get("learnset", [])
		if raw_learnset is Array:
			for raw_entry in raw_learnset:
				if raw_entry is Dictionary:
					definition.learnset.append(LearnsetEntry.from_dictionary(raw_entry))
				else:
					_add_error(result, &"invalid_field_type", "species.items[%d].learnset" % index, "Entries must be objects.")
		else:
			_add_error(result, &"invalid_field_type", "species.items[%d].learnset" % index, "Expected an array.")
		_add_species(definition, "species.items[%d].id" % index, result)


func _as_dictionary(value: Variant, path: String, result: ContentLoadResult) -> Dictionary:
	if value is Dictionary:
		if value.is_empty():
			_add_error(result, &"empty_item", path, "Content item cannot be empty.")
		return value
	_add_error(result, &"invalid_item", path, "Expected an object.")
	return {}


func _read_id(data: Dictionary, key: String, path: String, result: ContentLoadResult) -> StringName:
	var content_id := StringName(str(data.get(key, "")).strip_edges())
	if str(content_id).is_empty():
		_add_error(result, &"missing_id", path, "A stable content ID is required.")
	return content_id


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var output: Array[StringName] = []
	if value is Array:
		for item in value:
			output.append(StringName(str(item)))
	return output


func _add_species(definition: CreatureSpeciesDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_species(definition) and not str(definition.species_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Species ID is already defined.")


func _add_move(definition: MoveDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_move(definition) and not str(definition.move_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Move ID is already defined.")


func _add_type(definition: ElementTypeDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_type(definition) and not str(definition.type_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Type ID is already defined.")


func _add_status(definition: StatusConditionDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_status(definition) and not str(definition.status_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Status ID is already defined.")


func _add_growth_curve(definition: GrowthCurveDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_growth_curve(definition) and not str(definition.curve_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Growth curve ID is already defined.")


func _add_item(definition: ItemDefinition, path: String, result: ContentLoadResult) -> void:
	if not result.catalog.add_item(definition) and not str(definition.item_id).is_empty():
		_add_error(result, &"duplicate_id", path, "Item ID is already defined.")


func _add_error(result: ContentLoadResult, code: StringName, path: String, message: String) -> void:
	result.add_issue(ValidationIssue.create(ValidationIssue.Severity.ERROR, code, path, message))
