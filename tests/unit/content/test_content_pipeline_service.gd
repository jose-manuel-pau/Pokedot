extends TestSuite


func _init() -> void:
	super("ContentPipelineService")


func run() -> void:
	_test_valid_catalog_compiles_five_prompts()
	_test_compilation_is_deterministic()
	_test_invalid_catalog_stops_compilation()
	_test_missing_catalog_is_rejected()


func _catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


func _test_valid_catalog_compiles_five_prompts() -> void:
	begin_case("five prompt packages")
	var result := ContentPipelineService.new(_catalog()).compile()
	assert_false(result.has_errors())
	assert_equal(result.packages.size(), 5)
	assert_equal(result.manifest["schema_version"], 1)
	assert_equal(result.manifest["generator"], "pokedot_content_pipeline")
	assert_equal(result.manifest["prompt_count"], 5)
	var species_ids: Array[StringName] = []
	for package in result.packages:
		species_ids.append(package.species_id)
		assert_true(package.dalle_prompt.contains(package.display_name))
		assert_true(package.dalle_prompt.contains("96x96"))
		assert_true(package.midjourney_prompt.contains("--ar 1:1"))
		assert_true(package.midjourney_prompt.contains("--no"))
		assert_false(package.negative_prompt.is_empty())
	assert_equal(species_ids, [&"aurorook", &"cairnback", &"cindermite", &"gustlet", &"reedling"])
	var aurorook := result.packages[0]
	assert_true(aurorook.dalle_prompt.contains("#9DE09D"))
	assert_true(aurorook.dalle_prompt.contains("arctic tern"))


func _test_compilation_is_deterministic() -> void:
	begin_case("deterministic manifest")
	var first := ContentPipelineService.new(_catalog()).compile()
	var second := ContentPipelineService.new(_catalog()).compile()
	assert_equal(JSON.stringify(first.manifest), JSON.stringify(second.manifest))
	assert_equal(first.packages[2].dalle_prompt, second.packages[2].dalle_prompt)
	assert_equal(first.packages[2].midjourney_prompt, second.packages[2].midjourney_prompt)


func _test_invalid_catalog_stops_compilation() -> void:
	begin_case("invalid source blocks artifacts")
	var catalog := _catalog()
	catalog.get_creature_concept(&"gustlet").art_direction_id = &"missing"
	var result := ContentPipelineService.new(catalog).compile()
	assert_true(result.has_errors())
	assert_has_issue(result.issues, &"unknown_art_direction")
	assert_equal(result.packages.size(), 0)
	assert_true(result.manifest.is_empty())


func _test_missing_catalog_is_rejected() -> void:
	begin_case("missing catalog")
	var result := ContentPipelineService.new(null).compile()
	assert_true(result.has_errors())
	assert_has_issue(result.issues, &"missing_content_catalog")
	assert_equal(result.packages.size(), 0)
