extends TestSuite

const TEST_DIRECTORY := "user://pokedot_content_pipeline_tests"
const OUTPUT_PATH := TEST_DIRECTORY + "/prompts.json"


func _init() -> void:
	super("PromptManifestRepository")


func run() -> void:
	_cleanup()
	_test_manifest_is_written_atomically()
	_test_existing_manifest_is_replaced()
	_test_invalid_inputs_are_rejected()
	_cleanup()


func _manifest() -> Dictionary:
	var catalog := JsonContentRepository.new().load_catalog("res://data").catalog
	return ContentPipelineService.new(catalog).compile().manifest


func _test_manifest_is_written_atomically() -> void:
	begin_case("atomic prompt export")
	var result := PromptManifestRepository.new().save(_manifest(), OUTPUT_PATH)
	assert_true(result.success)
	assert_equal(result.output_path, OUTPUT_PATH)
	assert_true(FileAccess.file_exists(OUTPUT_PATH))
	assert_false(FileAccess.file_exists(OUTPUT_PATH + ".tmp"))
	assert_false(FileAccess.file_exists(OUTPUT_PATH + ".bak"))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary)
	assert_equal(int(parsed["prompt_count"]), 5)
	assert_equal((parsed["prompts"] as Array).size(), 5)


func _test_existing_manifest_is_replaced() -> void:
	begin_case("deterministic overwrite")
	var manifest := _manifest()
	manifest["generator"] = "replacement"
	var result := PromptManifestRepository.new().save(manifest, OUTPUT_PATH)
	assert_true(result.success)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	assert_equal(parsed["generator"], "replacement")
	assert_false(FileAccess.file_exists(OUTPUT_PATH + ".bak"))


func _test_invalid_inputs_are_rejected() -> void:
	begin_case("invalid export inputs")
	var repository := PromptManifestRepository.new()
	assert_equal(repository.save(_manifest(), "").reason, &"invalid_output_path")
	assert_equal(repository.save(_manifest(), TEST_DIRECTORY + "/prompts.txt").reason, &"invalid_output_path")
	assert_equal(repository.save({}, OUTPUT_PATH).reason, &"invalid_prompt_manifest")
	assert_equal(repository.save({"schema_version": 99, "prompts": []}, OUTPUT_PATH).reason, &"invalid_prompt_manifest")


func _cleanup() -> void:
	for raw_suffix in ["", ".tmp", ".bak"]:
		var suffix: String = raw_suffix
		var path: String = OUTPUT_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var absolute_directory := ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.remove_absolute(absolute_directory)
