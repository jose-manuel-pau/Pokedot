extends TestSuite

var map: ExplorationMapDefinition


func _init() -> void:
	super("ExplorationMapDefinition")
	map = BattleTestFactory.create_catalog().get_map(&"mosslight_crossing")


func run() -> void:
	_test_dimensions_and_tile_queries()
	_test_collision_boundaries()
	_test_zone_lookup()
	_test_npc_lookup()
	_test_treasure_chest_lookup()
	_test_map_exit_lookup()
	_test_second_map_layout()


func _test_dimensions_and_tile_queries() -> void:
	begin_case("map dimensions")
	assert_equal(map.get_width(), 18)
	assert_equal(map.get_height(), 11)
	assert_equal(map.get_tile_code(Vector2i(0, 0)), ExplorationMapDefinition.TILE_WALL)
	assert_equal(map.get_tile_code(Vector2i(1, 1)), ExplorationMapDefinition.TILE_PATH)
	assert_equal(map.get_tile_code(Vector2i(-1, 0)), ExplorationMapDefinition.TILE_WALL)


func _test_collision_boundaries() -> void:
	begin_case("terrain collision")
	assert_true(map.is_walkable(map.spawn_position))
	assert_true(map.is_walkable(Vector2i(3, 2)))
	assert_false(map.is_walkable(Vector2i(0, 0)))
	assert_false(map.is_walkable(Vector2i(9, 2)))
	assert_false(map.is_walkable(Vector2i(18, 5)))


func _test_zone_lookup() -> void:
	begin_case("encounter zone lookup")
	assert_equal(map.get_zone_for_cell(Vector2i(3, 2)).zone_id, &"sunmeadow_grass")
	assert_equal(map.get_zone_for_cell(Vector2i(8, 4)).zone_id, &"mistfern_patch")
	assert_equal(map.get_zone_for_cell(Vector2i(1, 1)), null)


func _test_npc_lookup() -> void:
	begin_case("npc placement")
	var npc := map.get_npc_at(Vector2i(14, 7))
	assert_not_null(npc)
	assert_equal(npc.npc_id, &"ranger_mira")
	assert_equal(npc.facing, Vector2i.LEFT)
	assert_equal(map.get_npc_at(Vector2i(13, 7)), null)


func _test_treasure_chest_lookup() -> void:
	begin_case("treasure chest placement")
	assert_equal(map.treasure_chests.size(), 3)
	var chest := map.get_treasure_chest_at(Vector2i(4, 9))
	assert_not_null(chest)
	assert_equal(chest.chest_id, &"trailhead_cache")
	assert_equal(chest.display_name, "Trailhead Cache")
	assert_equal(chest.reward_item_ids, [
		&"potion", &"mega_potion", &"ultra_potion", &"elixir",
	])
	assert_equal(chest.reward_quantity, 1)
	assert_equal(map.get_treasure_chest_at(Vector2i(3, 9)), null)


func _test_map_exit_lookup() -> void:
	begin_case("map exit placement")
	var map_exit := map.get_map_exit_at(Vector2i(16, 9))
	assert_not_null(map_exit)
	assert_equal(map_exit.exit_id, &"eastward_trail")
	assert_equal(map_exit.destination_map_id, &"dewstone_vale")
	assert_equal(map_exit.destination_position, Vector2i(2, 9))
	assert_equal(map_exit.destination_facing, Vector2i.RIGHT)
	assert_equal(map.get_map_exit_at(Vector2i(15, 9)), null)


func _test_second_map_layout() -> void:
	begin_case("second map layout")
	var second_map := BattleTestFactory.create_catalog().get_map(&"dewstone_vale")
	assert_not_null(second_map)
	assert_equal(second_map.get_width(), 18)
	assert_equal(second_map.get_height(), 11)
	assert_true(second_map.is_walkable(second_map.spawn_position))
	assert_equal(second_map.get_zone_for_cell(Vector2i(5, 1)).zone_id, &"dewgrass_run")
	assert_equal(second_map.get_zone_for_cell(Vector2i(3, 4)).zone_id, &"silverfern_hollow")
	assert_equal(second_map.treasure_chests.size(), 3)
	assert_equal(second_map.npcs.size(), 1)
	assert_equal(second_map.get_map_exit_at(Vector2i(1, 9)).destination_map_id, &"mosslight_crossing")
