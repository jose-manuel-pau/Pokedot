extends TestSuite


func _init() -> void:
	super("PlayerPreferencesService")


func run() -> void:
	_test_defaults_and_normalization()
	_test_accessibility_toggles_emit_changes()
	_test_text_scale_cycles()
	_test_volume_controls_are_bounded()


func _test_defaults_and_normalization() -> void:
	begin_case("preference defaults")
	var preferences := PlayerPreferences.from_dictionary({
		"text_scale": 4.0,
		"master_volume": -1.0,
		"effects_volume": 2.0,
	})
	assert_float_equal(preferences.text_scale, 1.5)
	assert_float_equal(preferences.master_volume, 0.0)
	assert_float_equal(preferences.effects_volume, 1.0)
	assert_false(preferences.high_contrast)
	assert_false(preferences.reduced_motion)
	assert_equal(preferences.to_dictionary()["schema_version"], 1)


func _test_accessibility_toggles_emit_changes() -> void:
	begin_case("preference observers")
	var service := PlayerPreferencesService.new()
	var counter := {"emissions": 0}
	service.preferences_changed.connect(func(_preferences: PlayerPreferences) -> void:
		counter["emissions"] = int(counter["emissions"]) + 1
	)
	service.toggle_high_contrast()
	service.toggle_reduced_motion()
	service.toggle_mute()
	assert_true(service.preferences.high_contrast)
	assert_true(service.preferences.reduced_motion)
	assert_true(service.preferences.mute_audio)
	assert_equal(counter["emissions"], 3)


func _test_text_scale_cycles() -> void:
	begin_case("text scale cycle")
	var service := PlayerPreferencesService.new()
	service.cycle_text_scale()
	assert_float_equal(service.preferences.text_scale, 1.25)
	service.cycle_text_scale()
	assert_float_equal(service.preferences.text_scale, 1.5)
	service.cycle_text_scale()
	assert_float_equal(service.preferences.text_scale, 1.0)


func _test_volume_controls_are_bounded() -> void:
	begin_case("volume bounds")
	var service := PlayerPreferencesService.new()
	service.set_volumes(5.0, -2.0)
	assert_float_equal(service.preferences.master_volume, 1.0)
	assert_float_equal(service.preferences.effects_volume, 0.0)
