class_name BattleConstants
extends RefCounted
## Shared stable identifiers for the battle domain. StringName values keep event
## payloads readable and safe to serialize in future replays.

const SIDE_PLAYER: StringName = &"player"
const SIDE_OPPONENT: StringName = &"opponent"

const PHASE_NOT_STARTED: StringName = &"not_started"
const PHASE_AWAITING_COMMANDS: StringName = &"awaiting_commands"
const PHASE_RESOLVING_TURN: StringName = &"resolving_turn"
const PHASE_FINISHED: StringName = &"finished"

const OUTCOME_NONE: StringName = &"none"
const OUTCOME_PLAYER_VICTORY: StringName = &"player_victory"
const OUTCOME_OPPONENT_VICTORY: StringName = &"opponent_victory"
const OUTCOME_DRAW: StringName = &"draw"
const OUTCOME_OPPONENT_CAPTURED: StringName = &"opponent_captured"

const EVENT_BATTLE_STARTED: StringName = &"battle_started"
const EVENT_TURN_STARTED: StringName = &"turn_started"
const EVENT_COMMAND_SUBMITTED: StringName = &"command_submitted"
const EVENT_COMMAND_REJECTED: StringName = &"command_rejected"
const EVENT_COMMAND_SKIPPED: StringName = &"command_skipped"
const EVENT_MOVE_USED: StringName = &"move_used"
const EVENT_MOVE_MISSED: StringName = &"move_missed"
const EVENT_DAMAGE_DEALT: StringName = &"damage_dealt"
const EVENT_STATUS_MOVE_RESOLVED: StringName = &"status_move_resolved"
const EVENT_STATUS_APPLIED: StringName = &"status_applied"
const EVENT_STATUS_APPLICATION_FAILED: StringName = &"status_application_failed"
const EVENT_STATUS_BLOCKED_ACTION: StringName = &"status_blocked_action"
const EVENT_STATUS_DAMAGE: StringName = &"status_damage"
const EVENT_STATUS_REMOVED: StringName = &"status_removed"
const EVENT_ITEM_USED: StringName = &"item_used"
const EVENT_CAPTURE_ATTEMPTED: StringName = &"capture_attempted"
const EVENT_CREATURE_CAPTURED: StringName = &"creature_captured"
const EVENT_CREATURE_SWITCHED: StringName = &"creature_switched"
const EVENT_CREATURE_DEFEATED: StringName = &"creature_defeated"
const EVENT_TURN_ENDED: StringName = &"turn_ended"
const EVENT_BATTLE_FINISHED: StringName = &"battle_finished"


static func opposing_side(side: StringName) -> StringName:
	if side == SIDE_PLAYER:
		return SIDE_OPPONENT
	if side == SIDE_OPPONENT:
		return SIDE_PLAYER
	return &""


static func is_valid_side(side: StringName) -> bool:
	return side == SIDE_PLAYER or side == SIDE_OPPONENT

