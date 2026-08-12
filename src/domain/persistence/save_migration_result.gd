class_name SaveMigrationResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var source_version: int = -1
var migrated: bool = false
var data: Dictionary = {}
