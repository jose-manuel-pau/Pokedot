# Progression and Persistence

This module connects completed battles to permanent creature growth and adds validated, versioned save slots for the complete player aggregate. Progression, serialization, validation, migration, and filesystem concerns remain separate services.

## Experience rewards

Each species now declares an `experience_yield` in `data/species.json`.

```text
Wild reward    = floor(species XP yield × defeated level / 5)
Trainer reward = floor(species XP yield × defeated level × 1.25 / 5)
Minimum valid reward = 1 XP
```

`ExperienceRewardCalculator` is pure and does not mutate combatants. `BattleRewardService` builds the complete reward pool from every defeated opponent after a player victory.

Reward rules:

- Only a finished `player_victory` can grant XP.
- Captures, draws, unfinished battles, and losses grant no XP.
- Only player creatures that entered the battle share the pool.
- Initial active creatures and every manual or forced switch are recorded once.
- Integer division remainder goes to participants in entry order.
- A battle's rewards can be claimed only once.
- Wild battles use the base reward; trainer battles use the 1.25 multiplier.

The reward service returns `BattleProgressionResult`, including the reward pool, applied XP by instance ID, and each creature's detailed progression result.

## Level growth

`ProgressionService.grant_experience()` owns permanent mutation of a `CreatureInstance`:

1. Validate the creature, species, growth curve, and positive award.
2. Normalize legacy total XP to at least the current level threshold.
3. Clamp the award at the growth curve's maximum-level threshold.
4. Resolve any number of level gains using `ExperienceCalculator`.
5. Recalculate all six stats.
6. Preserve existing damage by adding only the maximum-HP increase to a conscious creature.
7. Keep a defeated creature at zero HP.
8. Resolve moves unlocked across every crossed level.

`ProgressionResult` exposes old/new level, XP before/after, applied award, old/new stats, HP gained, automatically learned moves, and pending move decisions.

## Move learning

Creatures retain a maximum of four active learned moves.

- A newly unlocked move fills an open slot automatically.
- A full moveset is never modified silently.
- Instead, the move ID appears in `pending_move_ids`.
- `resolve_move_learning()` accepts a learned move to replace or an empty replacement to decline.
- Unknown, unavailable, duplicate, and invalid replacement choices are rejected without mutation.

This two-stage contract lets a future UI animate a level-up first and then present one or more move decisions.

## Player save aggregate

`PlayerGameState` is the persistence aggregate root:

- Player ID and display name
- Total play time
- Current map, grid position, and facing
- Inventory slot limit and item quantities
- Party and storage collections
- Complete mutable state for every creature

Creature snapshots include identity, species, nickname, level, total XP, current HP, genetics, training, aptitude modifiers, learned moves, and persistent statuses.

`CreatureRosterService` moves creatures between party and storage and reorders the party transactionally. It enforces the six-member cap and prevents storing the final party member. Party index zero is the default lead for systems without an explicit selection; the explorer roster can temporarily select any owned instance for its next one-versus-one wild battle.

The formal JSON contract is `data/schemas/save_game.schema.json`.

## Load validation

`GameStateValidator` validates the complete reconstructed aggregate before it can replace live state. Checks include:

- Required player identity and non-negative play time
- Existing map, walkable position, and cardinal facing
- Inventory capacity, known items, and content-defined stack limits
- Party size, non-empty party, and unique creature instance IDs across party and storage
- Existing species and growth curves
- Level/total-XP consistency
- Current HP against recalculated maximum HP
- Genetic, training, and aptitude boundaries
- One to four unique moves available to the species at its saved level
- Existing, persistent, unique status conditions

Invalid files return stable issue codes and no `PlayerGameState`.

## Versioning and migration

Current saves use `schema_version: 1`. `SaveGameMigrator` is the only compatibility boundary:

- Version 1 is deep-copied and validated.
- Legacy version 0's flat profile, exploration, items, party, and storage fields are upgraded to version 1.
- Unknown future versions are rejected without partial loading.

Future migrations should be added as explicit, sequential transforms before deserialization.

## Save repository and recovery

`SaveGameRepository` stores named JSON slots under `user://saves` by default.

```gdscript
var repository := SaveGameRepository.new(catalog)
var saved := repository.save(&"slot_1", game_state)
var loaded := repository.load(&"slot_1")
var slots := repository.list_slot_ids()
```

Save flow:

1. Validate slot ID and complete state.
2. Serialize into a temporary file.
3. Flush and close the temporary file.
4. Move an existing slot to a backup.
5. Promote the temporary file to the active slot.
6. Restore the backup if promotion fails; otherwise remove it.

If an interrupted commit leaves only the backup, `load()` reads it and reports `recovered_from_backup`. Corrupt JSON, missing slots, invalid aggregates, and unsupported versions are returned as explicit failures.

Slot IDs permit lowercase letters, digits, and underscores only, preventing path traversal. Slot listing is sorted for deterministic menus and tests.

## Extension points

- Add participation weighting or held-item bonuses before the reward pool is split.
- Add evolution as another progression decision result rather than scene logic.
- Add training-point rewards through a separate mutation service.
- Add encrypted or compressed repositories behind the same save/load result contract.
- Add cloud sync above `SaveGameRepository`; local validation should remain authoritative.
- Add autosave orchestration in the production pass without changing serialization rules.
