class_name TreasureChestDefinition
extends Resource
## Immutable map content for one interactable chest. Reward selection and
## inventory mutation remain in TreasureChestService.

@export var chest_id: StringName
@export var display_name: String
@export var grid_position: Vector2i
@export var reward_item_ids: Array[StringName] = []
@export_range(1, 99, 1) var reward_quantity: int = 1
