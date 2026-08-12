class_name FixedBattleRandomSource
extends BattleRandomSource
## Predictable random stream for battle tests. When exhausted, it returns the
## configured fallback rather than hiding an unexpected random call.

var values: Array[float] = []
var fallback: float = 0.5
var call_count: int = 0


func _init(sequence: Array[float] = [], fallback_value: float = 0.5) -> void:
	values.assign(sequence)
	fallback = fallback_value


func next_float() -> float:
	var value := fallback
	if call_count < values.size():
		value = values[call_count]
	call_count += 1
	return clampf(value, 0.0, 0.999999)

