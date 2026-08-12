class_name EncounterZoneDefinition
extends Resource
## Maps one tile symbol to an encounter table and per-step trigger rate.

@export var zone_id: StringName
@export var display_name: String
@export var tile_code: String = "g"
@export_range(0.0, 1.0, 0.01) var encounter_rate: float = 0.1
@export_range(0, 99, 1) var cooldown_steps: int = 3
@export var entries: Array[EncounterEntryDefinition] = []


func total_weight() -> int:
	var total := 0
	for entry in entries:
		total += maxi(entry.weight, 0)
	return total
