extends TestSuite


func _init() -> void:
	super("ProductionReadinessService")


func run() -> void:
	_test_project_is_release_ready()
	_test_balance_failures_block_readiness()


func _catalog() -> ContentCatalog:
	return JsonContentRepository.new().load_catalog("res://data").catalog


func _test_project_is_release_ready() -> void:
	begin_case("release readiness")
	var report := ProductionReadinessService.new().inspect(_catalog())
	assert_false(report.has_errors())
	assert_equal(report.error_count(), 0)
	assert_equal(report.warning_count(), 0)
	assert_true(report.metrics["production_ready"])
	assert_equal(report.metrics["export_preset"], "Windows Desktop")
	assert_equal(report.metrics["export_platform"], "Windows Desktop")
	assert_true(str(report.metrics["export_path"]).ends_with(".exe"))
	assert_equal(report.metrics["sprite_prompt_count"], 5)
	assert_equal(report.metrics["preferences_schema_version"], 1)


func _test_balance_failures_block_readiness() -> void:
	begin_case("readiness failure propagation")
	var test_catalog := _catalog()
	test_catalog.get_move(&"cinder_jab").category = "status"
	var report := ProductionReadinessService.new().inspect(test_catalog)
	assert_true(report.has_errors())
	assert_has_issue(report.issues, &"type_without_damaging_move")
	assert_false(report.metrics["production_ready"])
