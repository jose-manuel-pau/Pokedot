class_name StatusBehaviorRegistry
extends RefCounted
## Maps descriptive content tags to reusable hook strategies.

var _behaviors_by_tag: Dictionary = {}


func _init() -> void:
	register_behavior(&"action_denial", ActionDenialStatusBehavior.new())
	register_behavior(&"movement_lock", MovementLockStatusBehavior.new())
	register_behavior(&"speed_reduction", SpeedReductionStatusBehavior.new())
	register_behavior(&"damage_over_time", DamageOverTimeStatusBehavior.new())
	register_behavior(&"heat", PhysicalDamagePenaltyStatusBehavior.new())


func register_behavior(tag: StringName, behavior: StatusTagBehavior) -> void:
	if not str(tag).is_empty() and behavior != null:
		_behaviors_by_tag[tag] = behavior


func get_behaviors(tags: Array[StringName]) -> Array[StatusTagBehavior]:
	var matches: Array[StatusTagBehavior] = []
	for tag in tags:
		var behavior := _behaviors_by_tag.get(tag) as StatusTagBehavior
		if behavior != null:
			matches.append(behavior)
	return matches

