extends TestSuite


func _init() -> void:
	super("ContentValidator")


func run() -> void:
	_test_invalid_species_rules()
	_test_invalid_move_rules()
	_test_invalid_type_reference()
	_test_invalid_content_id()
	_test_invalid_item_rules()
	_test_invalid_map_rules()
	_test_invalid_art_direction_rules()
	_test_invalid_creature_concept_rules()


func _fresh_catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


func _test_invalid_species_rules() -> void:
	begin_case("species constraints")
	var catalog := _fresh_catalog()
	var species := catalog.get_species(&"cindermite")
	species.catch_rate = 0
	species.experience_yield = 0
	species.base_stats.hp = 0
	species.element_types.append(&"missing_type")
	var unknown_move := LearnsetEntry.new()
	unknown_move.level = 101
	unknown_move.move_id = &"missing_move"
	species.learnset.append(unknown_move)
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_catch_rate")
	assert_has_issue(issues, &"invalid_experience_yield")
	assert_has_issue(issues, &"invalid_base_stat")
	assert_has_issue(issues, &"invalid_species_type_count")
	assert_has_issue(issues, &"unknown_species_type")
	assert_has_issue(issues, &"invalid_learn_level")
	assert_has_issue(issues, &"unknown_learnset_move")


func _test_invalid_move_rules() -> void:
	begin_case("move constraints")
	var catalog := _fresh_catalog()
	var move := catalog.get_move(&"cinder_jab")
	move.element_type_id = &"missing_type"
	move.category = "status"
	move.accuracy = 0.0
	move.status_effect_id = &"missing_status"
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"unknown_move_type")
	assert_has_issue(issues, &"status_move_has_power")
	assert_has_issue(issues, &"invalid_accuracy")
	assert_has_issue(issues, &"unknown_status_reference")


func _test_invalid_type_reference() -> void:
	begin_case("type matrix constraints")
	var catalog := _fresh_catalog()
	var ember := catalog.get_type(&"ember")
	ember.effectiveness[&"missing_type"] = 9.0
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"unknown_type_reference")
	assert_has_issue(issues, &"invalid_effectiveness")


func _test_invalid_content_id() -> void:
	begin_case("stable content ID format")
	var catalog := _fresh_catalog()
	var type_definition := catalog.get_type(&"ember")
	catalog.types_by_id.erase(&"ember")
	type_definition.type_id = &"Ember-Type"
	catalog.types_by_id[type_definition.type_id] = type_definition
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_content_id")


func _test_invalid_item_rules() -> void:
	begin_case("item constraints")
	var catalog := _fresh_catalog()
	var device := catalog.get_item(&"basic_capsule")
	device.capture_multiplier = 0.0
	device.consumable = false
	device.battle_usable = false
	var healing := catalog.get_item(&"field_tonic")
	healing.healing_amount = 0
	healing.healing_fraction = 2.0
	var revival := catalog.get_item(&"elixir")
	revival.healing_fraction = 0.0
	revival.consumable = false
	revival.battle_usable = false
	var remedy := catalog.get_item(&"ember_salve")
	remedy.cured_status_ids = [&"missing_status"]
	var key_item := catalog.get_item(&"survey_compass")
	key_item.consumable = true
	key_item.max_stack = 2
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_device_multiplier")
	assert_has_issue(issues, &"reusable_capture_device")
	assert_has_issue(issues, &"unusable_capture_device")
	assert_has_issue(issues, &"invalid_healing_fraction")
	assert_has_issue(issues, &"revival_item_without_restoration")
	assert_has_issue(issues, &"reusable_revival_item")
	assert_has_issue(issues, &"unusable_revival_item")
	assert_has_issue(issues, &"unknown_item_status_reference")
	assert_has_issue(issues, &"consumable_key_item")
	assert_has_issue(issues, &"stackable_key_item")


