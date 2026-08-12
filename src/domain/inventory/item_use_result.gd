class_name ItemUseResult
extends RefCounted
## Describes an item effect without owning inventory consumption.

var success: bool = false
var reason: StringName = &""
var healing_applied: int = 0
var removed_status_ids: Array[StringName] = []


static func rejected(error: StringName) -> ItemUseResult:
	var result := ItemUseResult.new()
	result.reason = error
	return result

static func accepted() -> ItemUseResult:
	var result := ItemUseResult.new()
	result.success = true
	return result
