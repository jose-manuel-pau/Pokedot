class_name CreatureConceptDefinition
extends Resource
## Art-facing creature brief linked to authoritative gameplay species data.

@export var concept_id: StringName
@export var species_id: StringName
@export var art_direction_id: StringName
@export var elemental_type_ids: Array[StringName] = []
@export_multiline var elemental_archetype: String
@export var mythology_inspirations: Array[String] = []
@export var wildlife_inspirations: Array[String] = []
@export_multiline var silhouette: String
@export_multiline var anatomy: String
@export_multiline var materials: String
@export_multiline var personality: String
@export var scale: String
@export var palette: CreaturePaletteDefinition = CreaturePaletteDefinition.new()
@export var signature_features: Array[String] = []
@export_multiline var pose_instruction: String
@export var visual_exclusions: Array[String] = []


func all_authored_text() -> String:
	var fragments: Array[String] = [
		elemental_archetype,
		silhouette,
		anatomy,
		materials,
		personality,
		scale,
		pose_instruction,
	]
	fragments.append_array(mythology_inspirations)
	fragments.append_array(wildlife_inspirations)
	fragments.append_array(signature_features)
	fragments.append_array(visual_exclusions)
	return " ".join(fragments)
