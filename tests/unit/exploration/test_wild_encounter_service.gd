extends TestSuite

var catalog: ContentCatalog
var zone: EncounterZoneDefinition


func _init() -> void:
	super("WildEncounterService")
	catalog = BattleTestFactory.create_catalog()
	zone = catalog.get_map(&"mosslight_crossing").encounter_zones[0]


func run() -> void:
	_test_failed_trigger_stops_after_one_roll()
	_test_weighted_first_entry_and_min_level()
	_test_weighted_last_entry_and_max_level()
	_test_trigger_rate_boundary_is_exclusive()
	_test_invalid_table_does_not_roll()


func _test_failed_trigger_stops_after_one_roll() -> void:
	begin_case("failed trigger")
	var random := FixedExplorationRandomSource.new([0.18])
	var result := WildEncounterService.new(random).try_create(
		zone, &"mosslight_crossing", Vector2i(3, 2), 1
	)
	assert_equal(result, null)
	assert_equal(random.call_count, 1)


func _test_weighted_first_entry_and_min_level() -> void:
	begin_case("first weighted entry")
	var random := FixedExplorationRandomSource.new([0.0, 0.0, 0.0])
	var result := WildEncounterService.new(random).try_create(
		zone, &"mosslight_crossing", Vector2i(3, 2), 4
	)
	assert_not_null(result)
	assert_equal(result.encounter_id, "mosslight_crossing_sunmeadow_grass_4")
	assert_equal(result.species_id, &"cindermite")
	assert_equal(result.level, 3)
	assert_equal(result.grid_position, Vector2i(3, 2))
	assert_equal(random.call_count, 3)


func _test_weighted_last_entry_and_max_level() -> void:
	begin_case("last weighted entry")
	var random := FixedExplorationRandomSource.new([0.0, 0.99, 0.99])
	var result := WildEncounterService.new(random).try_create(
		zone, &"mosslight_crossing", Vector2i(6, 7), 2
	)
	assert_equal(result.species_id, &"gustlet")
	assert_equal(result.level, 6)
	assert_equal(result.zone_id, &"sunmeadow_grass")


func _test_trigger_rate_boundary_is_exclusive() -> void:
	begin_case("trigger boundary")
	var original_rate := zone.encounter_rate
	zone.encounter_rate = 1.0
	assert_not_null(WildEncounterService.new(
		FixedExplorationRandomSource.new([0.999999, 0.0, 0.0])
	).try_create(zone, &"mosslight_crossing", Vector2i.ZERO, 1))
	zone.encounter_rate = 0.0
	assert_equal(WildEncounterService.new(
		FixedExplorationRandomSource.new([0.0])
	).try_create(zone, &"mosslight_crossing", Vector2i.ZERO, 1), null)
	zone.encounter_rate = original_rate


func _test_invalid_table_does_not_roll() -> void:
	begin_case("invalid table")
	var random := FixedExplorationRandomSource.new()
	var empty_zone := EncounterZoneDefinition.new()
	assert_equal(WildEncounterService.new(random).try_create(
		empty_zone, &"map", Vector2i.ZERO, 1
	), null)
	assert_equal(random.call_count, 0)
