extends TestSuite

const CONTENT_PATH := "res://data"


func _init() -> void:
	super("JsonContentRepository")


func run() -> void:
	_test_valid_catalog_loads()
	_test_typed_species_data()
	_test_learnset_query()
	_test_cross_references_are_resolved()
	_test_typed_creature_concepts()


func _load() -> ContentLoadResult:
	return JsonContentRepository.new().load_catalog(CONTENT_PATH)


func _test_valid_catalog_loads() -> void:
	begin_case("valid catalog")
	var result := _load()
	assert_equal(result.error_count(), 0)
	assert_equal(result.warning_count(), 0)
	assert_equal(result.catalog.species_by_id.size(), 5)
	assert_equal(result.catalog.moves_by_id.size(), 11)
	assert_equal(result.catalog.types_by_id.size(), 5)
	assert_equal(result.catalog.statuses_by_id.size(), 3)
	assert_equal(result.catalog.growth_curves_by_id.size(), 3)
	assert_equal(result.catalog.items_by_id.size(), 12)
	assert_equal(result.catalog.maps_by_id.size(), 1)
	assert_equal(result.catalog.art_directions_by_id.size(), 1)
	assert_equal(result.catalog.creature_concepts_by_id.size(), 5)


func _test_typed_species_data() -> void:
	begin_case("typed species deserialization")
	var species := _load().catalog.get_species(&"cindermite")
	assert_not_null(species)
	assert_equal(species.display_name, "Cindermite")
	assert_equal(species.base_stats.attack, 64)
	assert_equal(species.element_types, [&"ember", &"stone"])
	assert_equal(species.growth_curve_id, &"standard")
	assert_equal(species.experience_yield, 62)


func _test_learnset_query() -> void:
	begin_case("learnset level query")
	var species := _load().catalog.get_species(&"cindermite")
	assert_equal(species.available_moves_at_level(1), [&"cinder_jab"])
	assert_equal(species.available_moves_at_level(5), [&"cinder_jab", &"stonepulse"])
	assert_equal(species.available_moves_at_level(100).size(), 3)


func _test_cross_references_are_resolved() -> void:
	begin_case("catalog references")
	var catalog := _load().catalog
	var species := catalog.get_species(&"reedling")
	assert_not_null(catalog.get_type(species.element_types[0]))
	assert_not_null(catalog.get_growth_curve(species.growth_curve_id))
	for learnset_entry in species.learnset:
		assert_not_null(catalog.get_move(learnset_entry.move_id))
	var remedy := catalog.get_item(&"clarity_herb")
	assert_not_null(remedy)
	assert_true(remedy.is_status_remedy())
	for status_id in remedy.cured_status_ids:
		assert_not_null(catalog.get_status(status_id))
	assert_equal(catalog.get_item(&"potion").healing_amount, 20)
	assert_equal(catalog.get_item(&"mega_potion").healing_amount, 50)
	assert_equal(catalog.get_item(&"ultra_potion").healing_amount, 100)
	var map := catalog.get_map(&"mosslight_crossing")
	assert_not_null(map)
	assert_equal(map.spawn_position, Vector2i(2, 8))
	assert_equal(map.encounter_zones.size(), 2)
	assert_equal(map.npcs.size(), 1)
	for zone in map.encounter_zones:
		for entry in zone.entries:
			assert_not_null(catalog.get_species(entry.species_id))
	for raw_concept in catalog.creature_concepts_by_id.values():
		var concept := raw_concept as CreatureConceptDefinition
		assert_not_null(catalog.get_species(concept.species_id))
		assert_not_null(catalog.get_art_direction(concept.art_direction_id))


func _test_typed_creature_concepts() -> void:
	begin_case("typed art concepts")
	var catalog := _load().catalog
	var concept := catalog.get_creature_concept(&"aurorook")
	assert_not_null(concept)
	assert_equal(concept.species_id, &"aurorook")
	assert_equal(concept.elemental_type_ids, [&"tide", &"gale"])
	assert_equal(concept.palette.accent, "#9DE09D")
	assert_equal(concept.signature_features.size(), 3)
	var direction := catalog.get_art_direction(&"field_sprite_v1")
	assert_not_null(direction)
	assert_equal(direction.canvas_size, Vector2i(96, 96))
	assert_equal(direction.prompt_version, 1)

