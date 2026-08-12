class_name BattleRandomSource
extends RefCounted
## Injectable random-number boundary. Tests provide a fixed sequence while
## production uses SeededBattleRandomSource.


func next_float() -> float:
	return 0.0


func next_int(max_exclusive: int) -> int:
	if max_exclusive <= 1:
		return 0
	return mini(floori(clampf(next_float(), 0.0, 0.999999) * max_exclusive), max_exclusive - 1)

