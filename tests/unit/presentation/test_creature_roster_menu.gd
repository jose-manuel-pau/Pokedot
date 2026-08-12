extends TestSuite

const ROSTER_SCENE := preload("res://src/presentation/collection/creature_roster_menu.tscn")

var catalog: ContentCatalog


func _init() -> void:
	super("CreatureRosterMenu")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_menu_lists_party_and_storage_captures()
	_test_storage_creature_can_be_selected_as_next_fighter()
	_test_reopening_menu_discovers_new_capture()
	_test_close_hides_menu_and_emits_signal()


func _creature(
	instance_id: String,
	species_id: StringName,
	level: int = 8
) -> CreatureInstance:
	var species := catalog.get_species(species_id)
	var creature := CreatureInstance.new()
	creature.instance_id = instance_id
	creature.species_id = species_id
	creature.level = level
	creature.learned_move_ids = species.available_moves_at_level(level)
	var curve := catalog.get_growth_curve(species.growth_curve_id)
	creature.total_experience = ExperienceCalculator.new().total_experience_for_level(
		curve,
		level
	) + 10
	creature.current_hp = StatCalculator.new().calculate_for_instance(
		species,
		creature
	).hp
	return creature


func _fixture() -> Dictionary:
	var collection := CreatureCollection.new()
	var cindermite := _creature("starter", &"cindermite")
	var reedling := _creature("capture-party", &"reedling")
	var gustlet := _creature("capture-storage", &"gustlet")
	collection.party = [cindermite, reedling]
	collection.storage = [gustlet]
	var menu := ROSTER_SCENE.instantiate() as CreatureRosterMenu
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)
	menu.open_roster(catalog, collection, reedling.instance_id, PlayerPreferences.new())
	return {"menu": menu, "collection": collection}


func _test_menu_lists_party_and_storage_captures() -> void:
	begin_case("complete captured roster")
	var fixture := _fixture()
	var menu := fixture["menu"] as CreatureRosterMenu
	assert_true(menu.visible)
	assert_equal(menu.get_entry_instance_ids(), [
		"starter", "capture-party", "capture-storage"
	])
	assert_equal(menu.count_label.text, "3 CAPTURED")
	assert_equal(menu.get_selected_instance_id(), "capture-party")
	assert_true(menu.get_entry_button("capture-party").button_pressed)
	assert_true(menu.get_entry_button("starter").text.contains("PARTY"))
	assert_true(menu.get_entry_button("capture-storage").text.contains("STORAGE"))
	assert_equal(menu.detail_name.text, "Reedling")
	assert_true(menu.detail_meta.text.contains("TIDE / GROVE"))
	assert_true(menu.get_entry_button("capture-party").text.contains("XP "))
	assert_true(menu.experience_bar.value > 0.0)
	assert_true(menu.experience_label.text.contains("Total"))
	assert_true(menu.experience_label.text.contains("to next"))
	menu.free()


func _test_storage_creature_can_be_selected_as_next_fighter() -> void:
	begin_case("storage selection")
	var fixture := _fixture()
	var menu := fixture["menu"] as CreatureRosterMenu
	var selected_ids: Array[String] = []
	menu.lead_selected.connect(func(instance_id: String) -> void:
		selected_ids.append(instance_id)
	)
	assert_true(menu.choose_creature("capture-storage"))
	assert_equal(menu.get_selected_instance_id(), "capture-storage")
	assert_equal(selected_ids, ["capture-storage"])
	assert_true(menu.get_entry_button("capture-storage").button_pressed)
	assert_false(menu.get_entry_button("capture-party").button_pressed)
	assert_equal(menu.detail_name.text, "Gustlet")
	assert_true(menu.selection_label.text.contains("next wild battle"))
	assert_false(menu.choose_creature("missing"))
	assert_equal(selected_ids.size(), 1)
	menu.free()


func _test_reopening_menu_discovers_new_capture() -> void:
	begin_case("live collection refresh")
	var fixture := _fixture()
	var menu := fixture["menu"] as CreatureRosterMenu
	var collection := fixture["collection"] as CreatureCollection
	menu.close_roster()
	var new_capture := _creature("new-capture", &"aurorook", 10)
	assert_true(CreatureCollectionService.new().add_captured(
		collection,
		new_capture
	).success)
	menu.open_roster(catalog, collection, "capture-party", PlayerPreferences.new())
	assert_equal(menu.get_entry_instance_ids().size(), 4)
	assert_true(menu.get_entry_instance_ids().has("new-capture"))
	assert_not_null(menu.get_entry_button("new-capture"))
	menu.free()


func _test_close_hides_menu_and_emits_signal() -> void:
	begin_case("close roster")
	var fixture := _fixture()
	var menu := fixture["menu"] as CreatureRosterMenu
	var close_events: Array[bool] = []
	menu.roster_closed.connect(func() -> void:
		close_events.append(true)
	)
	menu.close_roster()
	assert_false(menu.visible)
	assert_equal(close_events.size(), 1)
	menu.close_roster()
	assert_equal(close_events.size(), 1)
	menu.free()
