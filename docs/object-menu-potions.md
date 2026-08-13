# Object Menu and Persistent HP

Press **B** during active exploration to open the object menu. Field movement pauses while it is visible. The first owned object types are always presented in this order:

| Object | HP restored | Initial quantity |
| --- | ---: | ---: |
| Potion | 20 | 5 |
| Mega Potion | 50 | 3 |
| Ultra Potion | 100 | 1 |

Other owned objects follow alphabetically. Their category and quantity remain visible, but only healing objects can be used from this menu.

## Use an object

1. Choose Potion, Mega Potion, or Ultra Potion from the bag list.
2. Choose any conscious creature in the party or storage.
3. Select **Use** to apply the restorative.

The target list and detail bar show current and maximum HP. Healing stops at maximum HP, so an Ultra Potion applied to a creature missing 12 HP restores only 12. Potions cannot be used on full-HP or fainted creatures and are never consumed when the target or action is invalid.

The battle **I** action uses the same Potion stack. Field and battle screens therefore observe one inventory source of truth.

## Persistent post-battle HP

Battle damage is synchronized directly to each persistent `CreatureInstance`. Returning to Mosslight Crossing after victory, capture, retreat, or defeat no longer restores the collection automatically. The roster and object menu immediately show the remaining HP.

A creature at zero HP remains fainted and cannot be restored by a Potion. Choose another healthy fighter with **P**. A later healing-center or revival module can add recovery for fully fainted teams without weakening the current inventory rules.

## Architecture

- `ItemDefinition` contains the data-defined potion potency and display text.
- `InventoryService` owns stock mutation and stack constraints.
- `ItemEffectService` remains the shared HP-effect implementation used by battles and the field.
- `FieldItemUseService` validates the owned object and target, consumes one unit, applies healing, and restores the stock if a future effect fails after consumption.
- `ObjectMenu` manages only item/target selection and emits presentation-level success feedback.
- `ExplorationScreen` owns menu availability and no longer applies automatic post-battle healing.

Automated coverage verifies all three potencies, maximum-HP caps, failure atomicity, object ordering, captured-creature targeting, input guards, exact battle-damage persistence, field healing, inventory consumption, and map feedback.
