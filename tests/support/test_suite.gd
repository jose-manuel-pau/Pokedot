class_name TestSuite
extends RefCounted
## Minimal dependency-free test support suitable for headless Godot runs.

var suite_name: String
var case_count: int = 0
var assertion_count: int = 0
var failures: Array[String] = []
var _current_case: String = "unscoped"


func _init(name: String) -> void:
	suite_name = name


func run() -> void:
	push_error("Test suite '%s' did not implement run()." % suite_name)


func begin_case(case_name: String) -> void:
	_current_case = case_name
	case_count += 1


func assert_true(value: bool, message: String = "Expected true") -> void:
	assertion_count += 1
	if not value:
		_fail(message)


func assert_false(value: bool, message: String = "Expected false") -> void:
	assertion_count += 1
	if value:
		_fail(message)


func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	assertion_count += 1
	if actual != expected:
		var detail := message if not message.is_empty() else "Expected %s, got %s" % [expected, actual]
		_fail(detail)


func assert_float_equal(
	actual: float,
	expected: float,
	tolerance: float = 0.0001,
	message: String = ""
) -> void:
	assertion_count += 1
	if not is_equal_approx(actual, expected) and absf(actual - expected) > tolerance:
		var detail := message if not message.is_empty() else "Expected %.4f, got %.4f" % [expected, actual]
		_fail(detail)


func assert_not_null(value: Variant, message: String = "Expected a value") -> void:
	assertion_count += 1
	if value == null:
		_fail(message)


func assert_has_issue(issues: Array[ValidationIssue], code: StringName) -> void:
	assertion_count += 1
	for issue in issues:
		if issue.code == code:
			return
	_fail("Expected validation issue '%s'." % code)


func _fail(message: String) -> void:
	failures.append("%s :: %s :: %s" % [suite_name, _current_case, message])

