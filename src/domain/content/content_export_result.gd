class_name ContentExportResult
extends RefCounted

var success: bool = false
var output_path: String
var reason: StringName


static func create(
	did_succeed: bool,
	path: String,
	failure_reason: StringName = &""
) -> ContentExportResult:
	var result := ContentExportResult.new()
	result.success = did_succeed
	result.output_path = path
	result.reason = failure_reason
	return result
