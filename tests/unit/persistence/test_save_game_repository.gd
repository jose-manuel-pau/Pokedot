extends TestSuite

const TEST_BASE := "user://pokedot_progression_repository_tests"

var catalog: ContentCatalog
var repository: SaveGameRepository


func _init() -> void:
	super("SaveGameRepository")
	catalog = BattleTestFactory.create_catalog()
	repository = SaveGameRepository.new(catalog, TEST_BASE)


func run() -> void:
	_reset_directory()
	_test_save_load_and_overwrite()
	_test_slot_listing_is_sorted()
	_test_invalid_state_and_slot_are_not_written()
	_test_missing_corrupt_and_future_saves_are_rejected()
	_test_backup_recovery()
	_reset_directory()


func _test_save_load_and_overwrite() -> void:
	begin_case("save load overwrite")
	var state := GameStateTestFactory.create_valid_state(catalog)
	var saved := repository.save(&"slot_a", state)
	assert_true(saved.success)
	assert_true(FileAccess.file_exists(saved.file_path))
	var loaded := repository.load(&"slot_a")
	assert_true(loaded.success)
	assert_equal(loaded.source_version, SaveGameMigrator.CURRENT_VERSION)
	assert_false(loaded.migrated)
	assert_equal(loaded.state.player_name, "Aster")
	assert_equal(loaded.state.collection.party[0].nickname, "Coal")

	state.player_name = "Nova"
	state.play_time_seconds = 900
	assert_true(repository.save(&"slot_a", state).success)
	loaded = repository.load(&"slot_a")
	assert_equal(loaded.state.player_name, "Nova")
	assert_equal(loaded.state.play_time_seconds, 900)
	assert_false(FileAccess.file_exists(TEST_BASE.path_join("slot_a.json.bak")))
	assert_false(FileAccess.file_exists(TEST_BASE.path_join("slot_a.json.tmp")))


func _test_slot_listing_is_sorted() -> void:
	begin_case("slot listing")
	assert_true(repository.save(
		&"slot_c", GameStateTestFactory.create_valid_state(catalog)
	).success)
	assert_true(repository.save(
		&"slot_b", GameStateTestFactory.create_valid_state(catalog)
	).success)
	assert_equal(repository.list_slot_ids(), [&"slot_a", &"slot_b", &"slot_c"])


func _test_invalid_state_and_slot_are_not_written() -> void:
	begin_case("save rejection")
	var state := GameStateTestFactory.create_valid_state(catalog)
	assert_equal(repository.save(StringName("../escape"), state).reason, &"invalid_save_slot_id")
	state.collection.party.clear()
	var result := repository.save(&"invalid_state", state)
	assert_false(result.success)
	assert_equal(result.reason, &"invalid_game_state")
	assert_true(result.validation_issues.has(&"empty_save_party"))
	assert_false(FileAccess.file_exists(TEST_BASE.path_join("invalid_state.json")))


func _test_missing_corrupt_and_future_saves_are_rejected() -> void:
	begin_case("load rejection")
	assert_equal(repository.load(&"missing").reason, &"save_slot_not_found")
	_write_raw("corrupt.json", "{not-json")
	assert_equal(repository.load(&"corrupt").reason, &"invalid_save_json")
	_write_raw("future.json", JSON.stringify({"schema_version": 99}))
	assert_equal(repository.load(&"future").reason, &"unsupported_save_version")


func _test_backup_recovery() -> void:
	begin_case("backup recovery")
	var state := GameStateTestFactory.create_valid_state(catalog)
	assert_true(repository.save(&"recover", state).success)
	var final := ProjectSettings.globalize_path(
		TEST_BASE.path_join("recover.json")
	)
	var backup := ProjectSettings.globalize_path(
		TEST_BASE.path_join("recover.json.bak")
	)
	assert_equal(DirAccess.rename_absolute(final, backup), OK)
	var loaded := repository.load(&"recover")
	assert_true(loaded.success)
	assert_true(loaded.recovered_from_backup)
	assert_equal(loaded.state.player_id, "player-001")


func _write_raw(file_name: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_BASE))
	var file := FileAccess.open(TEST_BASE.path_join(file_name), FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _reset_directory() -> void:
	var directory := DirAccess.open(TEST_BASE)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			TEST_BASE.path_join(file_name)
		))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BASE))
