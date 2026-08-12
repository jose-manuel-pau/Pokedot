class_name SaveGameMigrator
extends RefCounted
## Explicit compatibility boundary. Version 0 is upgraded to the nested version
## 1 shape; unknown future formats are rejected without partial loading.

const CURRENT_VERSION := 1


func migrate(raw_data: Variant) -> SaveMigrationResult:
	var result := SaveMigrationResult.new()
	if not raw_data is Dictionary:
		result.reason = &"invalid_save_root"
		return result
	var data := raw_data as Dictionary
	result.source_version = int(data.get("schema_version", 0))
	if result.source_version == CURRENT_VERSION:
		result.success = true
		result.data = data.duplicate(true)
		return result
	if result.source_version == 0:
		result.success = true
		result.migrated = true
		result.data = _migrate_v0_to_v1(data)
		return result
	result.reason = &"unsupported_save_version"
	return result


func _migrate_v0_to_v1(legacy: Dictionary) -> Dictionary:
	var inventory: Variant = legacy.get("inventory", {})
	if not inventory is Dictionary or not inventory.has("quantities"):
		inventory = {
			"max_slots": Inventory.DEFAULT_MAX_SLOTS,
			"quantities": legacy.get("items", {}),
		}
	return {
		"schema_version": CURRENT_VERSION,
		"profile": {
			"player_id": legacy.get("player_id", ""),
			"player_name": legacy.get("player_name", ""),
		},
		"play_time_seconds": legacy.get("play_time_seconds", 0),
		"exploration": {
			"map_id": legacy.get("map_id", ""),
			"position": legacy.get("player_position", [0, 0]),
			"facing": legacy.get("player_facing", [0, 1]),
		},
		"inventory": inventory,
		"collection": {
			"party": legacy.get("party", []),
			"storage": legacy.get("storage", []),
		},
	}
