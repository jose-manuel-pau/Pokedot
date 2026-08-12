class_name CreatureStats
extends Resource
## A six-stat value object used for base stats, genetic potential, training, and
## calculated combat stats. Validation rules depend on the context in which the
## object is used.

const STAT_IDS: Array[StringName] = [
	&"hp",
	&"attack",
	&"defense",
	&"special_attack",
	&"special_defense",
	&"speed",
]

@export var hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var special_attack: int = 0
@export var special_defense: int = 0
@export var speed: int = 0


static func from_dictionary(data: Dictionary) -> CreatureStats:
	var stats := CreatureStats.new()
	stats.hp = int(data.get("hp", 0))
	stats.attack = int(data.get("attack", 0))
	stats.defense = int(data.get("defense", 0))
	stats.special_attack = int(data.get("special_attack", 0))
	stats.special_defense = int(data.get("special_defense", 0))
	stats.speed = int(data.get("speed", 0))
	return stats


func get_value(stat_id: StringName) -> int:
	match stat_id:
		&"hp":
			return hp
		&"attack":
			return attack
		&"defense":
			return defense
		&"special_attack":
			return special_attack
		&"special_defense":
			return special_defense
		&"speed":
			return speed
		_:
			push_error("Unknown creature stat: %s" % stat_id)
			return 0


func set_value(stat_id: StringName, value: int) -> void:
	match stat_id:
		&"hp":
			hp = value
		&"attack":
			attack = value
		&"defense":
			defense = value
		&"special_attack":
			special_attack = value
		&"special_defense":
			special_defense = value
		&"speed":
			speed = value
		_:
			push_error("Unknown creature stat: %s" % stat_id)


func sum() -> int:
	return hp + attack + defense + special_attack + special_defense + speed


func to_dictionary() -> Dictionary:
	return {
		"hp": hp,
		"attack": attack,
		"defense": defense,
		"special_attack": special_attack,
		"special_defense": special_defense,
		"speed": speed,
	}

