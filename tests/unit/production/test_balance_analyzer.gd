extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("BalanceAnalyzer")


func run() -> void:
	_test_current_catalog_is_inside_targets()
	_test_missing_catalog_is_rejected()
	_test_outliers_are_reported_as_warnings()
	_test_elemental_move_coverage_is_required()
	_test_every_species_must_be_obtainable()


func _fresh_catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


func _test_current_catalog_is_inside_targets() -> void:
	begin_case("production balance targets")
	var report := BalanceAnalyzer.new().analyze(_fresh_catalog())
	assert_false(report.has_errors())
	assert_equal(report.error_count(), 0)
	assert_equal(report.warning_count(), 0)
	assert_equal(report.metrics["species_count"], 5)
	assert_equal((report.metrics["base_stat_totals"] as Dictionary)["cairnback"], 325)
	assert_equal((report.metrics["damaging_moves_by_type"] as Dictionary)["ember"], 1)
	assert_equal((report.metrics["encounter_appearances"] as Dictionary)["aurorook"], 2)
	var data := report.to_dictionary()
	assert_equal(data["schema_version"], 1)
	assert_equal(data["issues"], [])


func _test_missing_catalog_is_rejected() -> void:
	begin_case("missing balance catalog")
	var report := BalanceAnalyzer.new().analyze(null)
	assert_true(report.has_errors())
	assert_has_issue(report.issues, &"missing_balance_catalog")


func _test_outliers_are_reported_as_warnings() -> void:
	begin_case("tuning outliers")
	var test_catalog := _fresh_catalog()
	test_catalog.get_species(&"cindermite").base_stats.hp = 200
	test_catalog.get_move(&"cinder_jab").power = 120
	var zone := test_catalog.get_map(&"mosslight_crossing").encounter_zones[0]
	zone.entries[0].weight = 1000
	var report := BalanceAnalyzer.new().analyze(test_catalog)
	assert_false(report.has_errors())
	assert_equal(report.warning_count(), 3)
	assert_has_issue(report.issues, &"base_stat_total_outlier")
	assert_has_issue(report.issues, &"move_power_outlier")
	assert_has_issue(report.issues, &"dominant_encounter_entry")


func _test_elemental_move_coverage_is_required() -> void:
	begin_case("elemental move coverage")
	var test_catalog := _fresh_catalog()
	test_catalog.get_move(&"cinder_jab").category = "status"
	var report := BalanceAnalyzer.new().analyze(test_catalog)
	assert_true(report.has_errors())
	assert_has_issue(report.issues, &"type_without_damaging_move")
	assert_equal((report.metrics["damaging_moves_by_type"] as Dictionary)["ember"], 0)


func _test_every_species_must_be_obtainable() -> void:
	begin_case("species obtainability")
	var test_catalog := _fresh_catalog()
	for map in test_catalog.maps_by_id.values():
		for zone in (map as ExplorationMapDefinition).encounter_zones:
			for index in range(zone.entries.size() - 1, -1, -1):
				if zone.entries[index].species_id == &"aurorook":
					zone.entries.remove_at(index)
	var report := BalanceAnalyzer.new().analyze(test_catalog)
	assert_true(report.has_errors())
	assert_has_issue(report.issues, &"species_not_obtainable")
	assert_equal((report.metrics["encounter_appearances"] as Dictionary)["aurorook"], 0)
