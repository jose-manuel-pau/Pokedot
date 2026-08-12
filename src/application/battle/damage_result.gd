class_name DamageResult
extends RefCounted
## Complete deterministic result of resolving one move against one defender.

var hit: bool = false
var damage: int = 0
var critical: bool = false
var type_multiplier: float = 1.0
var same_type_bonus: float = 1.0
var variance: float = 1.0
var accuracy_roll: float = 0.0

