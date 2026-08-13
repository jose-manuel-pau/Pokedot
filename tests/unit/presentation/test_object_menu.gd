extends TestSuite

const OBJECT_MENU_SCENE := preload("res://src/presentation/inventory/object_menu.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("ObjectMenu")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_potions_are_first_and_details_show_potency()
	_test_using_potion_updates_hp_stock_and_feedback()
	_test_elixir_revives_a_fainted_creature()
	_test_up_and_down_navigation_reaches_use_and_close()
	_test_unusable_and_full_hp_choices_preserve_stock()
	_test_maximum_text_scale_keeps_actions_on_screen()
	_test_close_hides_menu_and_emits_signal()


func _creature(
	instance_id: String,
	species_id: StringName,
	level: int,
	damage: int
) -> CreatureInstance:
	var creature := BattleTestFactory.create_creature(species_id, level, [&"cinder_jab"])
	creature.instance_id = instance_id
	var maximum := StatCalculator.new().calculate_for_instance(
		catalog.get_species(species_id),
		creature
	).hp
	creature.current_hp = maxi(maximum - damage, 0)
	return creature


func _fixture() -> Dictionary:
	var inventory := Inventory.new()
	var inventory_service := InventoryService.new(catalog)
	inventory_service.add(inventory, &"basic_capsule", 5)
	inventory_service.add(inventory, &"ultra_potion", 1)
	inventory_service.add(inventory, &"potion", 2)
	inventory_service.add(inventory, &"mega_potion", 1)
	inventory_service.add(inventory, &"elixir", 2)
	var collection := CreatureCollection.new()
	var cindermite := _creature("object-cinder", &"cindermite", 12, 30)
	var reedling := _creature("object-reed", &"reedling", 10, 10)
	collection.party = [cindermite, reedling]
	var menu := OBJECT_MENU_SCENE.instantiate() as ObjectMenu
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)
	menu.open_menu(
		catalog,
		inventory,
		collection,
		reedling.instance_id,
		PlayerPreferences.new()
	)
	return {
		"menu": menu,
		"inventory": inventory,
		"collection": collection,
		"cindermite": cindermite,
		"reedling": reedling,
	}


func _test_potions_are_first_and_details_show_potency() -> void:
	begin_case("ordered object list and potency")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	assert_true(menu.visible)
	assert_equal(menu.get_item_ids(), [
		&"potion", &"mega_potion", &"ultra_potion", &"elixir", &"basic_capsule",
	])
	assert_equal(menu.count_label.text, "5 OBJECT TYPES")
	assert_equal(menu.get_selected_item_id(), &"potion")
	assert_equal(menu.get_selected_target_id(), "object-reed")
	assert_true(menu.get_item_button(&"potion").text.contains("x2"))
	assert_true(menu.choose_item(&"mega_potion"))
	assert_equal(menu.item_name.text, "Mega Potion")
	assert_equal(menu.potency_label.text, "RESTORES 50 HP")
	assert_true(menu.choose_item(&"ultra_potion"))
	assert_equal(menu.potency_label.text, "RESTORES 100 HP")
	assert_true(menu.choose_item(&"elixir"))
	assert_equal(menu.potency_label.text, "REVIVES WITH 50% MAX HP")
	assert_false(menu.choose_item(&"missing"))
	menu.free()


func _test_using_potion_updates_hp_stock_and_feedback() -> void:
	begin_case("object use updates live aggregate")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var inventory := fixture["inventory"] as Inventory
	var creature := fixture["cindermite"] as CreatureInstance
	var hp_before := creature.current_hp
	var observed: Array[Variant] = []
	menu.object_used.connect(func(item_id: StringName, instance_id: String, healed: int) -> void:
		observed.append_array([item_id, instance_id, healed])
	)
	assert_true(menu.choose_target(creature.instance_id))
	assert_true(menu.use_selected_item())
	assert_equal(creature.current_hp, hp_before + 20)
	assert_equal(inventory.get_quantity(&"potion"), 1)
	assert_equal(observed, [&"potion", creature.instance_id, 20])
	assert_true(menu.feedback_label.text.contains("restored 20 HP"))
	assert_true(menu.health_label.text.contains(str(creature.current_hp)))
	assert_true(menu.get_item_button(&"potion").text.contains("x1"))
	menu.free()


