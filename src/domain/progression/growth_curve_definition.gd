class_name GrowthCurveDefinition
extends Resource
## Safe data-driven total-XP curve: scale * (level ^ exponent - 1).
## No arbitrary expressions are evaluated from content files.

@export var curve_id: StringName
@export var display_name: String
@export_range(2, 200, 1) var max_level: int = 100
@export_range(0.01, 100.0, 0.01) var scale: float = 1.0
@export_range(1.01, 6.0, 0.01) var exponent: float = 3.0

