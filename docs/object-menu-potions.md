# Object Menu and Persistent HP

Press **B** during active exploration to open the object menu. Field movement pauses while it is visible. The first owned object types are always presented in this order:

| Object | HP restored | Initial quantity |
| --- | ---: | ---: |
| Potion | 20 | 5 |
| Mega Potion | 50 | 3 |
| Ultra Potion | 100 | 1 |
| Elixir | Revives with 50% maximum HP | 2 |

These four restorative objects stay first. Other owned objects follow alphabetically. Their category and quantity remain visible, but only healing and revival objects can be used from this menu.

## Use an object

1. Choose a Potion tier or Elixir from the bag list.
2. Choose any creature in the party or storage.
3. Select **Use** to apply the restorative. Up/Down moves through object cards, creature cards, **Use**, and **Close**; disabled actions are skipped.

The target list and detail bar show current and maximum HP. Healing stops at maximum HP, so an Ultra Potion applied to a creature missing 12 HP restores only 12. Potions work only on damaged conscious creatures. Elixir works only at zero HP and revives that creature with half of its maximum HP, rounded up. Objects are never consumed when the target or action is invalid.

The battle **I** action uses the same Potion stack. Field and battle screens therefore observe one inventory source of truth.

## Persistent post-battle HP

Battle damage is synchronized directly to each persistent `CreatureInstance`. Returning to Mosslight Crossing after victory, capture, retreat, or defeat no longer restores the collection automatically. The roster and object menu immediately show the remaining HP.

A creature at zero HP remains fainted until an Elixir is used from the **B** menu. A successful revival immediately makes that creature eligible for selection with **P** and for the next wild encounter.

## Architecture

- `ItemDefinition` contains data-defined healing and revival categories, potency, and display text.
- `InventoryService` owns stock mutation and stack constraints.
- `ItemEffectService` remains the shared healing/revival implementation used by battles and the field.
- `FieldItemUseService` validates the owned object and target, consumes one unit, applies restoration, and restores the stock if a future effect fails after consumption.
- `ObjectMenu` manages item/target selection, an explicit focus graph, and presentation-level success feedback.
- `ExplorationScreen` owns menu availability and no longer applies automatic post-battle healing.

Automated coverage verifies all three Potion potencies, Elixir's 50% revival, conscious/fainted restrictions, maximum-HP caps, failure atomicity, object ordering, captured-creature targeting, Up/Down action access, disabled-action skipping, input guards, exact battle-damage persistence, inventory consumption, and map feedback.
