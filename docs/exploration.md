# Exploration

This module adds Pokedot's first playable field scene: **Mosslight Crossing**. It combines deterministic grid movement, terrain, NPC and treasure-chest collision, dialogue and chest interaction, data-driven wild encounter zones, and a tested handoff into the existing wild battle state machine.

## Play the vertical slice

Run the project from Godot 4.7.1:

```powershell
godot --path .
```

Controls:

| Action | Keyboard |
| --- | --- |
| Move | WASD or arrow keys |
| Interact / advance dialogue | E, Space, or Enter |
| Open captured creatures | P |
| Choose the next fighter | Click/focus a creature card and press Enter |
| Close captured creatures | P or Escape |
| Open field objects | B |
| Choose object/target | Click/focus a card and press Enter |
| Close field objects | B or Escape |
| Battle moves | 1–4 or click |
| Capture / Potion / run | C / I / R (Escape also runs) |
| Return after battle | Enter, Space, Escape, or click Continue |

Walk through bright grass or mistferns to trigger wild encounters. Stand next to Ranger Mira, face her, and interact to read her dialogue. Face a closed treasure chest and interact to receive one random Potion, Mega Potion, Ultra Potion, or Elixir. Walls, NPCs, and chests block movement. Battle damage persists after returning to the field; press **B** to inspect or use the updated restorative inventory between encounters.

## Architecture

Exploration follows the same scene-independent boundaries as combat:

```text
JSON map content
    ↓ load and cross-reference validation
ExplorationMapDefinition
    ↓ immutable terrain, zones, NPC and chest placements
ExplorationSession
    ├─ movement and collision
    ├─ facing, dialogue and one-time chest interaction
    ├─ state transitions and cooldown
    ├─ domain events
    └─ TreasureChestService → atomic InventoryService deposit
         ↓ encounter request
WildBattleFactory
         ↓
BattleManager.start_wild_battle()
```

`ExplorationScreen` translates keyboard input into session commands and renders command results. It does not decide collision or implement battle construction rules. It owns only the player's explicit next-fighter selection and passes that typed creature instance to `WildBattleFactory`. This lets a future sprite and TileMap presentation replace the code-drawn field without changing the rules.

## Versioned map content

`data/maps.json` describes:

- Stable map ID and display name
- Tile size and player spawn cell
- Equal-width tile rows
- Encounter zones associated with tile symbols
- Weighted species and inclusive level ranges
- Encounter rate and post-battle cooldown per zone
- NPC position, facing, name, and dialogue
- Treasure-chest ID, position, quantity, and item reward pool

Initial tile symbols:

| Symbol | Meaning |
| --- | --- |
| `#` | Impassable terrain |
| `.` | Walkable path |
| `g` | Sunmeadow Grass encounter tile |
| `f` | Mistfern Patch encounter tile |

`ContentValidator` rejects uneven rows, bad spawns, unknown tile symbols, unused or duplicated zone symbols, invalid encounter values, unknown species, invalid NPC placement/facing, overlapping interactables, missing dialogue, duplicate chest IDs/rewards, invalid chest positions/quantities, empty pools, and unknown reward items.

## Treasure chest rewards

Mosslight Crossing contains three map-defined chests. Each chest selects one item uniformly from its configured restorative pool using the injected `ExplorationRandomSource`:

- Potion
- Mega Potion
- Ultra Potion
- Elixir

`TreasureChestService` makes the roll and passes the award through `InventoryService`. The chest is marked open only after that transaction succeeds. If the chosen stack is full or the bag has no free slot, the chest remains closed, retains the already-rolled reward, and can be retried without rerolling. An opened chest cannot award a second item during the same exploration session, and its renderer visibly changes to the open state.

## Exploration state machine

The session phases are:

```text
not_started
    │ start(map_id)
    ▼
active ── successful encounter roll ──► battle_transition
  ▲                                          │
  └──────────── resume_after_battle() ───────┘
```

Only cardinal movement is accepted. A blocked move changes facing but does not change position or increment the step counter. Movement is rejected while a battle transition is pending.

The session emits stable observer events for map start, movement, NPC interaction, treasure collection, wild encounters, and exploration resume. These events are suitable for animation, audio, quests, analytics, and replay tooling.

## Wild encounter selection

For each successful step onto an encounter tile while cooldown is zero:

1. Roll once against the zone's per-step encounter rate. The roll succeeds when `roll < rate`.
2. On success, roll within the sum of entry weights to select a species.
3. Roll an integer within the selected entry's inclusive level range.
4. Emit a `WildEncounterRequest` containing encounter ID, map, zone, cell, species, and level.

Exploration uses its own injected `ExplorationRandomSource`; battle rolls remain isolated in `BattleRandomSource`. Identical seeds and movement sequences therefore reproduce the same exploration outcomes without coupling them to combat randomness.

After a battle transition, the zone's cooldown suppresses new encounter rolls for its configured number of successful steps.

## Battle transition contract

`WildBattleFactory` validates the request, builds a fully initialized `CreatureInstance`, assigns its level threshold experience and available moves, and starts a capturable `BattleManager` encounter. It returns `BattleTransitionResult` rather than changing scenes itself.

This boundary allows later scene routing to animate fades, load a full battle UI, and return a battle result while retaining the same tested encounter-to-combat handoff.

## Extension points

- Replace the renderer with authored TileMap layers and sprites while retaining map IDs and session rules.
- Add doors and map exits as new tile metadata and transition requests.
- Add NPC state, quest conditions, and branching dialogue behind stable NPC IDs.
- Persist opened chest IDs when the live exploration scene is connected to save-slot orchestration.
- Add terrain abilities by decorating movement validation.
- Add encounter conditions such as time, weather, lures, and story flags before weighted selection.
- Persist `ExplorationState` in the planned progression and save module.
