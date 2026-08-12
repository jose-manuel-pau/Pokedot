class_name StatusConditionDefinition
extends Resource
## Descriptive status data. Runtime hooks and behavior strategies are added by
## the battle module; capture_multiplier is already consumed by capture rules.

const VALID_CATEGORIES: Array[String] = ["persistent", "volatile"]

@export var status_id: StringName
@export var display_name: String
@export_enum("persistent", "volatile") var category: String = "persistent"
@export_range(0.01, 5.0, 0.01) var capture_multiplier: float = 1.0
@export_range(0, 99, 1) var max_duration_turns: int = 0
@export var stackable: bool = false
@export var tags: Array[StringName] = []
