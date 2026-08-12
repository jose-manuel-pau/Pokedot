extends TestSuite

var catalog: ContentCatalog
var experience := ExperienceCalculator.new()
var service: ExperienceProgressService


func _init() -> void:
	super("ExperienceProgressService")
	catalog = BattleTestFactory.create_catalog()
	service = ExperienceProgressService.new(catalog)


func run() -> void:
	_test_projects_current_level_progress_without_mutation()
	_test_total_below_level_floor_is_normalized_for_display()
	_test_max_level_and_invalid_creatures_are_safe()


func _creature(species_id: StringName, level: int) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, level, [&"cinder_jab"])
	creature.instance_id = "progress-%s" % species_id
	return creature


func _test_projects_current_level_progress_without_mutation() -> void:
	begin_case("current-level progress projection")
	var creature := _creature(&"cindermite", 5)
	creature.total_experience = 134
	var progress := service.calculate(creature)
	assert_true(progress.success)
	assert_equal(progress.level, 5)
	assert_equal(progress.level_start_experience, 124)
	assert_equal(progress.next_level_experience, 215)
	assert_equal(progress.experience_into_level, 10)
	assert_equal(progress.experience_for_level, 91)
	assert_equal(progress.experience_remaining, 81)
	assert_float_equal(progress.ratio(), 10.0 / 91.0)
	assert_equal(creature.total_experience, 134, "Projection must not mutate saved XP.")


func _test_total_below_level_floor_is_normalized_for_display() -> void:
	begin_case("legacy XP normalization")
	var creature := _creature(&"cindermite", 5)
	creature.total_experience = 3
	var progress := service.calculate(creature)
	assert_true(progress.success)
	assert_equal(progress.total_experience, 124)
	assert_equal(progress.experience_into_level, 0)
	assert_equal(progress.experience_remaining, 91)
	assert_float_equal(progress.ratio(), 0.0)
	assert_equal(creature.total_experience, 3, "Display normalization must remain read-only.")


func _test_max_level_and_invalid_creatures_are_safe() -> void:
	begin_case("max-level and invalid projections")
	var creature := _creature(&"cindermite", 100)
	var curve := catalog.get_growth_curve(&"standard")
	creature.total_experience = experience.total_experience_for_level(curve, 100)
	var progress := service.calculate(creature)
	assert_true(progress.success)
	assert_true(progress.is_max_level)
	assert_equal(progress.experience_remaining, 0)
	assert_float_equal(progress.ratio(), 1.0)
	assert_equal(service.calculate(null).reason, &"missing_creature")
	var unknown := _creature(&"cindermite", 1)
	unknown.species_id = &"missing"
	assert_equal(service.calculate(unknown).reason, &"unknown_species")
