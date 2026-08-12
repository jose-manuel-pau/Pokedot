class_name ContentPipelineService
extends RefCounted
## Validates source content and compiles deterministic provider prompt artifacts.

const MANIFEST_VERSION := 1

var _catalog: ContentCatalog
var _generator: CreaturePromptGenerator


func _init(
	catalog: ContentCatalog,
	generator: CreaturePromptGenerator = null
) -> void:
	_catalog = catalog
	_generator = generator if generator != null else CreaturePromptGenerator.new()


func compile() -> ContentPipelineResult:
	var result := ContentPipelineResult.new()
	if _catalog == null:
		result.issues.append(ValidationIssue.create(
			ValidationIssue.Severity.ERROR,
			&"missing_content_catalog",
			"content_pipeline",
			"A content catalog is required."
		))
		return result
	result.issues = ContentValidator.new().validate(_catalog)
	if result.has_errors():
		return result
	var concept_ids: Array = _catalog.creature_concepts_by_id.keys()
	concept_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str(left) < str(right)
	)
	for raw_concept_id in concept_ids:
		var concept := _catalog.get_creature_concept(StringName(str(raw_concept_id)))
		var species := _catalog.get_species(concept.species_id)
		var direction := _catalog.get_art_direction(concept.art_direction_id)
		var package := _generator.generate(
			concept,
			species,
			direction,
			_type_display_names(concept.elemental_type_ids)
		)
		if package != null:
			result.packages.append(package)
	var prompt_data: Array[Dictionary] = []
	for package in result.packages:
		prompt_data.append(package.to_dictionary())
	result.manifest = {
		"schema_version": MANIFEST_VERSION,
		"generator": "pokedot_content_pipeline",
		"prompt_count": prompt_data.size(),
		"prompts": prompt_data,
	}
	return result


func _type_display_names(type_ids: Array[StringName]) -> Array[String]:
	var names: Array[String] = []
	for type_id in type_ids:
		var definition := _catalog.get_type(type_id)
		names.append(definition.display_name if definition != null else str(type_id))
	return names
