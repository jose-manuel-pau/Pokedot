class_name StatusTickResult
extends RefCounted

var status_id: StringName
var damage: int = 0
var removed: bool = false


static func create(id: StringName) -> StatusTickResult:
	var result := StatusTickResult.new()
	result.status_id = id
	return result

