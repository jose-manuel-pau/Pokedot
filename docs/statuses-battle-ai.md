# Statuses, Party Switching, and Battle AI

This module extends deterministic combat with composable status hooks, parties of up to six creatures, manual and forced switching, and an opponent decision policy. All rules remain independent from scenes and UI.

## Composable status architecture

A runtime `BattleStatusInstance` stores only individual state:

- Stable status ID
- Remaining duration
- Application turn
- Stack count

`StatusConditionDefinition` remains immutable content. Its tags select small `StatusTagBehavior` strategies through `StatusBehaviorRegistry`:

| Tag | Hook behavior |
| --- | --- |
| `action_denial` | Prevents a queued move from executing |
| `movement_lock` | Prevents voluntary switching |
| `speed_reduction` | Multiplies effective Speed by `0.5` |
| `damage_over_time` | Deals `1/8` maximum HP at end of turn |
| `heat` | Multiplies outgoing physical damage by `0.75` |

One status may contribute several tags. One tag behavior can be reused by several statuses. Adding a mechanic requires a new strategy and registry entry rather than another condition in `BattleManager`.

## Initial status rules

| Status | Category | Duration | Effects |
| --- | --- | --- | --- |
| Scorched | Persistent | Indefinite | `1/8` max-HP end-turn damage and 25% physical damage penalty |
| Drowsy | Persistent | 4 end-turn cycles | Cannot execute moves |
| Rooted | Volatile | 3 end-turn cycles | Half Speed and cannot switch voluntarily |

Persistent status IDs synchronize to `CreatureInstance.persistent_status_ids` and survive switching. Volatile statuses are removed when a creature leaves the active position. Finite durations decrease exactly once per end-turn cycle.

Status-category moves and damaging moves use the same application pipeline. A damaging move rolls its secondary status chance only after a successful, non-knockout hit. A 100% chance does not consume an unnecessary random value.

## Status turn hooks

```text
Build action queue
    │ status-modified Speed
    ▼
Before action
    │ action-denial hooks
    ▼
Damage calculation
    │ outgoing-damage hooks
    ▼
Status application
    │ chance and duplicate/stack rules
    ▼
End of turn
    │ damage-over-time hooks
    │ duration decrement and expiry
    ▼
Forced switch or outcome evaluation
```

Every observable result produces a domain event: application, failed application, blocked action, end-turn damage, removal, defeat, and switch.

## Parties and switching

`BattleParty` owns an ordered list of `BattleParticipant` objects and one active index. The existing `start_battle()` remains the one-versus-one convenience API; party encounters use:

```gdscript
battle.start_party_battle(player_creatures, opponent_creatures)
```

Party rules:

- One to six members per side
- Stable and unique instance IDs within a party
- Only living creatures with usable move definitions may be active
- Voluntary switches use `SwitchCreatureCommand` at priority `6`
- A switch therefore resolves before the current move priority range
- Attacks after a switch target the incoming creature
- Defeated active creatures automatically select the first healthy bench member
- Victory occurs only when a party has no usable member

Switch commands reject empty, unknown, already-active, defeated, and status-blocked targets without modifying pending commands.

## Deterministic battle AI

`BattleAiController` returns a command and never mutates the battle directly. `BattleManager.submit_ai_command()` is the optional integration helper.

The policy evaluates:

- Move accuracy
- Power and physical/special stat ratio
- Same-type bonus
- Type effectiveness
- Move priority
- Status utility and whether the target already has that status
- Remaining move uses
- Current HP and available bench members
- Incoming defensive matchups for switch candidates

At or below 25% HP, the AI considers switching and chooses the strongest defensive/offensive bench candidate. Movement-lock statuses prevent this choice. Exact score ties use an injected `BattleRandomSource`, making identical seeds and battle states produce identical decisions.

The AI returns `null` when the battle is not accepting commands or no legal move/switch exists. Command validation remains authoritative in `BattleManager`.

## Extension points

- Add status mechanics by subclassing `StatusTagBehavior` and registering a tag.
- Add AI personalities by implementing another controller that returns `BattleCommand` objects.
- Add items, capture, and run behavior as new command subclasses.
- Add switch animations by observing `creature_switched`; presentation code should not change active-party state itself.

