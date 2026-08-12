extends SceneTree
## Usage: godot --headless --path . --script res://tools/export_content_pipeline.gd -- --output=user://prompts.json

const DEFAULT_OUTPUT := "res://builds/content/creature_sprite_prompts.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := JsonContentRepository.new().load_catalog("res://data")
	if load_result.has_errors():
		_print_issues(load_result.issues)
		quit(1)
		return
	var pipeline_result := ContentPipelineService.new(load_result.catalog).compile()
	if pipeline_result.has_errors():
		_print_issues(pipeline_result.issues)
		quit(1)
		return
	var output_path := _read_output_path()
	var export_result := PromptManifestRepository.new().save(
		pipeline_result.manifest,
		output_path
	)
	if not export_result.success:
		push_error("Prompt export failed: %s" % export_result.reason)
		quit(1)
		return
	print("Exported %d creature prompt packages to %s" % [
		pipeline_result.packages.size(), output_path
	])
	quit(0)


func _read_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return DEFAULT_OUTPUT


func _print_issues(issues: Array[ValidationIssue]) -> void:
	for issue in issues:
		push_error(issue.format())
