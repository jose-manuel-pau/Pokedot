class_name CreaturePromptPackage
extends RefCounted
## Provider-ready prompt pair generated from one validated concept.

var species_id: StringName
var display_name: String
var art_direction_id: StringName
var prompt_version: int
var dalle_prompt: String
var midjourney_prompt: String
var negative_prompt: String


func to_dictionary() -> Dictionary:
	return {
		"species_id": str(species_id),
		"display_name": display_name,
		"art_direction_id": str(art_direction_id),
		"prompt_version": prompt_version,
		"dalle_3": dalle_prompt,
		"midjourney": midjourney_prompt,
		"negative_prompt": negative_prompt,
	}
