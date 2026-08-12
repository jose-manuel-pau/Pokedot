class_name SaveOperationResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var slot_id: StringName
var file_path: String
var validation_issues: Array[StringName] = []
