class_name DamageCalculator
extends RefCounted
## Pure combat math plus injected randomness. It neither changes HP nor emits UI
## events; BattleManager owns those responsibilities.

const SAME_TYPE_BONUS := 1.25
const CRITICAL_CHANCE := 0.0625
const CRITICAL_MULTIPLIER := 1.5
const MIN_VARIANCE := 0.9
const MAX_VARIANCE := 1.0

var _type_service: TypeEffectivenessService
var _random: BattleRandomSource
var _status_service: StatusEffectService


func _init(
	type_service: TypeEffectivenessService,
	random_source: BattleRandomSource,
	status_service: StatusEffectService = null
) -> void:
	_type_service = type_service
	_random = random_source
	_status_service = status_service


func resolve(
	attacker: BattleParticipant,
	defender: BattleParticipant,
	move: MoveDefinition
) -> DamageResult:
	var result := DamageResult.new()
	result.accuracy_roll = _random.next_float() * 100.0
	if result.accuracy_roll >= move.accuracy:
		return result
	result.hit = true

	if move.category == "status" or move.power <= 0:
		return result

	var attacking_stat := attacker.calculated_stats.attack
	var defending_stat := defender.calculated_stats.defense
	if move.category == "special":
		attacking_stat = attacker.calculated_stats.special_attack
		defending_stat = defender.calculated_stats.special_defense

	result.critical = _random.next_float() < CRITICAL_CHANCE
	result.variance = lerpf(MIN_VARIANCE, MAX_VARIANCE, _random.next_float())
	if attacker.species.element_types.has(move.element_type_id):
		result.same_type_bonus = SAME_TYPE_BONUS
	result.type_multiplier = _type_service.get_multiplier(
		move.element_type_id,
		defender.species.element_types
	)

	var level_factor := (2.0 * attacker.creature.level + 10.0) / 250.0
	var stat_ratio := float(attacking_stat) / float(maxi(defending_stat, 1))
	var base_damage := level_factor * stat_ratio * move.power + 2.0
	var critical_modifier := CRITICAL_MULTIPLIER if result.critical else 1.0
	var modified_damage := base_damage \
		* result.same_type_bonus \
		* result.type_multiplier \
		* critical_modifier \
		* result.variance

	if result.type_multiplier <= 0.0:
		result.damage = 0
	else:
		result.damage = maxi(floori(modified_damage), 1)
		if _status_service != null:
			result.damage = _status_service.modify_outgoing_damage(
				attacker,
				move,
				result.damage
			)
	return result

