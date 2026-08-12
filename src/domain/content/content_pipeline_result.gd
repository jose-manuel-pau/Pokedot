class_name ContentPipelineResult
extends RefCounted
## Compilation result containing deterministic prompt packages or diagnostics.

var packages: Array[CreaturePromptPackage] = []
var issues: Array[ValidationIssue] = []
var manifest: Dictionary = {}


func has_errors() -> bool:
	for issue in issues:
		if issue.severity == ValidationIssue.Severity.ERROR:
			return true
	return false
