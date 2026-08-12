extends TestSuite

var catalog: ContentCatalog
var service: TypeEffectivenessService


func _init() -> void:
	super("TypeEffectivenessService")
	catalog = JsonContentRepository.new().load_catalog("res://data").catalog
	service = TypeEffectivenessService.new(catalog)


func run() -> void:
	_test_single_type_matchups()
	_test_dual_type_multiplication()
	_test_neutral_and_unknown_behavior()


func _test_single_type_matchups() -> void:
	begin_case("single type matchups")
	assert_float_equal(service.get_multiplier(&"ember", [&"grove"]), 2.0)
	assert_float_equal(service.get_multiplier(&"ember", [&"tide"]), 0.5)


func _test_dual_type_multiplication() -> void:
	begin_case("dual type multiplication")
	assert_float_equal(service.get_multiplier(&"ember", [&"grove", &"gale"]), 2.0)
	assert_float_equal(service.get_multiplier(&"grove", [&"tide", &"stone"]), 4.0)
	assert_float_equal(service.get_multiplier(&"tide", [&"ember", &"grove"]), 1.0)


func _test_neutral_and_unknown_behavior() -> void:
	begin_case("neutral defaults")
	assert_float_equal(service.get_multiplier(&"gale", [&"tide"]), 1.0)
	assert_float_equal(service.get_multiplier(&"missing_type", [&"tide"]), 1.0)
	var no_defenders: Array[StringName] = []
	assert_float_equal(service.get_multiplier(&"ember", no_defenders), 1.0)

