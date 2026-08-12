extends TestSuite

const TEST_DIRECTORY := "user://pokedot_preference_repository_tests"
const TEST_PATH := TEST_DIRECTORY + "/preferences.json"

var repository := PreferencesRepository.new(TEST_PATH)


func _init() -> void:
	super("PreferencesRepository")


func run() -> void:
	_cleanup()
	_test_missing_file_uses_defaults()
	_test_round_trip_and_overwrite()
	_test_invalid_data_uses_defaults()
	_test_missing_preferences_are_rejected()
	_cleanup()


func _test_missing_file_uses_defaults() -> void:
	begin_case("missing settings defaults")
	var result := repository.load()
	assert_true(result.success)
	assert_true(result.used_defaults)
	assert_equal(result.reason, &"settings_not_found")
	assert_float_equal(result.preferences.text_scale, 1.0)


func _test_round_trip_and_overwrite() -> void:
	begin_case("settings round trip")
	var preferences := PlayerPreferences.new()
	preferences.high_contrast = true
	preferences.text_scale = 1.25
	assert_true(repository.save(preferences).success)
	var loaded := repository.load()
	assert_true(loaded.success)
	assert_false(loaded.used_defaults)
	assert_true(loaded.preferences.high_contrast)
	assert_float_equal(loaded.preferences.text_scale, 1.25)
	preferences.mute_audio = true
	assert_true(repository.save(preferences).success)
	assert_true(repository.load().preferences.mute_audio)
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"))
	assert_false(FileAccess.file_exists(TEST_PATH + ".bak"))


func _test_invalid_data_uses_defaults() -> void:
	begin_case("invalid settings fallback")
	_write("{bad-json")
	var corrupt := repository.load()
	assert_true(corrupt.success)
	assert_true(corrupt.used_defaults)
	assert_equal(corrupt.reason, &"invalid_settings_json")
	_write(JSON.stringify({"schema_version": 99}))
	var future := repository.load()
	assert_true(future.used_defaults)
	assert_equal(future.reason, &"unsupported_settings_version")


func _test_missing_preferences_are_rejected() -> void:
	begin_case("missing settings save")
	var result := repository.save(null)
	assert_false(result.success)
	assert_equal(result.reason, &"missing_preferences")


func _write(contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _cleanup() -> void:
	for raw_suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PATH + str(raw_suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var directory := ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