func _test_elixir_revives_a_fainted_creature() -> void:
	begin_case("object menu Elixir revival")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var inventory := fixture["inventory"] as Inventory
	var creature := fixture["cindermite"] as CreatureInstance
	var maximum := StatCalculator.new().calculate_for_instance(
		catalog.get_species(creature.species_id),
		creature
	).hp
	creature.current_hp = 0
	assert_true(menu.choose_item(&"elixir"))
	assert_true(menu.choose_target(creature.instance_id))
	assert_false(menu.use_button.disabled)
	assert_true(menu.use_selected_item())
	assert_equal(creature.current_hp, ceili(maximum * 0.5))
	assert_equal(inventory.get_quantity(&"elixir"), 1)
	assert_true(menu.feedback_label.text.contains("revived"))
	assert_true(menu.feedback_label.text.contains(str(creature.current_hp)))
	menu.free()


func _test_up_and_down_navigation_reaches_use_and_close() -> void:
	begin_case("vertical focus reaches object actions")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var creature := fixture["reedling"] as CreatureInstance
	assert_true(menu.choose_item(&"potion"))
	assert_true(menu.choose_target(creature.instance_id))
	assert_false(menu.use_button.disabled)
	var target_button := menu.get_target_button(creature.instance_id)
	target_button.grab_focus()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	menu._on_focusable_gui_input(down, target_button)
	assert_true(menu.use_button.has_focus(), "Down from the final target must reach Use.")
	menu._on_focusable_gui_input(down, menu.use_button)
	assert_true(menu.close_button.has_focus(), "Down from Use must reach Close.")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	menu._on_focusable_gui_input(up, menu.close_button)
	assert_true(menu.use_button.has_focus(), "Up from Close must return to Use.")
	assert_true(menu.choose_item(&"basic_capsule"))
	assert_true(menu.use_button.disabled)
	target_button.grab_focus()
	menu._on_focusable_gui_input(down, target_button)
	assert_true(menu.close_button.has_focus(), "Disabled Use must be skipped.")
	menu.free()


func _test_unusable_and_full_hp_choices_preserve_stock() -> void:
	begin_case("invalid menu use is atomic")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var inventory := fixture["inventory"] as Inventory
	var creature := fixture["cindermite"] as CreatureInstance
	assert_true(menu.choose_item(&"basic_capsule"))
	assert_true(menu.use_button.disabled)
	assert_false(menu.use_selected_item())
	assert_equal(inventory.get_quantity(&"basic_capsule"), 5)
	assert_true(menu.feedback_label.text.contains("unsupported field item"))
	creature.current_hp = StatCalculator.new().calculate_for_instance(
		catalog.get_species(creature.species_id),
		creature
	).hp
	assert_true(menu.choose_item(&"potion"))
	assert_true(menu.choose_target(creature.instance_id))
	assert_true(menu.use_button.disabled)
	assert_false(menu.use_selected_item())
	assert_equal(inventory.get_quantity(&"potion"), 2)
	assert_true(menu.feedback_label.text.contains("target at full hp"))
	menu.free()


func _test_maximum_text_scale_keeps_actions_on_screen() -> void:
	begin_case("maximum text scale containment")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var preferences := PlayerPreferences.new()
	preferences.text_scale = 1.5
	menu.set_preferences(preferences)
	assert_true(menu.get_rect().encloses(menu.use_button.get_global_rect()))
	assert_true(menu.get_rect().encloses(menu.close_button.get_global_rect()))
	assert_true(menu.use_button.visible)
	assert_true(menu.title_label.visible)
	menu.free()


func _test_close_hides_menu_and_emits_signal() -> void:
	begin_case("close object menu")
	var fixture := _fixture()
	var menu := fixture["menu"] as ObjectMenu
	var close_events: Array[bool] = []
	menu.menu_closed.connect(func() -> void:
		close_events.append(true)
	)
	menu.close_menu()
	assert_false(menu.visible)
	assert_equal(close_events.size(), 1)
	menu.close_menu()
	assert_equal(close_events.size(), 1)
	menu.free()
