class_name SpriteArtDirectionDefinition
extends Resource
## Shared visual constraints used to keep generated creature sprites cohesive.

@export var direction_id: StringName
@export var display_name: String
@export_range(1, 100, 1) var prompt_version: int = 1
@export var canvas_size: Vector2i = Vector2i(96, 96)
@export_multiline var rendering_style: String
@export_multiline var view_instruction: String
@export_multiline var lighting_instruction: String
@export_multiline var background_instruction: String
@export var composition_rules: Array[String] = []
@export var negative_terms: Array[String] = []
@export var midjourney_parameters: String
