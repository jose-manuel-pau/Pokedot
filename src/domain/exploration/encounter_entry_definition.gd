class_name EncounterEntryDefinition
extends Resource
## One weighted species/level option inside an encounter zone.

@export var species_id: StringName
@export_range(1, 200, 1) var min_level: int = 1
@export_range(1, 200, 1) var max_level: int = 1
@export_range(1, 10000, 1) var weight: int = 1
