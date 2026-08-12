class_name MoveDefinition
extends Resource
## Data-only move definition. Execution belongs to the future battle module.

const VALID_CATEGORIES: Array[String] = ["physical", "special", "status"]

@export var move_id: StringName
@export var display_name: String
@export var element_type_id: StringName
@export_enum("physical", "special", "status") var category: String = "physical"
@export_range(0, 500, 1) var power: int = 0
@export_range(0.0, 100.0, 0.1) var accuracy: float = 100.0
@export_range(1, 99, 1) var max_uses: int = 10
@export_range(-10, 10, 1) var priority: int = 0
@export var status_effect_id: StringName
@export_range(0.0, 100.0, 0.1) var status_chance: float = 0.0
