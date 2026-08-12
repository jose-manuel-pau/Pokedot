class_name ExplorationFeedbackRouter
extends RefCounted
## Maps observer events to semantic feedback; rendering and playback stay optional.


func route(event: ExplorationEvent) -> FeedbackCue:
	if event == null:
		return null
	match event.event_type:
		ExplorationConstants.EVENT_MAP_STARTED:
			return FeedbackCue.create(&"map_ready", Color("6fd8c8"), 0.28, 523.25, 0.10)
		ExplorationConstants.EVENT_MOVEMENT_RESOLVED:
			if bool(event.payload.get("moved", false)):
				return FeedbackCue.create(&"step", Color("8fd17f"), 0.08, 261.63, 0.025)
			return FeedbackCue.create(&"blocked", Color("ef7d6d"), 0.18, 146.83, 0.07)
		ExplorationConstants.EVENT_NPC_INTERACTED:
			return FeedbackCue.create(&"interaction", Color("f4cf65"), 0.20, 392.0, 0.08)
		ExplorationConstants.EVENT_WILD_ENCOUNTER:
			return FeedbackCue.create(&"encounter", Color("f19b5b"), 0.45, 659.25, 0.16)
		ExplorationConstants.EVENT_EXPLORATION_RESUMED:
			return FeedbackCue.create(&"resume", Color("75b9e6"), 0.24, 329.63, 0.08)
		_:
			return null
