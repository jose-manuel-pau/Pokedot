class_name PreferencesLoadResult
extends RefCounted

var success: bool = false
var used_defaults: bool = false
var reason: StringName
var preferences: PlayerPreferences = PlayerPreferences.new()
