extends TestSuite

var catalog: ContentCatalog
var service: FieldItemUseService


func _init() -> void:
	super("FieldItemUseService")
	catalog = BattleTestFactory.create_catalog()
	service = FieldItemUseService.new(catalog)


func run() -> void:
	_test_three_potion_tiers_restore_increasing_hp()
	_test_healing_caps_at_maximum_hp()
	_test_elixir_revives_and_consumes_one_item()
	_test_rejections_preserve_inventory_and_hp()


func _creature(current_hp: int = 1) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(
		&"cindermite",
		50,
		[&"cinder_jab"],
		current_hp
	)
	creature.instance_id = "field-item-target"
	return creature


func _inventory(item_id: StringName, quantity: int = 1) -> Inventory:
	var inventory := Inventory.new()
	InventoryService.new(catalog).add(inventory, item_id, quantity)
	return inventory


func _test_three_potion_tiers_restore_increasing_hp() -> void:
	begin_case("potion healing tiers")
	var amounts := {
		&"potion": 20,
		&"mega_potion": 50,
		&"ultra_potion": 100,
	}
	for item_id in amounts.keys():
		var creature := _creature(1)
		var inventory := _inventory(item_id, 2)
		var result := service.use_on_creature(inventory, item_id, creature)
		assert_true(result.success, "%s should be usable in the field." % item_id)
		assert_equal(result.healing_applied, amounts[item_id])
		assert_equal(creature.current_hp, 1 + amounts[item_id])
		assert_equal(inventory.get_quantity(item_id), 1)
	assert_true(amounts[&"potion"] < amounts[&"mega_potion"])
	assert_true(amounts[&"mega_potion"] < amounts[&"ultra_potion"])


func _test_healing_caps_at_maximum_hp() -> void:
	begin_case("field healing maximum-HP cap")
	var creature := _creature(99999)
	var species := catalog.get_species(creature.species_id)
	var maximum := StatCalculator.new().calculate_for_instance(species, creature).hp
	creature.current_hp = maximum - 7
	var inventory := _inventory(&"ultra_potion")
	var result := service.use_on_creature(inventory, &"ultra_potion", creature)
	assert_true(result.success)
	assert_equal(result.healing_applied, 7)
	assert_equal(creature.current_hp, maximum)
	assert_equal(inventory.get_quantity(&"ultra_potion"), 0)


func _test_elixir_revives_and_consumes_one_item() -> void:
	begin_case("atomic field revival")
	var creature := _creature(0)
	var maximum := StatCalculator.new().calculate_for_instance(
		catalog.get_species(creature.species_id),
		creature
	).hp
	var inventory := _inventory(&"elixir", 2)
	var result := service.use_on_creature(inventory, &"elixir", creature)
	assert_true(result.success)
	assert_equal(result.healing_applied, ceili(maximum * 0.5))
	assert_equal(creature.current_hp, ceili(maximum * 0.5))
	assert_equal(inventory.get_quantity(&"elixir"), 1)
	result = service.use_on_creature(inventory, &"elixir", creature)
	assert_false(result.success)
	assert_equal(result.reason, &"target_not_defeated")
	assert_equal(inventory.get_quantity(&"elixir"), 1)


func _test_rejections_preserve_inventory_and_hp() -> void:
	begin_case("atomic invalid field use")
	var creature := _creature(10)
	var inventory := _inventory(&"potion", 2)
	assert_equal(
		service.use_on_creature(inventory, &"mega_potion", creature).reason,
		&"insufficient_quantity"
	)
	assert_equal(
		service.use_on_creature(inventory, &"basic_capsule", creature).reason,
		&"unsupported_field_item"
	)
	assert_equal(service.use_on_creature(inventory, &"missing", creature).reason, &"unknown_item")
	assert_equal(service.use_on_creature(inventory, &"potion", null).reason, &"missing_item_target")
	assert_equal(inventory.get_quantity(&"potion"), 2)
	assert_equal(creature.current_hp, 10)
	creature.current_hp = 0
	assert_equal(service.use_on_creature(inventory, &"potion", creature).reason, &"target_defeated")
	assert_equal(inventory.get_quantity(&"potion"), 2)
	creature.current_hp = StatCalculator.new().calculate_for_instance(
		catalog.get_species(creature.species_id),
		creature
	).hp
	assert_equal(service.use_on_creature(inventory, &"potion", creature).reason, &"target_at_full_hp")
	assert_equal(inventory.get_quantity(&"potion"), 2)
