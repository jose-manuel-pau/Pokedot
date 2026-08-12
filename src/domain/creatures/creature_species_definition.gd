class_name CreatureSpeciesDefinition
extends Resource
## Immutable design-time data shared by every creature of this species.

@export var species_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var base_stats: CreatureStats = CreatureStats.new()
@export var element_types: Array[StringName] = []
@export_range(1, 255, 1) var catch_rate: int = 100
@export_range(1, 1000, 1) var experience_yield: int = 50
@export var growth_curve_id: StringName
@export var learnset: Array[LearnsetEntry] = []


func available_moves_at_level(level: int) -> Array[StringName]:
	var available: Array[StringName] = []
	for entry in learnset:
		if entry.level <= level and not available.has(entry.move_id):
			available.append(entry.move_id)
	return available

