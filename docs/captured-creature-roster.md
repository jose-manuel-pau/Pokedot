# Captured Creature Roster

Press **P** while actively exploring to open the complete captured-creature menu. The field pauses while the roster is visible.

Every owned creature appears, including captures routed to storage after the six-member party fills. Each card shows its display name, level, elemental types, and whether it is in the party or storage. The detail panel shows HP, description, and learned moves.

## Select the next fighter

Click a creature card, or focus it with the keyboard and press Enter. The selected card is marked **NEXT FIGHTER**. Press **P** or Escape to return to the map.

The exact selected instance—not merely its species—is used as the player participant in the next wild one-versus-one battle. A stored creature may be selected without changing party/storage organization. After the battle, the selection remains active until the player chooses another creature.

New captures use the same live `CreatureCollection`; reopening the menu immediately includes them. The prototype restores every owned creature between field encounters because a healing-center gameplay loop has not yet been added.

## Architecture

- `CreatureCollection` provides ordered aggregate and lookup queries across party and storage.
- `CreatureRosterMenu` renders collection state and emits a stable selected instance ID.
- `ExplorationScreen` owns the selected lead and creates the next 1v1 player party from that instance.
- `WildBattleFactory` and `BattleManager` remain unchanged and receive a normal typed creature array.

Headless scene coverage verifies the full menu and the map → selection → next battle → map round trip.
