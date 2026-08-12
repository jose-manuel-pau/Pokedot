extends SceneTree
## Usage: godot --headless --path . --script res://tests/test_runner.gd

const STAT_TEST := preload("res://tests/unit/test_stat_calculator.gd")
const EXPERIENCE_TEST := preload("res://tests/unit/test_experience_calculator.gd")
const REPOSITORY_TEST := preload("res://tests/unit/test_content_repository.gd")
const VALIDATOR_TEST := preload("res://tests/unit/test_content_validator.gd")
const EFFECTIVENESS_TEST := preload("res://tests/unit/test_type_effectiveness_service.gd")
const DAMAGE_TEST := preload("res://tests/unit/battle/test_damage_calculator.gd")
const TURN_ORDER_TEST := preload("res://tests/unit/battle/test_turn_order_resolver.gd")
const BATTLE_MANAGER_TEST := preload("res://tests/unit/battle/test_battle_manager.gd")
const STATUS_SERVICE_TEST := preload("res://tests/unit/battle/test_status_effect_service.gd")
const STATUS_INTEGRATION_TEST := preload("res://tests/unit/battle/test_status_battle_integration.gd")
const PARTY_SWITCHING_TEST := preload("res://tests/unit/battle/test_party_switching.gd")
const BATTLE_AI_TEST := preload("res://tests/unit/battle/test_battle_ai_controller.gd")
const INVENTORY_TEST := preload("res://tests/unit/inventory/test_inventory_service.gd")
const ITEM_EFFECT_TEST := preload("res://tests/unit/inventory/test_item_effect_service.gd")
const COLLECTION_TEST := preload("res://tests/unit/collection/test_creature_collection_service.gd")
const CAPTURE_TEST := preload("res://tests/unit/capture/test_capture_service.gd")
const CAPTURE_INVENTORY_INTEGRATION_TEST := preload("res://tests/unit/battle/test_capture_inventory_integration.gd")
const EXPLORATION_MAP_TEST := preload("res://tests/unit/exploration/test_exploration_map_definition.gd")
const WILD_ENCOUNTER_TEST := preload("res://tests/unit/exploration/test_wild_encounter_service.gd")
const EXPLORATION_SESSION_TEST := preload("res://tests/unit/exploration/test_exploration_session.gd")
const WILD_BATTLE_FACTORY_TEST := preload("res://tests/unit/exploration/test_wild_battle_factory.gd")
const PROGRESSION_TEST := preload("res://tests/unit/progression/test_progression_service.gd")
const XP_REWARD_TEST := preload("res://tests/unit/progression/test_experience_reward_calculator.gd")
const BATTLE_REWARD_TEST := preload("res://tests/unit/progression/test_battle_reward_service.gd")
const STATE_SERIALIZER_TEST := preload("res://tests/unit/persistence/test_game_state_serializer.gd")
const STATE_VALIDATOR_TEST := preload("res://tests/unit/persistence/test_game_state_validator.gd")
const SAVE_MIGRATOR_TEST := preload("res://tests/unit/persistence/test_save_game_migrator.gd")
const SAVE_REPOSITORY_TEST := preload("res://tests/unit/persistence/test_save_game_repository.gd")
const ROSTER_SERVICE_TEST := preload("res://tests/unit/collection/test_creature_roster_service.gd")
const CONTENT_PIPELINE_TEST := preload("res://tests/unit/content/test_content_pipeline_service.gd")
const PROMPT_MANIFEST_TEST := preload("res://tests/unit/content/test_prompt_manifest_repository.gd")


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var suites: Array[TestSuite] = [
		STAT_TEST.new(),
		EXPERIENCE_TEST.new(),
		REPOSITORY_TEST.new(),
		VALIDATOR_TEST.new(),
		EFFECTIVENESS_TEST.new(),
		DAMAGE_TEST.new(),
		TURN_ORDER_TEST.new(),
		BATTLE_MANAGER_TEST.new(),
		STATUS_SERVICE_TEST.new(),
		STATUS_INTEGRATION_TEST.new(),
		PARTY_SWITCHING_TEST.new(),
		BATTLE_AI_TEST.new(),
		INVENTORY_TEST.new(),
		ITEM_EFFECT_TEST.new(),
		COLLECTION_TEST.new(),
		CAPTURE_TEST.new(),
		CAPTURE_INVENTORY_INTEGRATION_TEST.new(),
		EXPLORATION_MAP_TEST.new(),
		WILD_ENCOUNTER_TEST.new(),
		EXPLORATION_SESSION_TEST.new(),
		WILD_BATTLE_FACTORY_TEST.new(),
		PROGRESSION_TEST.new(),
		XP_REWARD_TEST.new(),
		BATTLE_REWARD_TEST.new(),
		STATE_SERIALIZER_TEST.new(),
		STATE_VALIDATOR_TEST.new(),
		SAVE_MIGRATOR_TEST.new(),
		SAVE_REPOSITORY_TEST.new(),
		ROSTER_SERVICE_TEST.new(),
		CONTENT_PIPELINE_TEST.new(),
		PROMPT_MANIFEST_TEST.new(),
	]
	var total_cases := 0
	var total_assertions := 0
	var all_failures: Array[String] = []

	print("\nPokedot automated tests")
	for suite in suites:
		suite.run()
		total_cases += suite.case_count
		total_assertions += suite.assertion_count
		all_failures.append_array(suite.failures)
		var outcome := "PASS" if suite.failures.is_empty() else "FAIL"
		print("  [%s] %s — %d cases, %d assertions" % [
			outcome, suite.suite_name, suite.case_count, suite.assertion_count
		])

	if all_failures.is_empty():
		print("\nPASS — %d cases, %d assertions, 0 failures\n" % [total_cases, total_assertions])
		quit(0)
		return

	print("\nFailures:")
	for failure in all_failures:
		print("  - " + failure)
	print("\nFAIL — %d cases, %d assertions, %d failures\n" % [
		total_cases, total_assertions, all_failures.size()
	])
	quit(1)

