# Exploration

This module provides three connected outdoor maps—**Mosslight Crossing**, **Dewstone Vale**, and **Lumenstead Village**—plus the first building interior, **Lumen Research House**. It combines deterministic grid movement, terrain and interactable collision, dialogue, treasure collection, a dialogue-gated creature-egg choice, data-driven wild encounter zones, smooth map travel, and a tested handoff into the existing wild battle state machine.

## Play the vertical slice

Run the project from Godot 4.7.1:

```powershell
godot --path .
```

Controls:

| Action | Keyboard |
| --- | --- |
| Move | WASD or arrow keys |
| Travel between outdoor maps | Follow an open trail through the east/west map boundary |
| Enter/leave the research house | Walk through its visible door |
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

Walk through bright grass or mistferns to trigger wild encounters. Open east/west boundary trails connect Mosslight Crossing, Dewstone Vale, and Lumenstead Village without artificial outdoor gates. Lumenstead's visible house door leads into the research house and is the only building-style transition. Inside, face Professor Lumen and interact before choosing one of the three eggs. The selected egg hatches into Cindermite, Reedling, or Gustlet at level five, joins the live collection, and becomes the next battle lead; the other eggs then close permanently for the current session. Face a closed treasure chest to receive one random Potion, Mega Potion, Ultra Potion, or Elixir. Walls, building walls, fences, NPCs, chests, and eggs block movement. Battle damage persists after returning to the field; press **B** to use restorative inventory between encounters.

## Architecture

Exploration follows the same scene-independent boundaries as combat:

```text
JSON map content
    ↓ load and cross-reference validation
ExplorationMapDefinition
    ↓ immutable terrain, zones, NPC, chest, gift, and exit placements
ExplorationSession
    ├─ movement and collision
    ├─ facing, dialogue, one-time chest interaction and gift prerequisites
    ├─ battle/map state transitions and cooldown
    ├─ domain events
    ├─ TreasureChestService → atomic InventoryService deposit
    └─ CreatureGiftService → initialized CreatureInstance → party/storage
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
- Creature-gift ID, choice group, position, species, level, and prerequisite NPC
- Map-exit ID, position, destination map/cell, arrival facing, and `open_path`/`door` style

Initial tile symbols:

| Symbol | Meaning |
| --- | --- |
| `#` | Impassable terrain |
| `.` | Walkable path |
| `-` | Impassable horizontal wooden fence |
| `\|` | Impassable vertical wooden fence |
| `H` | Impassable building wall/roof |
| `g` | Sunmeadow Grass encounter tile |
| `f` | Mistfern Patch encounter tile |

Fence and building symbols are reserved terrain rather than encounter-zone codes. `ContentValidator` rejects uneven rows, bad spawns, unknown tile symbols, encounter zones that reuse reserved terrain, unused or duplicated zone symbols, invalid encounter values, unknown species, invalid NPC placement/facing, overlapping interactables, missing dialogue, duplicate chest IDs/rewards, invalid chest positions/quantities, empty pools, unknown reward items, malformed creature gifts, missing gift prerequisites, duplicate choice-group species, invalid transition styles, open paths away from boundaries, invalid exit destinations/facing, occupied arrival cells, and map links without a return route.

## Treasure chest rewards

The maps contain seven map-defined chests. Every chest selects one item uniformly from its configured restorative pool using the injected `ExplorationRandomSource`:

- Potion
- Mega Potion
- Ultra Potion
- Elixir

`TreasureChestService` makes the roll and passes the award through `InventoryService`. The chest is marked open only after that transaction succeeds. If the chosen stack is full or the bag has no free slot, the chest remains closed, retains the already-rolled reward, and can be retried without rerolling. An opened chest cannot award a second item during the same exploration session, and its renderer visibly changes to the open state.

## Professor and egg choice

Professor Lumen and the three eggs are authored map content rather than hard-coded screen coordinates. `ExplorationState` records stable NPC IDs that have been spoken to and the chosen gift ID per mutually exclusive choice group. `ExplorationSession` rejects an egg interaction until its prerequisite NPC conversation has occurred, then delegates creature construction to `CreatureGiftService`. The service applies the species growth curve, level-threshold XP, learned moves, calculated maximum HP, stable instance ID, and shared party/storage routing. A successful selection emits `creature_gift_claimed`; presentation only observes the result, updates the next lead, and redraws the selected shell and unavailable eggs.

## Exploration state machine

The session phases are:

```text
not_started
    │ start(map_id)
    ▼
active ── successful encounter roll ──► battle_transition
  ▲                                          │
  └──────────── resume_after_battle() ───────┘

active ── step onto map exit ──► map_transition
  ▲                                  │
  └──── complete_map_transition() ────┘
```

Only cardinal movement is accepted. Walls, building walls, both fence orientations, NPCs, chests, and eggs use authoritative collision rules. A blocked move changes facing but does not change position or increment the step counter. Movement is rejected while a battle or map transition is pending. Map travel uses a two-phase contract: stepping onto an open boundary path or building door creates a typed `MapTransitionRequest` with its transition style and locks input; the presentation fades to black, commits the free arrival cell, and fades the new area in. Reduced-motion mode shortens both fade phases.

The session emits stable observer events for map start, movement, NPC interaction, treasure collection, creature-gift selection, map departure/arrival, wild encounters, and exploration resume. These events are suitable for animation, audio, quests, analytics, and replay tooling. The same live session remains active across map changes, preserving creature HP/XP, the selected fighter, inventory quantities, opened chests, NPC conversations, and the exclusive egg choice.

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
- Add locked or conditional doors on top of the existing typed map-exit style contract.
- Add broader quest conditions and branching dialogue behind stable NPC IDs.
- Persist opened chest IDs when the live exploration scene is connected to save-slot orchestration.
- Add terrain abilities by decorating movement validation.
- Add encounter conditions such as time, weather, lures, and story flags before weighted selection.
- Persist `ExplorationState` in the planned progression and save module.
