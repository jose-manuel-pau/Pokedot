class_name CaptureCommand
extends BattleCommand
## Attempts to capture the active creature in a wild encounter.

const CAPTURE_PRIORITY := 5

var device_item_id: StringName


func _init(side: StringName = &"", selected_device_id: StringName = &"") -> void:
	super(side)
	device_item_id = selected_device_id


func get_kind() -> StringName:
	return &"capture"


func get_priority(_catalog: ContentCatalog) -> int:
	return CAPTURE_PRIORITY


func validate(
	_participant: BattleParticipant,
	catalog: ContentCatalog
) -> StringName:
	var device := catalog.get_item(device_item_id)
	if device == null:
		return &"unknown_item"
	if not device.is_capture_device():
		return &"invalid_capture_device"
	return &""
