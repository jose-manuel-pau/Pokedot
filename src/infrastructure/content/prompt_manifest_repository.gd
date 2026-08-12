class_name PromptManifestRepository
extends RefCounted
## Atomic JSON writer for generated, reproducible content-pipeline artifacts.


func save(manifest: Dictionary, output_path: String) -> ContentExportResult:
	if output_path.strip_edges().is_empty() or not output_path.ends_with(".json"):
		return ContentExportResult.create(false, output_path, &"invalid_output_path")
	if (
		int(manifest.get("schema_version", -1)) != ContentPipelineService.MANIFEST_VERSION
		or not manifest.get("prompts", null) is Array
	):
		return ContentExportResult.create(false, output_path, &"invalid_prompt_manifest")
	var absolute_output := ProjectSettings.globalize_path(output_path)
	var absolute_directory := absolute_output.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return ContentExportResult.create(false, output_path, &"output_directory_unavailable")
	var temporary_path := output_path + ".tmp"
	var backup_path := output_path + ".bak"
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		return ContentExportResult.create(false, output_path, &"output_unwritable")
	temporary.store_string(JSON.stringify(manifest, "\t") + "\n")
	temporary.flush()
	temporary.close()
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	var had_previous := FileAccess.file_exists(output_path)
	if had_previous and DirAccess.rename_absolute(absolute_output, absolute_backup) != OK:
		DirAccess.remove_absolute(absolute_temporary)
		return ContentExportResult.create(false, output_path, &"backup_failed")
	if DirAccess.rename_absolute(absolute_temporary, absolute_output) != OK:
		if had_previous:
			DirAccess.rename_absolute(absolute_backup, absolute_output)
		return ContentExportResult.create(false, output_path, &"promotion_failed")
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
	return ContentExportResult.create(true, output_path)
