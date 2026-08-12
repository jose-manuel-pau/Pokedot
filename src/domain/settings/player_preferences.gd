class_name PlayerPreferences
extends Resource
## Small, versioned set of presentation preferences safe to load before gameplay.

const SCHEMA_VERSION := 1

@export_range(0.8, 1.5, 0.05) var text_scale: float = 1.0
@export var high_contrast: bool = false
@export var reduced_motion: bool = false
@export var mute_audio: bool = false
@export_range(0.0, 1.0, 0.01) var master_volume: float = 0.8
@export_range(0.0, 1.0, 0.01) var effects_volume: float = 0.8


static func from_dictionary(data: Dictionary) -> PlayerPreferences:
	var preferences := PlayerPreferences.new()
	preferences.text_scale = float(data.get("text_scale", 1.0))
	preferences.high_contrast = bool(data.get("high_contrast", false))
	preferences.reduced_motion = bool(data.get("reduced_motion", false))
	preferences.mute_audio = bool(data.get("mute_audio", false))
	preferences.master_volume = float(data.get("master_volume", 0.8))
	preferences.effects_volume = float(data.get("effects_volume", 0.8))
	preferences.normalize()
	return preferences


func normalize() -> void:
	text_scale = clampf(text_scale, 0.8, 1.5)
	master_volume = clampf(master_volume, 0.0, 1.0)
	effects_volume = clampf(effects_volume, 0.0, 1.0)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"text_scale": text_scale,
		"high_contrast": high_contrast,
		"reduced_motion": reduced_motion,
		"mute_audio": mute_audio,
		"master_volume": master_volume,
		"effects_volume": effects_volume,
	}
