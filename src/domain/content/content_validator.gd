class_name ContentValidator
extends RefCounted
## Validates domain rules and every cross-reference after JSON deserialization.


func validate(catalog: ContentCatalog) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	_validate_types(catalog, issues)
	_validate_statuses(catalog, issues)
	_validate_items(catalog, issues)
	_validate_growth_curves(catalog, issues)
	_validate_moves(catalog, issues)
	_validate_species(catalog, issues)
	_validate_maps(catalog, issues)
	return issues


func _validate_types(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.types_by_id.values():
		var definition := raw_definition as ElementTypeDefinition
		var path := "types.%s" % definition.type_id
		_validate_content_id(definition.type_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if not definition.color_hex.is_valid_html_color():
			_add_error(issues, &"invalid_color", path + ".color_hex", "Expected an HTML color.")
		for raw_defending_type_id in definition.effectiveness.keys():
			var defending_type_id := StringName(str(raw_defending_type_id))
			if not catalog.types_by_id.has(defending_type_id):
				_add_error(
					issues,
					&"unknown_type_reference",
					path + ".effectiveness.%s" % defending_type_id,
					"Defending type does not exist."
				)
			var multiplier := float(definition.effectiveness[raw_defending_type_id])
			if multiplier < 0.0 or multiplier > 4.0:
				_add_error(
					issues,
					&"invalid_effectiveness",
					path + ".effectiveness.%s" % defending_type_id,
					"Multiplier must be between 0.0 and 4.0."
				)


func _validate_statuses(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.statuses_by_id.values():
		var definition := raw_definition as StatusConditionDefinition
		var path := "statuses.%s" % definition.status_id
		_validate_content_id(definition.status_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if definition.category not in StatusConditionDefinition.VALID_CATEGORIES:
			_add_error(issues, &"invalid_status_category", path + ".category", "Unknown category.")
		if definition.capture_multiplier <= 0.0 or definition.capture_multiplier > 5.0:
			_add_error(
				issues,
				&"invalid_capture_multiplier",
				path + ".capture_multiplier",
				"Multiplier must be greater than 0 and at most 5."
			)
		if definition.max_duration_turns < 0:
			_add_error(issues, &"invalid_duration", path + ".max_duration_turns", "Cannot be negative.")


func _validate_growth_curves(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.growth_curves_by_id.values():
		var definition := raw_definition as GrowthCurveDefinition
		var path := "growth_curves.%s" % definition.curve_id
		_validate_content_id(definition.curve_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if definition.max_level < 2 or definition.max_level > 200:
			_add_error(issues, &"invalid_max_level", path + ".max_level", "Must be from 2 to 200.")
		if definition.scale <= 0.0:
			_add_error(issues, &"invalid_curve_scale", path + ".scale", "Must be greater than 0.")
		if definition.exponent <= 1.0 or definition.exponent > 6.0:
			_add_error(issues, &"invalid_curve_exponent", path + ".exponent", "Must be above 1 and at most 6.")


func _validate_items(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.items_by_id.values():
		var definition := raw_definition as ItemDefinition
		var path := "items.%s" % definition.item_id
		_validate_content_id(definition.item_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if definition.category not in ItemDefinition.VALID_CATEGORIES:
			_add_error(issues, &"invalid_item_category", path + ".category", "Unknown item category.")
		if definition.max_stack < 1 or definition.max_stack > 999:
			_add_error(issues, &"invalid_max_stack", path + ".max_stack", "Must be from 1 to 999.")
		if definition.purchase_price < 0:
			_add_error(issues, &"invalid_purchase_price", path + ".purchase_price", "Cannot be negative.")
		if definition.is_capture_device():
			if definition.capture_multiplier <= 0.0 or definition.capture_multiplier > 10.0:
				_add_error(
					issues,
					&"invalid_device_multiplier",
					path + ".capture_multiplier",
					"Capture multiplier must be above 0 and at most 10."
				)
			if not definition.consumable:
				_add_error(issues, &"reusable_capture_device", path + ".consumable", "Capture devices must be consumable.")
			if not definition.battle_usable:
				_add_error(issues, &"unusable_capture_device", path + ".battle_usable", "Capture devices must be battle usable.")
		elif not is_equal_approx(definition.capture_multiplier, 1.0):
			_add_error(
				issues,
				&"multiplier_on_non_device",
				path + ".capture_multiplier",
				"Only capture devices may modify capture chance."
			)
		if definition.healing_amount < 0:
			_add_error(issues, &"invalid_healing_amount", path + ".healing_amount", "Cannot be negative.")
		if definition.is_healing_item() \
			and definition.healing_amount <= 0 \
			and definition.healing_fraction <= 0.0:
			_add_error(
				issues,
				&"healing_item_without_healing",
				path,
				"Healing items need a flat or fractional heal."
			)
		if definition.healing_fraction < 0.0 or definition.healing_fraction > 1.0:
			_add_error(issues, &"invalid_healing_fraction", path + ".healing_fraction", "Must be from 0 to 1.")
		if definition.is_status_remedy() and definition.cured_status_ids.is_empty():
			_add_error(issues, &"remedy_without_statuses", path, "A remedy must cure at least one status.")
		for status_id in definition.cured_status_ids:
			if not catalog.statuses_by_id.has(status_id):
				_add_error(
					issues,
					&"unknown_item_status_reference",
					path + ".cured_status_ids",
					"Status '%s' does not exist." % status_id
				)
		if definition.category == ItemDefinition.CATEGORY_KEY_ITEM:
			if definition.consumable:
				_add_error(issues, &"consumable_key_item", path + ".consumable", "Key items cannot be consumable.")
			if definition.max_stack != 1:
				_add_error(issues, &"stackable_key_item", path + ".max_stack", "Key items must have max stack 1.")


func _validate_moves(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.moves_by_id.values():
		var definition := raw_definition as MoveDefinition
		var path := "moves.%s" % definition.move_id
		_validate_content_id(definition.move_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if not catalog.types_by_id.has(definition.element_type_id):
			_add_error(issues, &"unknown_move_type", path + ".type_id", "Element type does not exist.")
		if definition.category not in MoveDefinition.VALID_CATEGORIES:
			_add_error(issues, &"invalid_move_category", path + ".category", "Unknown category.")
		if definition.category == "status" and definition.power != 0:
			_add_error(issues, &"status_move_has_power", path + ".power", "Status moves must have zero power.")
		if definition.category != "status" and definition.power <= 0:
			_add_error(issues, &"damaging_move_without_power", path + ".power", "Damaging moves need positive power.")
		if definition.accuracy <= 0.0 or definition.accuracy > 100.0:
			_add_error(issues, &"invalid_accuracy", path + ".accuracy", "Must be above 0 and at most 100.")
		if definition.max_uses <= 0:
			_add_error(issues, &"invalid_max_uses", path + ".max_uses", "Must be positive.")
		if definition.status_chance < 0.0 or definition.status_chance > 100.0:
			_add_error(issues, &"invalid_status_chance", path + ".status_chance", "Must be from 0 to 100.")
		if not str(definition.status_effect_id).is_empty() and not catalog.statuses_by_id.has(definition.status_effect_id):
			_add_error(
				issues,
				&"unknown_status_reference",
				path + ".status_effect_id",
				"Status condition does not exist."
			)


func _validate_species(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.species_by_id.values():
		var definition := raw_definition as CreatureSpeciesDefinition
		var path := "species.%s" % definition.species_id
		_validate_content_id(definition.species_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if definition.element_types.is_empty() or definition.element_types.size() > 2:
			_add_error(issues, &"invalid_species_type_count", path + ".types", "A species needs one or two types.")
		var seen_types: Dictionary = {}
		for type_id in definition.element_types:
			if not catalog.types_by_id.has(type_id):
				_add_error(issues, &"unknown_species_type", path + ".types", "Type '%s' does not exist." % type_id)
			if seen_types.has(type_id):
				_add_error(issues, &"duplicate_species_type", path + ".types", "Type '%s' is repeated." % type_id)
			seen_types[type_id] = true
		if definition.catch_rate < 1 or definition.catch_rate > 255:
			_add_error(issues, &"invalid_catch_rate", path + ".catch_rate", "Must be from 1 to 255.")
		if definition.experience_yield < 1 or definition.experience_yield > 1000:
			_add_error(issues, &"invalid_experience_yield", path + ".experience_yield", "Must be from 1 to 1000.")
		if not catalog.growth_curves_by_id.has(definition.growth_curve_id):
			_add_error(issues, &"unknown_growth_curve", path + ".growth_curve_id", "Growth curve does not exist.")
		_validate_base_stats(definition.base_stats, path + ".base_stats", issues)
		_validate_learnset(definition, catalog, path + ".learnset", issues)


func _validate_maps(catalog: ContentCatalog, issues: Array[ValidationIssue]) -> void:
	for raw_definition in catalog.maps_by_id.values():
		var definition := raw_definition as ExplorationMapDefinition
		var path := "maps.%s" % definition.map_id
		_validate_content_id(definition.map_id, path + ".id", issues)
		_validate_display_name(definition.display_name, path, issues)
		if definition.tile_size < 8 or definition.tile_size > 128:
			_add_error(issues, &"invalid_tile_size", path + ".tile_size", "Must be from 8 to 128.")
		if definition.tile_rows.is_empty():
			_add_error(issues, &"empty_map", path + ".tile_rows", "At least one row is required.")
			continue
		var width := definition.get_width()
		if width < 3 or definition.get_height() < 3:
			_add_error(issues, &"map_too_small", path + ".tile_rows", "Map must be at least 3 by 3.")
		for row_index in definition.tile_rows.size():
			if definition.tile_rows[row_index].length() != width:
				_add_error(issues, &"uneven_map_rows", path + ".tile_rows[%d]" % row_index, "Every row needs equal width.")
		if not definition.is_walkable(definition.spawn_position):
			_add_error(issues, &"invalid_map_spawn", path + ".spawn", "Spawn must be on a walkable tile.")
		var zone_codes: Dictionary = {}
		var zone_ids: Dictionary = {}
		for zone in definition.encounter_zones:
			_validate_encounter_zone(zone, catalog, path, issues)
			if zone_ids.has(zone.zone_id):
				_add_error(issues, &"duplicate_zone_id", path + ".encounter_zones", "Zone ID is repeated.")
			if zone_codes.has(zone.tile_code):
				_add_error(issues, &"duplicate_zone_tile", path + ".encounter_zones", "Zone tile code is repeated.")
			zone_ids[zone.zone_id] = true
			zone_codes[zone.tile_code] = true
		var encountered_zone_codes: Dictionary = {}
		for row_index in definition.tile_rows.size():
			var row := definition.tile_rows[row_index]
			for column in row.length():
				var tile_code := row.substr(column, 1)
				if tile_code in [ExplorationMapDefinition.TILE_WALL, ExplorationMapDefinition.TILE_PATH]:
					continue
				if not zone_codes.has(tile_code):
					_add_error(issues, &"unknown_map_tile", path + ".tile_rows[%d]" % row_index, "Tile '%s' has no terrain rule." % tile_code)
				else:
					encountered_zone_codes[tile_code] = true
		for zone_code in zone_codes.keys():
			if not encountered_zone_codes.has(zone_code):
				_add_error(issues, &"unused_zone_tile", path + ".encounter_zones", "Zone tile '%s' is not used by the map." % zone_code)
		var npc_ids: Dictionary = {}
		var occupied: Dictionary = {}
		for npc in definition.npcs:
			_validate_content_id(npc.npc_id, path + ".npcs.id", issues)
			_validate_display_name(npc.display_name, path + ".npcs.%s" % npc.npc_id, issues)
			if npc_ids.has(npc.npc_id):
				_add_error(issues, &"duplicate_npc_id", path + ".npcs", "NPC ID is repeated.")
			if not definition.is_walkable(npc.grid_position):
				_add_error(issues, &"invalid_npc_position", path + ".npcs.%s.position" % npc.npc_id, "NPC must be on a walkable tile.")
			if npc.grid_position == definition.spawn_position:
				_add_error(issues, &"npc_on_spawn", path + ".npcs.%s.position" % npc.npc_id, "NPC cannot occupy the spawn.")
			if occupied.has(npc.grid_position):
				_add_error(issues, &"overlapping_npcs", path + ".npcs", "NPC positions must be unique.")
			if not _is_cardinal(npc.facing):
				_add_error(issues, &"invalid_npc_facing", path + ".npcs.%s.facing" % npc.npc_id, "Facing must be cardinal.")
			if npc.dialogue.is_empty():
				_add_error(issues, &"npc_without_dialogue", path + ".npcs.%s.dialogue" % npc.npc_id, "NPC needs dialogue.")
			npc_ids[npc.npc_id] = true
			occupied[npc.grid_position] = true


func _validate_encounter_zone(
	zone: EncounterZoneDefinition,
	catalog: ContentCatalog,
	map_path: String,
	issues: Array[ValidationIssue]
) -> void:
	var path := map_path + ".encounter_zones.%s" % zone.zone_id
	_validate_content_id(zone.zone_id, path + ".id", issues)
	_validate_display_name(zone.display_name, path, issues)
	if zone.tile_code.length() != 1 or zone.tile_code in [ExplorationMapDefinition.TILE_WALL, ExplorationMapDefinition.TILE_PATH]:
		_add_error(issues, &"invalid_zone_tile", path + ".tile_code", "Use one non-reserved tile character.")
	if zone.encounter_rate < 0.0 or zone.encounter_rate > 1.0:
		_add_error(issues, &"invalid_encounter_rate", path + ".encounter_rate", "Must be from 0 to 1.")
	if zone.cooldown_steps < 0:
		_add_error(issues, &"invalid_encounter_cooldown", path + ".cooldown_steps", "Cannot be negative.")
	if zone.entries.is_empty():
		_add_error(issues, &"empty_encounter_table", path + ".entries", "At least one encounter is required.")
	for entry in zone.entries:
		if catalog.get_species(entry.species_id) == null:
			_add_error(issues, &"unknown_encounter_species", path + ".entries", "Encounter species does not exist.")
		if entry.min_level < 1 or entry.max_level < entry.min_level or entry.max_level > 200:
			_add_error(issues, &"invalid_encounter_level", path + ".entries", "Level range is invalid.")
		if entry.weight <= 0:
			_add_error(issues, &"invalid_encounter_weight", path + ".entries", "Weight must be positive.")


func _is_cardinal(direction: Vector2i) -> bool:
	return direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _validate_base_stats(stats: CreatureStats, path: String, issues: Array[ValidationIssue]) -> void:
	for stat_id in CreatureStats.STAT_IDS:
		var value := stats.get_value(stat_id)
		if value < 1 or value > 255:
			_add_error(
				issues,
				&"invalid_base_stat",
				path + ".%s" % stat_id,
				"Base stat must be from 1 to 255."
			)


func _validate_learnset(
	definition: CreatureSpeciesDefinition,
	catalog: ContentCatalog,
	path: String,
	issues: Array[ValidationIssue]
) -> void:
	var max_level := 200
	var curve := catalog.get_growth_curve(definition.growth_curve_id)
	if curve != null:
		max_level = curve.max_level
	var seen_moves: Dictionary = {}
	var previous_level := 0
	for index in definition.learnset.size():
		var entry := definition.learnset[index]
		var entry_path := path + "[%d]" % index
		if entry.level < 1 or entry.level > max_level:
			_add_error(issues, &"invalid_learn_level", entry_path + ".level", "Outside the growth curve's level range.")
		if not catalog.moves_by_id.has(entry.move_id):
			_add_error(issues, &"unknown_learnset_move", entry_path + ".move_id", "Move does not exist.")
		if seen_moves.has(entry.move_id):
			_add_error(issues, &"duplicate_learnset_move", entry_path + ".move_id", "Move is already in this learnset.")
		seen_moves[entry.move_id] = true
		if entry.level < previous_level:
			issues.append(
				ValidationIssue.create(
					ValidationIssue.Severity.WARNING,
					&"unsorted_learnset",
					entry_path,
					"Entries should be ordered by level for maintainability."
				)
			)
		previous_level = entry.level


func _validate_display_name(name: String, path: String, issues: Array[ValidationIssue]) -> void:
	if name.strip_edges().is_empty():
		_add_error(issues, &"missing_display_name", path + ".display_name", "Display name is required.")


func _validate_content_id(content_id: StringName, path: String, issues: Array[ValidationIssue]) -> void:
	var value := str(content_id)
	if value.is_empty():
		_add_error(issues, &"invalid_content_id", path, "ID cannot be empty.")
		return
	for index in value.length():
		var character := value.substr(index, 1)
		var is_lowercase_letter := character >= "a" and character <= "z"
		var is_digit := character >= "0" and character <= "9"
		if (index == 0 and not is_lowercase_letter) or (
			index > 0 and not is_lowercase_letter and not is_digit and character != "_"
		):
			_add_error(
				issues,
				&"invalid_content_id",
				path,
				"Use lowercase snake_case beginning with a letter."
			)
			return


func _add_error(
	issues: Array[ValidationIssue],
	code: StringName,
	path: String,
	message: String
) -> void:
	issues.append(ValidationIssue.create(ValidationIssue.Severity.ERROR, code, path, message))
