class_name PlayerPreferencesService
extends RefCounted
## Mutation boundary for keyboard-accessible settings and observer updates.

signal preferences_changed(preferences: PlayerPreferences)

const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]

var preferences: PlayerPreferences


func _init(initial_preferences: PlayerPreferences = null) -> void:
	preferences = initial_preferences if initial_preferences != null else PlayerPreferences.new()
	preferences.normalize()


func toggle_high_contrast() -> void:
	preferences.high_contrast = not preferences.high_contrast
	preferences_changed.emit(preferences)


func toggle_reduced_motion() -> void:
	preferences.reduced_motion = not preferences.reduced_motion
	preferences_changed.emit(preferences)


func toggle_mute() -> void:
	preferences.mute_audio = not preferences.mute_audio
	preferences_changed.emit(preferences)


func cycle_text_scale() -> void:
	var next_index := 0
	for index in TEXT_SCALES.size():
		if is_equal_approx(preferences.text_scale, TEXT_SCALES[index]):
			next_index = (index + 1) % TEXT_SCALES.size()
			break
	preferences.text_scale = TEXT_SCALES[next_index]
	preferences_changed.emit(preferences)


func set_volumes(master: float, effects: float) -> void:
	preferences.master_volume = clampf(master, 0.0, 1.0)
	preferences.effects_volume = clampf(effects, 0.0, 1.0)
	preferences_changed.emit(preferences)
