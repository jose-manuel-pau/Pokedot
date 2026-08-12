# One-versus-One Combat Vertical Slice

This module supplies a deterministic, UI-independent one-versus-one combat loop. It uses the Creature Data & Stats content catalog but has no dependency on scenes, animation, audio, input devices, or enemy AI.

## State machine

```text
not_started
    │ start_battle(player, opponent)
    ▼
awaiting_commands ◄──────────────────────┐
    │ one valid command from each side   │
    ▼                                    │
resolving_turn                           │
    │ priority → Speed → seeded tie      │
    │ accuracy → damage → defeat         │
    ├────────────────────────────────────┘ next turn
    ▼
finished
```

`BattleManager` is the state-machine coordinator. Its collaborators each own one concern:

- `BattleParticipant` projects a `CreatureInstance` into mutable battle state.
- `BattleCommand` represents an actor's intent. The first concrete command is `UseMoveCommand`.
- `TurnOrderResolver` applies priority, Speed, and seeded tie-breaking.
- `DamageCalculator` performs accuracy, critical, variance, STAB, and type calculations.
- `BattleRandomSource` isolates randomness so a battle can be replayed exactly.
- `BattleEvent` is the output boundary for presentation and logging.

## Turn priority

Commands are ordered by:

1. Move priority, descending.
2. Effective Speed, descending.
3. Seeded random tie-break for equal priority and Speed.

Random values are assigned after deterministic sorting rather than from inside the sort comparator. This prevents an unstable comparator from producing platform-dependent order.

## Move resolution

For a damaging move:

```text
hit when accuracy_roll < move_accuracy

base_damage = ((2 × level + 10) / 250)
              × (attack_stat / defense_stat)
              × move_power
              + 2

damage = floor(
    base_damage
    × same_type_bonus
    × type_effectiveness
    × critical_modifier
    × random_variance
)
```

Current constants:

- Same-type bonus: `1.25`
- Critical chance: `6.25%`
- Critical multiplier: `1.5`
- Variance: `0.90` through `1.00`
- Minimum non-immune damaging hit: `1`

Physical moves use Attack and Defense. Special moves use Special Attack and Special Defense. An effectiveness multiplier of zero deals no damage.

## Command lifecycle

```gdscript
var catalog := JsonContentRepository.new().load_catalog("res://data").catalog
var battle := BattleManager.new(catalog, SeededBattleRandomSource.new(4401))

battle.event_emitted.connect(_on_battle_event)
battle.phase_changed.connect(_on_battle_phase_changed)

battle.start_battle(player_creature, opponent_creature)
battle.submit_command(UseMoveCommand.new(&"player", &"cinder_jab"))
battle.submit_command(UseMoveCommand.new(&"opponent", &"brook_bash"))
battle.resolve_turn()
```

Commands are validated when submitted. Unknown sides, unknown or unlearned moves, duplicate submissions, and depleted move uses are rejected without changing the pending command set.

## Event contract

Every event is appended to `event_history` and published through `event_emitted`. Relevant event types include:

- Battle and turn started
- Command submitted, rejected, or skipped
- Move used or missed
- Damage dealt
- Status move resolved
- Creature defeated
- Turn ended
- Battle finished

Payloads contain stable IDs and primitive values suitable for animation queues and replay logs. Presentation code should react to events and never recalculate combat results.

## Scope boundary

This slice supports physical, special, and status-category move selection. Status moves currently resolve accuracy, consume a use, and publish `status_move_resolved`; applying persistent or volatile effects belongs to the next Statuses and Battle AI module.

Party switching is now implemented by `SwitchCreatureCommand` in the Statuses and Battle AI module. Items, capture, and running will become additional `BattleCommand` implementations in their respective modules. Their addition does not require changing `TurnOrderResolver`.

