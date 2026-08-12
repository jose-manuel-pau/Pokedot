extends SceneTree
## Usage: godot --headless --path . --script res://tools/verify_release.gd

const OUTPUT_PATH := "res://builds/reports/production_readiness.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := JsonContentRepository.new().load_catalog("res://data")
	if load_result.has_errors():
		for issue in load_result.issues:
			push_error(issue.format())
		quit(1)
		return
	var report := ProductionReadinessService.new().inspect(load_result.catalog)
	for issue in report.issues:
		print(issue.format())
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write production readiness report.")
		quit(1)
		return
	file.store_string(JSON.stringify(report.to_dictionary(), "  ") + "\n")
	file.close()
	print("Production readiness: %s, %d errors, %d warnings -> %s" % [
		"PASS" if not report.has_errors() else "FAIL",
		report.error_count(),
		report.warning_count(),
		OUTPUT_PATH,
	])
	quit(1 if report.has_errors() else 0)
