class_name ValidationIssue
extends RefCounted

enum Severity { WARNING, ERROR }

var severity: Severity
var code: StringName
var path: String
var message: String


static func create(
	issue_severity: Severity,
	issue_code: StringName,
	issue_path: String,
	issue_message: String
) -> ValidationIssue:
	var issue := ValidationIssue.new()
	issue.severity = issue_severity
	issue.code = issue_code
	issue.path = issue_path
	issue.message = issue_message
	return issue


func format() -> String:
	var label := "ERROR" if severity == Severity.ERROR else "WARNING"
	return "[%s][%s] %s: %s" % [label, code, path, message]

