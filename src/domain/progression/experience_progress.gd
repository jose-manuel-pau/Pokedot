class_name ExperienceProgress
extends RefCounted
## Read-only projection for presentation. Total XP remains the saved source of
## truth; the bar displays progress inside the creature's current level.

var success: bool = false
var reason: StringName = &""
var level: int = 1
var max_level: int = 1
var total_experience: int = 0
var level_start_experience: int = 0
var next_level_experience: int = 0
var experience_into_level: int = 0
var experience_for_level: int = 0
var experience_remaining: int = 0
var is_max_level: bool = false


func ratio() -> float:
	if not success:
		return 0.0
	if is_max_level:
		return 1.0
	if experience_for_level <= 0:
		return 0.0
	return clampf(
		float(experience_into_level) / float(experience_for_level),
		0.0,
		1.0
	)
