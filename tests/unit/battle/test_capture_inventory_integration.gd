extends TestSuite

var catalog: ContentCatalog


func _init() -> void:
	super("CaptureInventoryIntegration")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_trainer_capture_is_rejected_without_consumption()
	_test_failed_wild_capture_consumes_device_and_turn_continues()
	_test_successful_capture_ends_battle_before_counterattack()
	_test_capture_routes_to_storage_when_party_is_full()
	_test_healing_item_resolves_before_move_and_consumes_stock()
	_test_remedy_cures_persistent_status_in_battle()
	_test_invalid_item_commands_preserve_stock()
	_test_item_resolution_revalidates_stock_atomically()


func _creature(
	species_id: StringName,
	moves: Array[StringName],
	hp: int = 99999,
	suffix: String = ""
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, 20, moves, hp)
	if not suffix.is_empty():
		creature.instance_id += "-" + suffix
	return creature


func _typed_party(creatures: Array[CreatureInstance]) -> Array[CreatureInstance]:
	return creatures


func _inventory(item_id: StringName, amount: int = 1) -> Inventory:
	var inventory := Inventory.new()
	InventoryService.new(catalog).add(inventory, item_id, amount)
	return inventory


func _test_trainer_capture_is_rejected_without_consumption() -> void:
	begin_case("trainer capture rejection")
	var inventory := _inventory(&"basic_capsule")
	var manager := BattleManager.new(catalog)
	manager.start_battle(
		_creature(&"cindermite", [&"cinder_jab"]),
		_creature(&"gustlet", [&"updraft"])
	)
	manager.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)
	assert_false(manager.submit_command(CaptureCommand.new(&"player", &"basic_capsule")))
	assert_equal(manager.last_error, &"capture_not_allowed")
	assert_equal(inventory.get_quantity(&"basic_capsule"), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CAPTURE_ATTEMPTED).size(), 0)


func _test_failed_wild_capture_consumes_device_and_turn_continues() -> void:
	begin_case("failed wild capture")
	var player := _creature(&"cindermite", [&"cinder_jab"])
	var wild := _creature(&"gustlet", [&"updraft"], 99999, "wild-fail")
	var inventory := _inventory(&"basic_capsule")
	var collection := CreatureCollection.new()
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.99, 0.99, 0.0, 0.5, 1.0])
	)
	assert_true(manager.start_wild_battle(
		_typed_party([player]), wild, inventory, collection
	))
	var player_hp := manager.get_participant(&"player").current_hp
	assert_true(manager.submit_command(CaptureCommand.new(&"player", &"basic_capsule")))
	assert_true(manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft")))
	assert_true(manager.resolve_turn())
	assert_equal(inventory.get_quantity(&"basic_capsule"), 0)
	assert_true(manager.get_participant(&"player").current_hp < player_hp)
	assert_equal(manager.phase, BattleConstants.PHASE_AWAITING_COMMANDS)
	assert_equal(manager.turn_number, 2)
	assert_equal(collection.party.size(), 0)
	var attempts := manager.events_of_type(BattleConstants.EVENT_CAPTURE_ATTEMPTED)
	assert_equal(attempts.size(), 1)
	assert_false(attempts[0].payload["success"])


func _test_successful_capture_ends_battle_before_counterattack() -> void:
	begin_case("successful wild capture")
	var player := _creature(&"cindermite", [&"cinder_jab"])
	var wild := _creature(&"gustlet", [&"updraft"], 99999, "wild-success")
	var inventory := _inventory(&"reinforced_capsule")
	var collection := CreatureCollection.new()
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.0])
	)
	manager.start_wild_battle(_typed_party([player]), wild, inventory, collection)
	var player_hp := manager.get_participant(&"player").current_hp
	manager.submit_command(CaptureCommand.new(&"player", &"reinforced_capsule"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	assert_true(manager.resolve_turn())
	assert_equal(manager.phase, BattleConstants.PHASE_FINISHED)
	assert_equal(manager.outcome, BattleConstants.OUTCOME_OPPONENT_CAPTURED)
	assert_equal(manager.get_participant(&"player").current_hp, player_hp)
	assert_equal(inventory.get_quantity(&"reinforced_capsule"), 0)
	assert_equal(collection.party, [wild])
	assert_equal(collection.storage.size(), 0)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_CREATURE_CAPTURED).size(), 1)
	assert_equal(manager.events_of_type(BattleConstants.EVENT_MOVE_USED).size(), 0)
	assert_equal(manager.event_history[-1].event_type, BattleConstants.EVENT_BATTLE_FINISHED)


func _test_capture_routes_to_storage_when_party_is_full() -> void:
	begin_case("capture storage routing")
	var collection := CreatureCollection.new()
	for index in CreatureCollection.MAX_PARTY_SIZE:
		collection.party.append(_creature(
			&"cindermite", [&"cinder_jab"], 99999, "owned-%d" % index
		))
	var wild := _creature(&"reedling", [&"brook_bash"], 1, "wild-storage")
	var inventory := _inventory(&"basic_capsule")
	var manager := BattleManager.new(catalog, FixedBattleRandomSource.new([0.0, 0.5]))
	manager.start_wild_battle(
		_typed_party([_creature(&"gustlet", [&"updraft"])]),
		wild,
		inventory,
		collection
	)
	manager.submit_command(CaptureCommand.new(&"player", &"basic_capsule"))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
	manager.resolve_turn()
	assert_equal(collection.party.size(), CreatureCollection.MAX_PARTY_SIZE)
	assert_equal(collection.storage, [wild])
	var capture_event := manager.events_of_type(BattleConstants.EVENT_CREATURE_CAPTURED)[0]
	assert_equal(capture_event.payload["destination"], CollectionAddResult.DESTINATION_STORAGE)


