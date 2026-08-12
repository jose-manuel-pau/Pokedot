class_name ElementTypeDefinition
extends Resource
## Elemental matchup data from this attacking type to defending types.
## Missing matchups are intentionally neutral (1.0).

@export var type_id: StringName
@export var display_name: String
@export var color_hex: String = "#FFFFFF"
@export var effectiveness: Dictionary = {}


func multiplier_against(defending_type_id: StringName) -> float:
	return float(effectiveness.get(defending_type_id, 1.0))

