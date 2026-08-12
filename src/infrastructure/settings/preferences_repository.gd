class_name PreferencesRepository
extends RefCounted
## Resilient JSON preferences. Invalid or future data falls back to safe defaults.

var _file_path: String


func _init(file_path: String = "user://settings/player_preferences.json") -> void:
	_file_path = file_path


func load() -> PreferencesLoadResult:
	var result := PreferencesLoadResult.new()
	if not FileAccess.file_exists(_file_path):
		return _defaults(result, &"settings_not_found")
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		return _defaults(result, &"settings_unreadable")
	var contents := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return _defaults(result, &"invalid_settings_json")
	var data := parser.data as Dictionary
	if int(data.get("schema_version", -1)) != PlayerPreferences.SCHEMA_VERSION:
		return _defaults(result, &"unsupported_settings_version")
	result.success = true
	result.preferences = PlayerPreferences.from_dictionary(data)
	return result


func save(preferences: PlayerPreferences) -> PreferencesSaveResult:
	var result := PreferencesSaveResult.new()
	result.file_path = _file_path
	if preferences == null:
		result.reason = &"missing_preferences"
		return result
	preferences.normalize()
	var absolute_path := ProjectSettings.globalize_path(_file_path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		result.reason = &"settings_directory_unavailable"
		return result
	var temporary_path := _file_path + ".tmp"
	var backup_path := _file_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		result.reason = &"settings_unwritable"
		return result
	file.store_string(JSON.stringify(preferences.to_dictionary(), "  ") + "\n")
	file.flush()
	file.close()
	if not _commit(temporary_path, _file_path, backup_path):
		result.reason = &"settings_commit_failed"
		return result
	result.success = true
	return result


func _defaults(result: PreferencesLoadResult, reason: StringName) -> PreferencesLoadResult:
	result.success = true
	result.used_defaults = true
	result.reason = reason
	result.preferences = PlayerPreferences.new()
	return result


func _commit(temporary_path: String, final_path: String, backup_path: String) -> bool:
	var temporary := ProjectSettings.globalize_path(temporary_path)
	var final := ProjectSettings.globalize_path(final_path)
	var backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup)
	var had_previous := FileAccess.file_exists(final_path)
	if had_previous and DirAccess.rename_absolute(final, backup) != OK:
		return false
	if DirAccess.rename_absolute(temporary, final) != OK:
		if had_previous:
			DirAccess.rename_absolute(backup, final)
		return false
	if had_previous:
		DirAccess.remove_absolute(backup)
	return true
