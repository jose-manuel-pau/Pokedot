class_name SeededBattleRandomSource
extends BattleRandomSource
## Reproducible RNG used for battle replays, debugging, and deterministic saves.

var seed_value: int
var _generator := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	seed_value = seed
	_generator.seed = seed


func next_float() -> float:
	return _generator.randf()

