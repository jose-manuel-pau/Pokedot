extends TestSuite

var catalog: ContentCatalog
var chest: TreasureChestDefinition


func _init() -> void:
	super("TreasureChestService")
	catalog = BattleTestFactory.create_catalog()
	chest = catalog.get_map(&"mosslight_crossing").get_treasure_chest_at(Vector2i(4, 9))


func run() -> void:
	_test_reward_roll_boundaries_are_deterministic()
	_test_invalid_chests_are_rejected_without_mutation()
	_test_inventory_capacity_failures_preserve_stock()


func _test_reward_roll_boundaries_are_deterministic() -> void:
	begin_case("deterministic restorative reward pool")
	var rolls := [0.0, 0.25, 0.5, 0.999999]
	var expected: Array[StringName] = [
		&"potion", &"mega_potion", &"ultra_potion", &"elixir",
	]
	for index in rolls.size():
		var random := FixedExplorationRandomSource.new([rolls[index]])
		var inventory := Inventory.new()
		var result := TreasureChestService.new(catalog, random).open(chest, inventory)
		assert_true(result.success)
		assert_equal(result.item_id, expected[index])
		assert_equal(result.quantity, 1)
		assert_equal(result.quantity_after, 1)
		assert_equal(inventory.get_quantity(expected[index]), 1)
		assert_equal(random.call_count, 1)


func _test_invalid_chests_are_rejected_without_mutation() -> void:
	begin_case("invalid treasure chest inputs")
	var random := FixedExplorationRandomSource.new([0.0])
	var service := TreasureChestService.new(catalog, random)
	var inventory := Inventory.new()
	assert_equal(service.open(null, inventory).reason, &"missing_treasure_chest")
	assert_equal(service.open(chest, null).reason, &"missing_inventory")
	var empty := TreasureChestDefinition.new()
	empty.chest_id = &"empty_cache"
	assert_equal(service.open(empty, inventory).reason, &"empty_chest_reward_pool")
	assert_equal(random.call_count, 0)
	empty.reward_item_ids = [&"potion"]
	empty.reward_quantity = 0
	assert_equal(service.open(empty, inventory).reason, &"invalid_chest_reward_quantity")
	assert_equal(random.call_count, 0)
	empty.reward_quantity = 1
	assert_equal(
		service.open(empty, inventory, &"elixir").reason,
		&"invalid_reserved_chest_reward"
	)
	assert_equal(random.call_count, 0)
	empty.reward_item_ids = [&"missing_item"]
	assert_equal(service.open(empty, inventory).reason, &"unknown_chest_reward")
	assert_equal(inventory.get_used_slots(), 0)


func _test_inventory_capacity_failures_preserve_stock() -> void:
	begin_case("atomic chest inventory capacity")
	var inventory := Inventory.new()
	var inventory_service := InventoryService.new(catalog)
	assert_true(inventory_service.add(inventory, &"potion", 99).success)
	var service := TreasureChestService.new(
		catalog,
		FixedExplorationRandomSource.new([0.0])
	)
	var result := service.open(chest, inventory)
	assert_false(result.success)
	assert_equal(result.reason, &"stack_limit_exceeded")
	assert_equal(result.item_id, &"potion")
	assert_equal(inventory.get_quantity(&"potion"), 99)
	var full_inventory := Inventory.new(1)
	assert_true(inventory_service.add(full_inventory, &"basic_capsule").success)
	result = service.open(chest, full_inventory)
	assert_false(result.success)
	assert_equal(result.reason, &"inventory_full")
	assert_equal(full_inventory.get_quantity(&"basic_capsule"), 1)
