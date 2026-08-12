class_name CreaturePromptGenerator
extends RefCounted
## Pure prompt composer. It has no filesystem or image-provider dependency.


func generate(
	concept: CreatureConceptDefinition,
	species: CreatureSpeciesDefinition,
	direction: SpriteArtDirectionDefinition,
	type_names: Array[String]
) -> CreaturePromptPackage:
	if concept == null or species == null or direction == null:
		return null
	var package := CreaturePromptPackage.new()
	package.species_id = species.species_id
	package.display_name = species.display_name
	package.art_direction_id = direction.direction_id
	package.prompt_version = direction.prompt_version
	package.negative_prompt = _join_unique(
		direction.negative_terms + concept.visual_exclusions,
		", "
	)
	var palette := concept.palette
	var subject := (
		"%s, an original %s creature. Elemental identity: %s. "
		+ "Wildlife foundation: %s. Transformed folklore inspiration: %s. "
		+ "Silhouette: %s. Anatomy: %s. Surface materials: %s. "
		+ "Signature features: %s. Personality: %s. Scale: %s. Pose: %s. "
		+ "Restricted palette: primary %s, secondary %s, accent %s, outline %s."
	) % [
		species.display_name,
		concept.elemental_archetype,
		_join(type_names, " and "),
		_join(concept.wildlife_inspirations, ", "),
		_join(concept.mythology_inspirations, ", "),
		concept.silhouette,
		concept.anatomy,
		concept.materials,
		_join(concept.signature_features, "; "),
		concept.personality,
		concept.scale,
		concept.pose_instruction,
		palette.primary,
		palette.secondary,
		palette.accent,
		palette.outline,
	]
	var production := (
		"Art direction: %s. View: %s. Lighting: %s. Background: %s. "
		+ "Composition rules: %s. Keep the design readable at %dx%d pixels and independent of existing franchises."
	) % [
		direction.rendering_style,
		direction.view_instruction,
		direction.lighting_instruction,
		direction.background_instruction,
		_join(direction.composition_rules, "; "),
		direction.canvas_size.x,
		direction.canvas_size.y,
	]
	package.dalle_prompt = "Create a single clean game-sprite asset. %s %s Avoid: %s." % [
		subject, production, package.negative_prompt
	]
	package.midjourney_prompt = "%s %s --no %s %s" % [
		subject,
		production,
		package.negative_prompt,
		direction.midjourney_parameters,
	]
	return package


func _join(values: Array[String], separator: String) -> String:
	return separator.join(PackedStringArray(values))


func _join_unique(values: Array[String], separator: String) -> String:
	var unique: Array[String] = []
	for value in values:
		var normalized := value.strip_edges()
		if not normalized.is_empty() and not unique.has(normalized):
			unique.append(normalized)
	return _join(unique, separator)
