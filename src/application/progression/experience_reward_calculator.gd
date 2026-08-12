class_name ExperienceRewardCalculator
extends RefCounted
## Pure reward formula. Trainer battles pay a modest premium; sharing is handled
## by BattleRewardService so this calculator remains creature-focused.

const TRAINER_MULTIPLIER := 1.25


func calculate(
	defeated_species: CreatureSpeciesDefinition,
	defeated_level: int,
	is_trainer_battle: bool = false
) -> int:
	if defeated_species == null or defeated_level <= 0:
		return 0
	var multiplier := TRAINER_MULTIPLIER if is_trainer_battle else 1.0
	return maxi(
		floori(defeated_species.experience_yield * defeated_level * multiplier / 5.0),
		1
	)
