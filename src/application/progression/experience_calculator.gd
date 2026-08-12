class_name ExperienceCalculator
extends RefCounted
## Pure total-experience calculations for a data-defined growth curve.


func total_experience_for_level(curve: GrowthCurveDefinition, level: int) -> int:
	var safe_level := clampi(level, 1, curve.max_level)
	if safe_level == 1:
		return 0
	return floori(curve.scale * (pow(float(safe_level), curve.exponent) - 1.0))


func level_for_total_experience(curve: GrowthCurveDefinition, total_experience: int) -> int:
	var safe_experience := maxi(total_experience, 0)
	var low := 1
	var high := curve.max_level

	while low <= high:
		var middle := floori((low + high) / 2.0)
		var required := total_experience_for_level(curve, middle)
		if required <= safe_experience:
			low = middle + 1
		else:
			high = middle - 1
	return clampi(high, 1, curve.max_level)


func experience_to_next_level(curve: GrowthCurveDefinition, total_experience: int) -> int:
	var level := level_for_total_experience(curve, total_experience)
	if level >= curve.max_level:
		return 0
	return total_experience_for_level(curve, level + 1) - maxi(total_experience, 0)