func _test_invalid_map_rules() -> void:
	begin_case("exploration map constraints")
	var catalog := _fresh_catalog()
	var map := catalog.get_map(&"mosslight_crossing")
	map.spawn_position = Vector2i(0, 0)
	map.tile_rows[1] = "#?...............#"
	var zone := map.encounter_zones[0]
	zone.encounter_rate = 2.0
	zone.entries[0].species_id = &"missing_species"
	zone.entries[0].min_level = 9
	zone.entries[0].max_level = 4
	zone.entries[0].weight = 0
	var npc := map.npcs[0]
	npc.facing = Vector2i(1, 1)
	npc.dialogue.clear()
	var first_chest := map.treasure_chests[0]
	first_chest.grid_position = map.spawn_position
	first_chest.reward_item_ids.clear()
	first_chest.reward_quantity = 0
	var second_chest := map.treasure_chests[1]
	second_chest.chest_id = first_chest.chest_id
	second_chest.grid_position = map.spawn_position
	second_chest.reward_item_ids = [&"missing_item", &"missing_item"]
	map.treasure_chests[2].grid_position = Vector2i(0, 0)
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_map_spawn")
	assert_has_issue(issues, &"unknown_map_tile")
	assert_has_issue(issues, &"invalid_encounter_rate")
	assert_has_issue(issues, &"unknown_encounter_species")
	assert_has_issue(issues, &"invalid_encounter_level")
	assert_has_issue(issues, &"invalid_encounter_weight")
	assert_has_issue(issues, &"invalid_npc_facing")
	assert_has_issue(issues, &"npc_without_dialogue")
	assert_has_issue(issues, &"treasure_chest_on_spawn")
	assert_has_issue(issues, &"empty_chest_reward_pool")
	assert_has_issue(issues, &"invalid_chest_reward_quantity")
	assert_has_issue(issues, &"duplicate_treasure_chest_id")
	assert_has_issue(issues, &"overlapping_map_interactable")
	assert_has_issue(issues, &"unknown_chest_reward")
	assert_has_issue(issues, &"duplicate_chest_reward")
	assert_has_issue(issues, &"invalid_treasure_chest_position")


func _test_invalid_art_direction_rules() -> void:
	begin_case("art direction constraints")
	var catalog := _fresh_catalog()
	var direction := catalog.get_art_direction(&"field_sprite_v1")
	direction.prompt_version = 0
	direction.canvas_size = Vector2i(8, 2048)
	direction.rendering_style = ""
	direction.composition_rules.clear()
	direction.negative_terms.clear()
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"invalid_prompt_version")
	assert_has_issue(issues, &"invalid_sprite_canvas")
	assert_has_issue(issues, &"missing_art_brief_text")
	assert_has_issue(issues, &"missing_composition_rules")
	assert_has_issue(issues, &"missing_negative_terms")


func _test_invalid_creature_concept_rules() -> void:
	begin_case("creature concept constraints")
	var catalog := _fresh_catalog()
	var concept := catalog.get_creature_concept(&"cindermite")
	concept.species_id = &"missing_species"
	concept.art_direction_id = &"missing_direction"
	concept.elemental_type_ids = [&"tide"]
	concept.mythology_inspirations.clear()
	concept.wildlife_inspirations.clear()
	concept.signature_features = ["one feature"]
	concept.visual_exclusions.clear()
	concept.palette.primary = "not-a-color"
	concept.personality = "A Pokemon-like mascot"
	var issues := ContentValidator.new().validate(catalog)
	assert_has_issue(issues, &"concept_id_mismatch")
	assert_has_issue(issues, &"unknown_concept_species")
	assert_has_issue(issues, &"unknown_art_direction")
	assert_has_issue(issues, &"missing_mythology_inspiration")
	assert_has_issue(issues, &"missing_wildlife_inspiration")
	assert_has_issue(issues, &"insufficient_signature_features")
	assert_has_issue(issues, &"missing_visual_exclusions")
	assert_has_issue(issues, &"invalid_palette_color")
	assert_has_issue(issues, &"protected_ip_reference")
	assert_has_issue(issues, &"missing_species_concept")
