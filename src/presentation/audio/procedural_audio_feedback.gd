class_name ProceduralAudioFeedback
extends AudioStreamPlayer
## Tiny synthesized UI cues avoid licensed assets and remain export-safe.

const MIX_RATE := 22050.0


func play_cue(cue: FeedbackCue, preferences: PlayerPreferences) -> bool:
	if cue == null or preferences == null:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	if preferences.mute_audio or preferences.master_volume <= 0.0 or preferences.effects_volume <= 0.0:
		return false
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = maxf(cue.audio_duration + 0.04, 0.1)
	stream = generator
	volume_db = linear_to_db(preferences.master_volume * preferences.effects_volume)
	play()
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return false
	var requested_frames := int(ceil(cue.audio_duration * MIX_RATE))
	var frame_count := mini(requested_frames, playback.get_frames_available())
	for frame in frame_count:
		var time := float(frame) / MIX_RATE
		var progress := float(frame) / float(maxi(frame_count - 1, 1))
		var envelope := sin(PI * progress) * 0.22
		var sample := sin(TAU * cue.frequency_hz * time) * envelope
		playback.push_frame(Vector2(sample, sample))
	return frame_count > 0
