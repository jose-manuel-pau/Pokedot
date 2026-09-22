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
	_test_village_and_research_house_layout()


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
	assert_equal(map.get_tile_code(Vector2i(10, 1)), ExplorationMapDefinition.TILE_FENCE_HORIZONTAL)
	assert_false(map.is_walkable(Vector2i(10, 1)))
	assert_equal(map.get_tile_code(Vector2i(8, 3)), ExplorationMapDefinition.TILE_FENCE_VERTICAL)
	assert_false(map.is_walkable(Vector2i(8, 3)))
	assert_false(map.is_walkable(Vector2i(18, 5)))


func _test_zone_lookup() -> void:
	begin_case("encounter zone lookup")
	var grass_zone := map.get_zone_for_cell(Vector2i(3, 2))
	assert_not_null(grass_zone)
	if grass_zone != null:
		assert_equal(grass_zone.zone_id, &"sunmeadow_grass")
	var fern_zone := map.get_zone_for_cell(Vector2i(9, 4))
	assert_not_null(fern_zone)
	if fern_zone != null:
		assert_equal(fern_zone.zone_id, &"mistfern_patch")
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
	begin_case("open boundary exit placement")
	var map_exit := map.get_map_exit_at(Vector2i(17, 9))
	assert_not_null(map_exit)
	if map_exit == null:
		return
	assert_equal(map_exit.exit_id, &"eastward_trail")
	assert_equal(map_exit.destination_map_id, &"dewstone_vale")
	assert_equal(map_exit.destination_position, Vector2i(1, 9))
	assert_equal(map_exit.destination_facing, Vector2i.RIGHT)
	assert_equal(map_exit.transition_style, MapExitDefinition.STYLE_OPEN_PATH)
	assert_true(map.is_walkable(Vector2i(17, 9)))
	assert_equal(map.get_map_exit_at(Vector2i(16, 9)), null)


func _test_second_map_layout() -> void:
	begin_case("second map layout")
	var second_map := BattleTestFactory.create_catalog().get_map(&"dewstone_vale")
	assert_not_null(second_map)
	if second_map == null:
		return
	assert_equal(second_map.get_width(), 18)
	assert_equal(second_map.get_height(), 11)
	assert_true(second_map.is_walkable(second_map.spawn_position))
	var grass_zone := second_map.get_zone_for_cell(Vector2i(5, 1))
	assert_not_null(grass_zone)
	if grass_zone != null:
		assert_equal(grass_zone.zone_id, &"dewgrass_run")
	var fern_zone := second_map.get_zone_for_cell(Vector2i(3, 4))
	assert_not_null(fern_zone)
	if fern_zone != null:
		assert_equal(fern_zone.zone_id, &"silverfern_hollow")
	assert_equal(second_map.treasure_chests.size(), 3)
	assert_equal(second_map.npcs.size(), 1)
	assert_false(second_map.is_walkable(Vector2i(10, 1)))
	assert_false(second_map.is_walkable(Vector2i(9, 2)))
	var map_exit := second_map.get_map_exit_at(Vector2i(0, 9))
	assert_not_null(map_exit)
	if map_exit != null:
		assert_equal(map_exit.destination_map_id, &"mosslight_crossing")
	assert_true(second_map.is_walkable(Vector2i(0, 9)))
	var east_exit := second_map.get_map_exit_at(Vector2i(17, 9))
	assert_not_null(east_exit)
	if east_exit != null:
		assert_equal(east_exit.destination_map_id, &"lumenstead_village")
		assert_equal(east_exit.transition_style, MapExitDefinition.STYLE_OPEN_PATH)


func _test_village_and_research_house_layout() -> void:
	begin_case("village house and egg layout")
	var catalog := BattleTestFactory.create_catalog()
	var village := catalog.get_map(&"lumenstead_village")
	assert_not_null(village)
	if village == null:
		return
	assert_equal(village.get_width(), 18)
	assert_equal(village.get_height(), 11)
	assert_false(village.is_walkable(Vector2i(6, 1)))
	assert_equal(village.get_tile_code(Vector2i(6, 1)), ExplorationMapDefinition.TILE_BUILDING_WALL)
	assert_false(village.is_walkable(Vector2i(4, 5)))
	var house_door := village.get_map_exit_at(Vector2i(8, 3))
	assert_not_null(house_door)
	if house_door != null:
		assert_equal(house_door.destination_map_id, &"lumen_research_house")
		assert_equal(house_door.transition_style, MapExitDefinition.STYLE_DOOR)
	var house := catalog.get_map(&"lumen_research_house")
	assert_not_null(house)
	if house == null:
		return
	assert_equal(house.encounter_zones.size(), 0)
	assert_equal(house.npcs.size(), 1)
	assert_equal(house.npcs[0].display_name, "Professor Lumen")
	assert_equal(house.creature_gifts.size(), 3)
	assert_equal(house.get_creature_gift_at(Vector2i(5, 5)).species_id, &"cindermite")
	assert_equal(house.get_creature_gift_at(Vector2i(8, 5)).species_id, &"reedling")
	assert_equal(house.get_creature_gift_at(Vector2i(11, 5)).species_id, &"gustlet")
	assert_equal(house.get_map_exit_at(Vector2i(8, 10)).transition_style, MapExitDefinition.STYLE_DOOR)