func _test_healing_item_resolves_before_move_and_consumes_stock() -> void:
	begin_case("healing item battle command")
	var player := _creature(&"cindermite", [&"cinder_jab"], 1)
	var inventory := _inventory(&"field_tonic", 2)
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_battle(player, _creature(&"gustlet", [&"updraft"]))
	manager.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)
	manager.submit_command(UseItemCommand.new(&"player", &"field_tonic", player.instance_id))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(inventory.get_quantity(&"field_tonic"), 1)
	var item_events := manager.events_of_type(BattleConstants.EVENT_ITEM_USED)
	assert_equal(item_events.size(), 1)
	assert_equal(item_events[0].payload["healing_applied"], 20)
	assert_true(manager.get_participant(&"player").current_hp > 0)
	var item_index := manager.event_history.find(item_events[0])
	var damage_index := manager.event_history.find(
		manager.events_of_type(BattleConstants.EVENT_DAMAGE_DEALT)[0]
	)
	assert_true(item_index < damage_index)


func _test_remedy_cures_persistent_status_in_battle() -> void:
	begin_case("remedy battle command")
	var player := _creature(&"cindermite", [&"cinder_jab"])
	player.persistent_status_ids.append(&"scorch")
	var inventory := _inventory(&"ember_salve")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_battle(player, _creature(&"gustlet", [&"updraft"]))
	manager.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)
	assert_true(manager.get_participant(&"player").has_status(&"scorch"))
	manager.submit_command(UseItemCommand.new(&"player", &"ember_salve", player.instance_id))
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_false(manager.get_participant(&"player").has_status(&"scorch"))
	assert_false(player.persistent_status_ids.has(&"scorch"))
	assert_equal(inventory.get_quantity(&"ember_salve"), 0)
	var removals := manager.events_of_type(BattleConstants.EVENT_STATUS_REMOVED)
	assert_equal(removals.size(), 1)
	assert_equal(removals[0].payload["reason"], &"item_used")


func _test_invalid_item_commands_preserve_stock() -> void:
	begin_case("invalid item command")
	var player := _creature(&"cindermite", [&"cinder_jab"])
	var inventory := _inventory(&"survey_compass")
	InventoryService.new(catalog).add(inventory, &"field_tonic")
	InventoryService.new(catalog).add(inventory, &"basic_capsule")
	var manager := BattleManager.new(catalog)
	manager.start_battle(player, _creature(&"gustlet", [&"updraft"]))
	manager.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)
	assert_false(manager.submit_command(
		UseItemCommand.new(&"player", &"survey_compass", player.instance_id)
	))
	assert_equal(manager.last_error, &"item_not_battle_usable")
	assert_false(manager.submit_command(
		UseItemCommand.new(&"player", &"basic_capsule", player.instance_id)
	))
	assert_equal(manager.last_error, &"capture_device_requires_capture_command")
	assert_false(manager.submit_command(
		UseItemCommand.new(&"player", &"field_tonic", "missing")
	))
	assert_equal(manager.last_error, &"unknown_item_target")
	assert_false(manager.submit_command(
		UseItemCommand.new(&"player", &"field_tonic", player.instance_id)
	))
	assert_equal(manager.last_error, &"target_at_full_hp")
	assert_equal(inventory.get_quantity(&"survey_compass"), 1)
	assert_equal(inventory.get_quantity(&"field_tonic"), 1)
	assert_equal(inventory.get_quantity(&"basic_capsule"), 1)


func _test_item_resolution_revalidates_stock_atomically() -> void:
	begin_case("item stock changed before resolution")
	var player := _creature(&"cindermite", [&"cinder_jab"], 1)
	var inventory := _inventory(&"field_tonic")
	var manager := BattleManager.new(
		catalog,
		FixedBattleRandomSource.new([0.0, 0.5, 1.0])
	)
	manager.start_battle(player, _creature(&"gustlet", [&"updraft"]))
	manager.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)
	assert_true(manager.submit_command(
		UseItemCommand.new(&"player", &"field_tonic", player.instance_id)
	))
	assert_true(InventoryService.new(catalog).remove(inventory, &"field_tonic").success)
	manager.submit_command(UseMoveCommand.new(&"opponent", &"updraft"))
	manager.resolve_turn()
	assert_equal(manager.events_of_type(BattleConstants.EVENT_ITEM_USED).size(), 0)
	var skipped := manager.events_of_type(BattleConstants.EVENT_COMMAND_SKIPPED)
	assert_equal(skipped.size(), 1)
	assert_equal(skipped[0].payload["reason"], &"insufficient_quantity")
	assert_equal(player.current_hp, 0)
