# Capture and Inventory

This module adds data-driven item definitions, capacity-safe inventory transactions, restorative battle items, deterministic wild-creature capture, and party/storage routing. Domain rules do not depend on scenes or UI.

## Item content and inventory

`data/items.json` contains stable item IDs and presentation data alongside mechanical fields. The initial catalog contains three capture devices, three healing items, two remedies, and one key item. `ContentValidator` verifies item categories, stack limits, prices, effect values, key-item invariants, and status references.

`Inventory` stores quantities only. `InventoryService` is the mutation boundary and returns an `InventoryTransactionResult` for every add or remove. Transactions reject unknown items, non-positive amounts, insufficient stock, full slot capacity, and stack overflow without partially modifying the bag.

Restorative effects are separated from stock ownership:

- `ItemEffectService` applies healing or removes configured statuses.
- `BattleParticipant.restore_hp()` synchronizes the battle projection and its `CreatureInstance`.
- `StatusEffectService.remove_status()` synchronizes persistent status state.
- `BattleManager` consumes a configured item only after a valid effect is accepted.

## Capture formula

Capture uses a single final probability:

```text
HP ratio          = current HP / maximum HP
Health multiplier = 1 + 2 × (1 - HP ratio)
Status multiplier = product of active status multipliers, capped at 2.5

Raw chance = (species catch rate / 255)
             × health multiplier
             × status multiplier
             × device multiplier
             × encounter multiplier

Final chance    = clamp(raw chance, 0.01, 0.95)
Critical chance = min(final chance × 0.15, 0.25)
```

Every valid attempt consumes exactly two injected random values: one success roll and one critical roll. A roll succeeds when it is lower than its probability. The critical flag is feedback for presentation and telemetry; it does not alter an already-computed success.

`CaptureResult` exposes the probability, rolls, and individual multipliers. This keeps balancing observable and deterministic without giving the capture service ownership of inventory, collection, or battle state.

## Battle commands and encounter rules

Trainer and wild encounters are explicit:

```gdscript
# Trainer or non-capturable encounter
battle.start_party_battle(player_party, opponent_party)
battle.assign_inventory(BattleConstants.SIDE_PLAYER, inventory)

# Capturable single wild creature
battle.start_wild_battle(player_party, wild_creature, inventory, collection)
```

New command priorities are ordered between switching and ordinary moves:

| Command | Priority |
| --- | ---: |
| Switch creature | 6 |
| Capture | 5 |
| Use item | 4 |
| Move | Definition priority |

`CaptureCommand` is player-only, requires a wild encounter and an owned capture device, and always consumes the device for a valid attempt. A failed capture lets the rest of the turn resolve. A successful capture emits `capture_attempted`, `creature_captured`, and `battle_finished`, then stops queued actions and end-turn status ticks. Its terminal outcome is `opponent_captured`.

`UseItemCommand` targets any member of the actor's battle party. It rejects missing stock, invalid targets, full-HP healing, defeated healing targets, remedies with no matching status, capture devices, and non-battle items before command submission. Successful use emits `item_used`; remedies additionally emit `status_removed` for presentation.

## Creature collection

`CreatureCollectionService` prevents duplicate instance IDs and routes captured creatures predictably:

1. Add to the party while it has fewer than six members.
2. Otherwise add to storage.

`CollectionAddResult.destination` reports `party` or `storage`, which is also included in the capture event so UI code can explain where the creature went.

## Extension points

- Add item effects through an effect strategy registry when categories grow beyond healing and remedies.
- Supply biome, species, story, or difficulty rules through the encounter multiplier.
- Add device-specific conditional rules before the final multiplier is passed to `CaptureService`.
- Persist `Inventory` and `CreatureCollection` through a future save repository without changing battle rules.
- Observe battle events to animate capsule shakes, healing, status removal, and collection routing.
