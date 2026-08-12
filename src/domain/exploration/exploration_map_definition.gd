class_name ExplorationMapDefinition
extends Resource
## Versioned top-down grid. Tile symbols carry terrain meaning without binding
## domain code to Godot TileMap resources or presentation assets.

const TILE_WALL := "#"
const TILE_PATH := "."

@export var map_id: StringName
@export var display_name: String
@export_range(8, 128, 1) var tile_size: int = 48
@export var spawn_position: Vector2i
@export var tile_rows: Array[String] = []
@export var encounter_zones: Array[EncounterZoneDefinition] = []
@export var npcs: Array[NpcDefinition] = []


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
	return is_in_bounds(cell) and get_tile_code(cell) != TILE_WALL


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
