class_name CreatureInstance
extends RefCounted
## Mutable, saveable state belonging to one individual creature. Species data is
## referenced by ID to keep save files small and migratable.

var instance_id: String
var species_id: StringName
var nickname: String
var level: int = 1
var total_experience: int = 0
var current_hp: int = 1
var genetic_potential: CreatureStats = CreatureStats.new()
var training: CreatureStats = CreatureStats.new()
var aptitude_modifiers: Dictionary = {}
var learned_move_ids: Array[StringName] = []
var persistent_status_ids: Array[StringName] = []


func get_aptitude_modifier(stat_id: StringName) -> float:
	return float(aptitude_modifiers.get(stat_id, 1.0))

