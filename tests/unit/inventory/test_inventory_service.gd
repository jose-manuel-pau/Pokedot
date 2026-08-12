extends TestSuite

var catalog: ContentCatalog
var service: InventoryService


func _init() -> void:
	super("InventoryService")
	catalog = BattleTestFactory.create_catalog()
	service = InventoryService.new(catalog)


func run() -> void:
	_test_add_and_remove_transactions()
	_test_invalid_transactions_preserve_state()
	_test_stack_limit_is_atomic()
	_test_slot_capacity_and_existing_stacks()
	_test_key_item_limit()


func _test_add_and_remove_transactions() -> void:
	begin_case("add and remove")
	var inventory := Inventory.new()
	var added := service.add(inventory, &"field_tonic", 3)
	assert_true(added.success)
	assert_equal(added.amount_changed, 3)
	assert_equal(added.quantity_after, 3)
	assert_equal(inventory.get_used_slots(), 1)
	assert_true(inventory.has(&"field_tonic", 2))
	var removed := service.remove(inventory, &"field_tonic", 2)
	assert_true(removed.success)
	assert_equal(removed.amount_changed, -2)
	assert_equal(inventory.get_quantity(&"field_tonic"), 1)
	assert_true(service.remove(inventory, &"field_tonic").success)
	assert_equal(inventory.get_used_slots(), 0)


func _test_invalid_transactions_preserve_state() -> void:
	begin_case("invalid transactions")
	var inventory := Inventory.new()
	assert_equal(service.add(inventory, &"missing", 1).reason, &"unknown_item")
	assert_equal(service.add(inventory, &"field_tonic", 0).reason, &"invalid_amount")
	assert_equal(service.remove(inventory, &"field_tonic", 1).reason, &"insufficient_quantity")
	assert_equal(service.remove(inventory, &"field_tonic", -1).reason, &"invalid_amount")
	assert_equal(inventory.get_used_slots(), 0)


func _test_stack_limit_is_atomic() -> void:
	begin_case("stack limit")
	var inventory := Inventory.new()
	assert_true(service.add(inventory, &"prism_capsule", 25).success)
	var overflow := service.add(inventory, &"prism_capsule", 1)
	assert_false(overflow.success)
	assert_equal(overflow.reason, &"stack_limit_exceeded")
	assert_equal(inventory.get_quantity(&"prism_capsule"), 25)


func _test_slot_capacity_and_existing_stacks() -> void:
	begin_case("slot capacity")
	var inventory := Inventory.new(1)
	assert_true(service.add(inventory, &"field_tonic", 1).success)
	assert_true(service.add(inventory, &"field_tonic", 1).success)
	var full := service.add(inventory, &"grand_tonic", 1)
	assert_false(full.success)
	assert_equal(full.reason, &"inventory_full")
	assert_equal(inventory.get_quantity(&"field_tonic"), 2)


func _test_key_item_limit() -> void:
	begin_case("key item stack")
	var inventory := Inventory.new()
	assert_true(service.add(inventory, &"survey_compass").success)
	assert_equal(service.add(inventory, &"survey_compass").reason, &"stack_limit_exceeded")
	assert_equal(inventory.get_quantity(&"survey_compass"), 1)
