extends TestSuite

var migrator := SaveGameMigrator.new()


func _init() -> void:
	super("SaveGameMigrator")


func run() -> void:
	_test_current_version_is_copied()
	_test_legacy_version_is_upgraded()
	_test_unknown_and_invalid_versions_are_rejected()


func _test_current_version_is_copied() -> void:
	begin_case("current version")
	var source := {"schema_version": 1, "profile": {"player_name": "Aster"}}
	var result := migrator.migrate(source)
	assert_true(result.success)
	assert_false(result.migrated)
	assert_equal(result.source_version, 1)
	result.data["profile"]["player_name"] = "Changed"
	assert_equal(source["profile"]["player_name"], "Aster")


func _test_legacy_version_is_upgraded() -> void:
	begin_case("version zero migration")
	var legacy := {
		"player_id": "legacy-player",
		"player_name": "Mira",
		"play_time_seconds": 12,
		"map_id": "mosslight_crossing",
		"player_position": [2, 8],
		"player_facing": [1, 0],
		"items": {"basic_capsule": 2},
		"party": [],
		"storage": [],
	}
	var result := migrator.migrate(legacy)
	assert_true(result.success)
	assert_true(result.migrated)
	assert_equal(result.source_version, 0)
	assert_equal(result.data["schema_version"], 1)
	assert_equal(result.data["profile"]["player_id"], "legacy-player")
	assert_equal(result.data["exploration"]["position"], [2, 8])
	assert_equal(result.data["inventory"]["max_slots"], Inventory.DEFAULT_MAX_SLOTS)
	assert_equal(result.data["inventory"]["quantities"]["basic_capsule"], 2)


func _test_unknown_and_invalid_versions_are_rejected() -> void:
	begin_case("unsupported versions")
	assert_equal(migrator.migrate({"schema_version": 99}).reason, &"unsupported_save_version")
	assert_equal(migrator.migrate([]).reason, &"invalid_save_root")
