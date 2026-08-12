class_name SaveGameRepository
extends RefCounted
## JSON slot repository with validation, migration, temporary writes, backup
## recovery, and deterministic slot listing.

const SAVE_EXTENSION := ".json"

var _catalog: ContentCatalog
var _base_path: String
var _serializer := GameStateSerializer.new()
var _migrator := SaveGameMigrator.new()
var _validator: GameStateValidator


func _init(
	catalog: ContentCatalog,
	base_path: String = "user://saves"
) -> void:
	_catalog = catalog
	_base_path = base_path
	_validator = GameStateValidator.new(_catalog)


func save(slot_id: StringName, state: PlayerGameState) -> SaveOperationResult:
	var result := SaveOperationResult.new()
	result.slot_id = slot_id
	if not _is_valid_slot_id(slot_id):
		result.reason = &"invalid_save_slot_id"
		return result
	result.validation_issues = _validator.validate(state)
	if not result.validation_issues.is_empty():
		result.reason = &"invalid_game_state"
		return result
	if not _ensure_base_directory():
		result.reason = &"save_directory_unavailable"
		return result
	var final_path := _slot_path(slot_id)
	var temporary_path := final_path + ".tmp"
	var backup_path := final_path + ".bak"
	result.file_path = final_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		result.reason = &"save_file_unwritable"
		return result
	file.store_string(JSON.stringify(_serializer.to_dictionary(state), "  "))
	file.flush()
	file.close()
	if not _commit_file(temporary_path, final_path, backup_path):
		result.reason = &"save_commit_failed"
		return result
	result.success = true
	return result


func load(slot_id: StringName) -> GameLoadResult:
	var result := GameLoadResult.new()
	if not _is_valid_slot_id(slot_id):
		result.reason = &"invalid_save_slot_id"
		return result
	var final_path := _slot_path(slot_id)
	var backup_path := final_path + ".bak"
	var load_path := final_path
	if not FileAccess.file_exists(load_path):
		if not FileAccess.file_exists(backup_path):
			result.reason = &"save_slot_not_found"
			return result
		load_path = backup_path
		result.recovered_from_backup = true
	var file := FileAccess.open(load_path, FileAccess.READ)
	if file == null:
		result.reason = &"save_file_unreadable"
		return result
	var parser := JSON.new()
	var contents := file.get_as_text()
	file.close()
	if parser.parse(contents) != OK:
		result.reason = &"invalid_save_json"
		return result
	var migration := _migrator.migrate(parser.data)
	result.source_version = migration.source_version
	result.migrated = migration.migrated
	if not migration.success:
		result.reason = migration.reason
		return result
	var state := _serializer.from_dictionary(migration.data)
	result.validation_issues = _validator.validate(state)
	if not result.validation_issues.is_empty():
		result.reason = &"invalid_game_state"
		return result
	result.success = true
	result.state = state
	return result


func list_slot_ids() -> Array[StringName]:
	var slots: Array[StringName] = []
	var directory := DirAccess.open(_base_path)
	if directory == null:
		return slots
	for file_name in directory.get_files():
		if file_name.ends_with(SAVE_EXTENSION):
			slots.append(StringName(file_name.trim_suffix(SAVE_EXTENSION)))
	slots.sort_custom(func(left: StringName, right: StringName) -> bool:
		return str(left) < str(right)
	)
	return slots


func _commit_file(
	temporary_path: String,
	final_path: String,
	backup_path: String
) -> bool:
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


func _ensure_base_directory() -> bool:
	var global_path := ProjectSettings.globalize_path(_base_path)
	return DirAccess.dir_exists_absolute(global_path) \
		or DirAccess.make_dir_recursive_absolute(global_path) == OK


func _slot_path(slot_id: StringName) -> String:
	return _base_path.path_join(str(slot_id) + SAVE_EXTENSION)


func _is_valid_slot_id(slot_id: StringName) -> bool:
	var value := str(slot_id)
	if value.is_empty():
		return false
	for index in value.length():
		var character := value.substr(index, 1)
		var is_letter := character >= "a" and character <= "z"
		var is_digit := character >= "0" and character <= "9"
		if not is_letter and not is_digit and character != "_":
			return false
	return true
