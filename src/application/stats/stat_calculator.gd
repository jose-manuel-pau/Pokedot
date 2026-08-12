class_name StatCalculator
extends RefCounted
## Pure stat service. It has no dependency on scenes, files, random numbers, or UI.

const MIN_LEVEL := 1
const MAX_LEVEL := 200
const MAX_GENETIC_POTENTIAL := 20
const MAX_TRAINING_PER_STAT := 200
const MAX_TRAINING_TOTAL := 500
const MIN_APTITUDE_MODIFIER := 0.5
const MAX_APTITUDE_MODIFIER := 1.5


func calculate_for_instance(
	species: CreatureSpeciesDefinition,
	creature: CreatureInstance
) -> CreatureStats:
	var calculated := CreatureStats.new()
	for stat_id in CreatureStats.STAT_IDS:
		calculated.set_value(
			stat_id,
			calculate_stat(
				species.base_stats.get_value(stat_id),
				creature.level,
				creature.genetic_potential.get_value(stat_id),
				creature.training.get_value(stat_id),
				stat_id == &"hp",
				creature.get_aptitude_modifier(stat_id),
			)
		)
	return calculated


func calculate_stat(
	base_stat: int,
	level: int,
	genetic_potential: int = 0,
	training_points: int = 0,
	is_hp: bool = false,
	aptitude_modifier: float = 1.0
) -> int:
	var safe_base := maxi(base_stat, 1)
	var safe_level := clampi(level, MIN_LEVEL, MAX_LEVEL)
	var safe_potential := clampi(genetic_potential, 0, MAX_GENETIC_POTENTIAL)
	var safe_training := clampi(training_points, 0, MAX_TRAINING_PER_STAT)
	var safe_modifier := clampf(
		aptitude_modifier,
		MIN_APTITUDE_MODIFIER,
		MAX_APTITUDE_MODIFIER
	)
	var trained_value := 2 * safe_base + safe_potential + floori(safe_training / 10.0)
	var scaled_value := floori(trained_value * safe_level / 100.0)

	if is_hp:
		return scaled_value + safe_level + 15
	return floori((scaled_value + 5) * safe_modifier)


func is_training_valid(training: CreatureStats) -> bool:
	if training.sum() > MAX_TRAINING_TOTAL:
		return false
	for stat_id in CreatureStats.STAT_IDS:
		var value := training.get_value(stat_id)
		if value < 0 or value > MAX_TRAINING_PER_STAT:
			return false
	return true
