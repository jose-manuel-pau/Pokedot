extends TestSuite

var router := ExplorationFeedbackRouter.new()


func _init() -> void:
	super("ExplorationFeedbackRouter")


func run() -> void:
	_test_semantic_event_cues()
	_test_movement_success_and_block_are_distinct()
	_test_unknown_and_muted_feedback_are_safe()


func _event(type: StringName, payload: Dictionary = {}) -> ExplorationEvent:
	return ExplorationEvent.create(type, 1, payload)


func _test_semantic_event_cues() -> void:
	begin_case("semantic feedback cues")
	assert_equal(router.route(_event(ExplorationConstants.EVENT_MAP_STARTED)).cue_id, &"map_ready")
	assert_equal(router.route(_event(ExplorationConstants.EVENT_NPC_INTERACTED)).cue_id, &"interaction")
	assert_equal(router.route(_event(ExplorationConstants.EVENT_TREASURE_CHEST_OPENED)).cue_id, &"treasure")
	var encounter := router.route(_event(ExplorationConstants.EVENT_WILD_ENCOUNTER))
	assert_equal(encounter.cue_id, &"encounter")
	assert_true(encounter.visual_duration > 0.0)
	assert_true(encounter.audio_duration > 0.0)
	assert_true(encounter.frequency_hz > 0.0)
	assert_equal(router.route(_event(ExplorationConstants.EVENT_EXPLORATION_RESUMED)).cue_id, &"resume")


func _test_movement_success_and_block_are_distinct() -> void:
	begin_case("movement feedback")
	var step := router.route(_event(ExplorationConstants.EVENT_MOVEMENT_RESOLVED, {"moved": true}))
	var blocked := router.route(_event(ExplorationConstants.EVENT_MOVEMENT_RESOLVED, {"moved": false}))
	assert_equal(step.cue_id, &"step")
	assert_equal(blocked.cue_id, &"blocked")
	assert_true(step.frequency_hz > blocked.frequency_hz)
	assert_true(step.color != blocked.color)


func _test_unknown_and_muted_feedback_are_safe() -> void:
	begin_case("optional feedback")
	assert_equal(router.route(null), null)
	assert_equal(router.route(_event(&"unknown")), null)
	var audio := ProceduralAudioFeedback.new()
	var preferences := PlayerPreferences.new()
	preferences.mute_audio = true
	assert_false(audio.play_cue(router.route(_event(ExplorationConstants.EVENT_MAP_STARTED)), preferences))
	audio.free()
