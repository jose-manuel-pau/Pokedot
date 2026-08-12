class_name SeededExplorationRandomSource
extends ExplorationRandomSource

var _generator := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	_generator.seed = seed


func next_float() -> float:
	return _generator.randf()
