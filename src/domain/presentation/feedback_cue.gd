class_name FeedbackCue
extends RefCounted
## Presentation-only response description derived from a domain event.

var cue_id: StringName
var color: Color = Color.WHITE
var visual_duration: float = 0.12
var frequency_hz: float = 440.0
var audio_duration: float = 0.06


static func create(
	id: StringName,
	visual_color: Color,
	visual_seconds: float,
	frequency: float,
	audio_seconds: float
) -> FeedbackCue:
	var cue := FeedbackCue.new()
	cue.cue_id = id
	cue.color = visual_color
	cue.visual_duration = visual_seconds
	cue.frequency_hz = frequency
	cue.audio_duration = audio_seconds
	return cue
