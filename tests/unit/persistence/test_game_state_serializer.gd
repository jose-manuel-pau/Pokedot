extends TestSuite

var catalog: ContentCatalog
var serializer := GameStateSerializer.new()


func _init() -> void:
	super("GameStateSerializer")
	catalog = BattleTestFactory.create_catalog()


func run() -> void:
	_test_json_compatible_round_trip()
	_test_complete_creature_state_round_trip()
	_test_deserialized_state_is_independent()


func _round_trip(state: PlayerGameState) -> PlayerGameState:
	var encoded := JSON.stringify(serializer.to_dictionary(state))
	var decoded: Dictionary = JSON.parse_string(encoded)
	return serializer.from_dictionary(decoded)


func _test_json_compatible_round_trip() -> void:
	begin_case("aggregate round trip")
	var original := GameStateTestFactory.create_valid_state(catalog)
	var data := serializer.to_dictionary(original)
	assert_equal(data["schema_version"], SaveGameMigrator.CURRENT_VERSION)
	assert_true(JSON.stringify(data).length() > 0)
	var loaded := _round_trip(original)
	assert_equal(loaded.player_id, original.player_id)
	assert_equal(loaded.player_name, original.player_name)
	assert_equal(loaded.play_time_seconds, original.play_time_seconds)
	assert_equal(loaded.current_map_id, original.current_map_id)
	assert_equal(loaded.player_position, original.player_position)
	assert_equal(loaded.player_facing, original.player_facing)
	assert_equal(loaded.inventory.max_slots, 12)
	assert_equal(loaded.inventory.get_quantity(&"basic_capsule"), 3)
	assert_equal(loaded.collection.party.size(), 1)
	assert_equal(loaded.collection.storage.size(), 1)


func _test_complete_creature_state_round_trip() -> void:
	begin_case("creature round trip")
	var loaded := _round_trip(GameStateTestFactory.create_valid_state(catalog))
	var creature := loaded.collection.party[0]
	assert_equal(creature.instance_id, "party-1")
	assert_equal(creature.species_id, &"cindermite")
	assert_equal(creature.nickname, "Coal")
	assert_equal(creature.level, 8)
	assert_equal(creature.genetic_potential.hp, 5)
	assert_equal(creature.training.attack, 10)
	assert_float_equal(creature.get_aptitude_modifier(&"attack"), 1.1)
	assert_equal(creature.learned_move_ids, [&"cinder_jab", &"stonepulse"])
	assert_equal(creature.persistent_status_ids, [&"scorch"])


func _test_deserialized_state_is_independent() -> void:
	begin_case("round-trip independence")
	var original := GameStateTestFactory.create_valid_state(catalog)
	var loaded := _round_trip(original)
	loaded.player_name = "Changed"
	loaded.inventory.quantities_by_item_id[&"basic_capsule"] = 1
	loaded.collection.party[0].nickname = "Changed"
	assert_equal(original.player_name, "Aster")
	assert_equal(original.inventory.get_quantity(&"basic_capsule"), 3)
	assert_equal(original.collection.party[0].nickname, "Coal")
