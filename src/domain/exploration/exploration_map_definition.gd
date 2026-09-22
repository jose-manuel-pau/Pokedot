class_name ExplorationMapDefinition
extends Resource
## Versioned top-down grid. Tile symbols carry terrain meaning without binding
## domain code to Godot TileMap resources or presentation assets.

const TILE_WALL := "#"
const TILE_PATH := "."
const TILE_FENCE_HORIZONTAL := "-"
const TILE_FENCE_VERTICAL := "|"
const TILE_BUILDING_WALL := "H"

@export var map_id: StringName
@export var display_name: String
@export_range(8, 128, 1) var tile_size: int = 48
@export var spawn_position: Vector2i
@export var tile_rows: Array[String] = []
@export var encounter_zones: Array[EncounterZoneDefinition] = []
@export var npcs: Array[NpcDefinition] = []
@export var treasure_chests: Array[TreasureChestDefinition] = []
@export var map_exits: Array[MapExitDefinition] = []
@export var creature_gifts: Array[CreatureGiftDefinition] = []


func get_width() -> int:
	return tile_rows[0].length() if not tile_rows.is_empty() else 0


func get_height() -> int:
	return tile_rows.size()


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < get_width() and cell.y < get_height()


func get_tile_code(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return TILE_WALL
	return tile_rows[cell.y].substr(cell.x, 1)


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_blocking_tile_code(get_tile_code(cell))


static func is_blocking_tile_code(tile_code: String) -> bool:
	return tile_code in [
		TILE_WALL,
		TILE_FENCE_HORIZONTAL,
		TILE_FENCE_VERTICAL,
		TILE_BUILDING_WALL,
	]


static func is_reserved_tile_code(tile_code: String) -> bool:
	return tile_code in [
		TILE_WALL,
		TILE_PATH,
		TILE_FENCE_HORIZONTAL,
		TILE_FENCE_VERTICAL,
		TILE_BUILDING_WALL,
	]


func get_zone_for_cell(cell: Vector2i) -> EncounterZoneDefinition:
	var code := get_tile_code(cell)
	for zone in encounter_zones:
		if zone.tile_code == code:
			return zone
	return null


func get_npc_at(cell: Vector2i) -> NpcDefinition:
	for npc in npcs:
		if npc.grid_position == cell:
			return npc
	return null


func get_treasure_chest_at(cell: Vector2i) -> TreasureChestDefinition:
	for chest in treasure_chests:
		if chest.grid_position == cell:
			return chest
	return null


func get_map_exit_at(cell: Vector2i) -> MapExitDefinition:
	for map_exit in map_exits:
		if map_exit.grid_position == cell:
			return map_exit
	return null


func get_creature_gift_at(cell: Vector2i) -> CreatureGiftDefinition:
	for gift in creature_gifts:
		if gift.grid_position == cell:
			return gift
	return null
