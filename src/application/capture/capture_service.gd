class_name CaptureService
extends RefCounted
## Deterministic capture probability service. It never changes inventory,
## collection, or battle state; orchestration belongs to BattleManager.

const CATCH_RATE_SCALE := 255.0
const MIN_CHANCE := 0.01
const MAX_CHANCE := 0.95
const MAX_STATUS_MULTIPLIER := 2.5
const CRITICAL_RATE := 0.15
const MAX_CRITICAL_CHANCE := 0.25

var _catalog: ContentCatalog
var _random: BattleRandomSource


func _init(catalog: ContentCatalog, random_source: BattleRandomSource) -> void:
	_catalog = catalog
	_random = random_source


func attempt(
	target: BattleParticipant,
	device: ItemDefinition,
	encounter_multiplier: float = 1.0
) -> CaptureResult:
	var result := CaptureResult.new()
	if target == null:
		result.reason = &"missing_capture_target"
		return result
	if device == null or not device.is_capture_device():
		result.reason = &"invalid_capture_device"
		return result
	if target.is_defeated():
		result.reason = &"capture_target_defeated"
		return result
	result.device_multiplier = device.capture_multiplier
	result.encounter_multiplier = maxf(encounter_multiplier, 0.0)
	var hp_ratio := float(target.current_hp) / float(target.get_max_hp())
	result.health_multiplier = 1.0 + 2.0 * (1.0 - hp_ratio)
	result.status_multiplier = _get_status_multiplier(target)
	var raw_chance := (float(target.species.catch_rate) / CATCH_RATE_SCALE) \
		* result.health_multiplier \
		* result.status_multiplier \
		* result.device_multiplier \
		* result.encounter_multiplier
	result.chance = clampf(raw_chance, MIN_CHANCE, MAX_CHANCE)
	result.critical_chance = minf(result.chance * CRITICAL_RATE, MAX_CRITICAL_CHANCE)
	result.success_roll = _random.next_float()
	result.critical_roll = _random.next_float()
	result.success = result.success_roll < result.chance
	result.critical = result.success and result.critical_roll < result.critical_chance
	return result


func _get_status_multiplier(target: BattleParticipant) -> float:
	var multiplier := 1.0
	for status_id in target.active_statuses_by_id.keys():
		var status := _catalog.get_status(status_id)
		if status != null:
			multiplier *= status.capture_multiplier
	return minf(multiplier, MAX_STATUS_MULTIPLIER)
