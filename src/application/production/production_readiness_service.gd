class_name ProductionReadinessService
extends RefCounted
## One release gate covering content balance, generated prompts, branding,
## project startup, preferences, and desktop export configuration.


func inspect(catalog: ContentCatalog) -> BalanceReport:
	var report := BalanceAnalyzer.new().analyze(catalog)
	if catalog == null:
		return report
	_check_project_configuration(report)
	_check_export_preset(report)
	_check_content_pipeline(catalog, report)
	_check_preferences(report)
	report.metrics["production_ready"] = not report.has_errors()
	return report


func _check_project_configuration(report: BalanceReport) -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var icon_path := str(ProjectSettings.get_setting("application/config/icon", ""))
	report.metrics["main_scene"] = main_scene
	report.metrics["icon_path"] = icon_path
	if main_scene.is_empty() or not ResourceLoader.exists(main_scene):
		_add_error(report, &"missing_main_scene", "project.application.run", "Configured main scene does not exist.")
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		_add_error(report, &"missing_application_icon", "project.application.config.icon", "Configured application icon does not exist.")
	if str(ProjectSettings.get_setting("application/config/version", "")).is_empty():
		_add_error(report, &"missing_application_version", "project.application.config.version", "A production version is required.")
	var launcher_path := "res://play_pokedot.cmd"
	report.metrics["playtest_launcher"] = launcher_path
	if not FileAccess.file_exists(launcher_path):
		_add_error(report, &"missing_playtest_launcher", launcher_path, "A one-click local playtest launcher is required.")


func _check_export_preset(report: BalanceReport) -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		_add_error(report, &"missing_export_preset", "export_presets.cfg", "Desktop export configuration could not be loaded.")
		return
	var preset_name := str(config.get_value("preset.0", "name", ""))
	var platform := str(config.get_value("preset.0", "platform", ""))
	var export_path := str(config.get_value("preset.0", "export_path", ""))
	report.metrics["export_preset"] = preset_name
	report.metrics["export_platform"] = platform
	report.metrics["export_path"] = export_path
	if preset_name != "Windows Desktop" or platform != "Windows Desktop":
		_add_error(report, &"invalid_export_preset", "export_presets.cfg.preset.0", "Expected a runnable Windows Desktop preset.")
	if not export_path.ends_with(".exe"):
		_add_error(report, &"invalid_export_path", "export_presets.cfg.preset.0.export_path", "Windows export must target an .exe file.")


func _check_content_pipeline(catalog: ContentCatalog, report: BalanceReport) -> void:
	var pipeline := ContentPipelineService.new(catalog).compile()
	if pipeline.has_errors():
		for issue in pipeline.issues:
			if issue.severity == ValidationIssue.Severity.ERROR:
				report.issues.append(issue)
		return
	report.metrics["sprite_prompt_count"] = pipeline.packages.size()
	if pipeline.packages.size() != catalog.species_by_id.size():
		_add_error(report, &"incomplete_sprite_prompts", "content_pipeline", "Every species needs one compiled sprite prompt package.")


func _check_preferences(report: BalanceReport) -> void:
	var defaults := PlayerPreferences.new()
	var data := defaults.to_dictionary()
	report.metrics["preferences_schema_version"] = int(data.get("schema_version", -1))
	if int(data.get("schema_version", -1)) != PlayerPreferences.SCHEMA_VERSION:
		_add_error(report, &"invalid_preferences_schema", "player_preferences", "Default preferences must serialize at the current version.")


func _add_error(
	report: BalanceReport,
	code: StringName,
	path: String,
	message: String
) -> void:
	report.issues.append(ValidationIssue.create(
		ValidationIssue.Severity.ERROR,
		code,
		path,
		message
	))
