# Captured Creature Roster

Press **P** while actively exploring to open the complete captured-creature menu. The field pauses while the roster is visible.

Every owned creature appears, including captures routed to storage after the six-member party fills. Each card shows its display name, level, elemental types, party/storage location, and current-level XP percentage. The detail panel shows HP, an accumulative XP bar with exact totals and XP remaining, description, and learned moves.

## Select the next fighter

Click a creature card, or focus it with the keyboard and press Enter. The selected card is marked **NEXT FIGHTER**. Press **P** or Escape to return to the map.

The exact selected instance—not merely its species—is used as the player participant in the next wild one-versus-one battle. A stored creature may be selected without changing party/storage organization. After the battle, the selection remains active until the player chooses another creature.

New captures use the same live `CreatureCollection`; reopening the menu immediately includes them. Current HP also remains live: battle damage persists on the map and can be restored from the **B** object menu. Use an Elixir there to revive a fully fainted creature with half of its maximum HP before selecting it as the next fighter.

## Architecture

- `CreatureCollection` provides ordered aggregate and lookup queries across party and storage.
- `CreatureRosterMenu` renders collection state and emits a stable selected instance ID.
- `ExplorationScreen` owns the selected lead and creates the next 1v1 player party from that instance.
- `WildBattleFactory` and `BattleManager` remain unchanged and receive a normal typed creature array.

Headless scene coverage verifies the full menu, XP projection, and the map → selection → battle victory → level-up → roster round trip.
