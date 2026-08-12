class_name ContentLoadResult
extends RefCounted

var catalog: ContentCatalog = ContentCatalog.new()
var issues: Array[ValidationIssue] = []


func add_issue(issue: ValidationIssue) -> void:
	issues.append(issue)


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

