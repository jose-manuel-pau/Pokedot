class_name ExperienceProgressService
extends RefCounted
## Builds consistent cumulative/current-level XP projections for every UI.

var _catalog: ContentCatalog
var _experience := ExperienceCalculator.new()


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func calculate(creature: CreatureInstance) -> ExperienceProgress:
	var progress := ExperienceProgress.new()
	if creature == null:
		progress.reason = &"missing_creature"
		return progress
	var species := _catalog.get_species(creature.species_id)
	if species == null:
		progress.reason = &"unknown_species"
		return progress
	var curve := _catalog.get_growth_curve(species.growth_curve_id)
	if curve == null:
		progress.reason = &"unknown_growth_curve"
		return progress

	progress.success = true
	progress.level = clampi(creature.level, 1, curve.max_level)
	progress.max_level = curve.max_level
	progress.level_start_experience = _experience.total_experience_for_level(
		curve,
		progress.level
	)
	var maximum_total := _experience.total_experience_for_level(
		curve,
		curve.max_level
	)
	progress.total_experience = clampi(
		maxi(creature.total_experience, progress.level_start_experience),
		0,
		maximum_total
	)
	progress.is_max_level = progress.level >= curve.max_level
	if progress.is_max_level:
		progress.next_level_experience = maximum_total
		progress.experience_into_level = 0
		progress.experience_for_level = 0
		progress.experience_remaining = 0
		return progress

	progress.next_level_experience = _experience.total_experience_for_level(
		curve,
		progress.level + 1
	)
	progress.experience_for_level = maxi(
		progress.next_level_experience - progress.level_start_experience,
		1
	)
	progress.experience_into_level = clampi(
		progress.total_experience - progress.level_start_experience,
		0,
		progress.experience_for_level
	)
	progress.experience_remaining = maxi(
		progress.experience_for_level - progress.experience_into_level,
		0
	)
	return progress
