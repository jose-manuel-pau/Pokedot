class_name BalanceReport
extends RefCounted
## Deterministic metrics and actionable diagnostics from one catalog audit.

var metrics: Dictionary = {}
var issues: Array[ValidationIssue] = []


func has_errors() -> bool:
	return error_count() > 0


func error_count() -> int:
	var count := 0
	for issue in issues:
		if issue.severity == ValidationIssue.Severity.ERROR:
			count += 1
	return count


func warning_count() -> int:
	return issues.size() - error_count()


func to_dictionary() -> Dictionary:
	var issue_data: Array[Dictionary] = []
	for issue in issues:
		issue_data.append({
			"severity": "error" if issue.severity == ValidationIssue.Severity.ERROR else "warning",
			"code": str(issue.code),
			"path": issue.path,
			"message": issue.message,
		})
	return {
		"schema_version": 1,
		"metrics": metrics.duplicate(true),
		"error_count": error_count(),
		"warning_count": warning_count(),
		"issues": issue_data,
	}
