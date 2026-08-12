class_name GameLoadResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var state: PlayerGameState
var source_version: int = -1
var migrated: bool = false
var recovered_from_backup: bool = false
var validation_issues: Array[StringName] = []
