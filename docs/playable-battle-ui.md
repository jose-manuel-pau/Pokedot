# Playable Battle UI

The graphical battle screen is a presentation adapter over the existing battle state machine. It never calculates damage, capture probability, status behavior, turn order, or AI choices itself.

## Player flow

1. A field encounter creates a live wild `BattleManager` through `WildBattleFactory`.
2. `ExplorationScreen` passes that manager, the content catalog, and player inventory to `BattleScreen`.
3. The player selects a move, Basic Capsule, Field Tonic, or Run by mouse or keyboard.
4. `BattleScreen` submits the matching command, asks `BattleAiController` for the wild command, and resolves the turn.
5. Domain events update the combat log, HP bars, statuses, move uses, arena impact cue, and result panel.
6. A player victory awards cumulative XP once, updates any crossed levels, and refreshes the XP bar and result feedback.
7. Continue closes the battle, restores the demo starter for ongoing playtesting, applies encounter cooldown, and resumes the field state machine.

## Controls

| Action | Keyboard | Mouse |
| --- | --- | --- |
| Use a move | 1–4 | Move button |
| Throw Basic Capsule | C | Capsule button |
| Use Field Tonic | I | Tonic button |
| Retreat | R or Escape | Run button |
| Close result | Enter, Space, or Escape | Continue button |

The Tonic action is disabled at full HP. Capsule and Tonic actions display and consume their live inventory quantities. Move buttons display elemental type and current/maximum uses.

The player HUD also displays a blue current-level XP bar and exact cumulative total. A victory lists the earned XP and any level increase in both the log and result panel before returning to exploration.

## Graphics seam

`BattleArena` draws an original habitat and distinct silhouettes for Cindermite, Reedling, Gustlet, Aurorook, and Cairnback from primitive shapes and elemental palette data. This keeps the prototype immediately playable without importing third-party art. It is intentionally replaceable: final sprite nodes can observe the same participants and battle events without changing application or domain code.

## Covered behavior

Headless coverage instantiates the real scenes and verifies:

- combatant names, levels, arena data, available moves, inventory counts, and initial log;
- all five creature silhouettes remain inside the viewport and clear of the name, HP, log, turn, and command panels on both battle sides;
- move selection submits both commands, resolves damage, advances the turn, and redraws HP/log state;
- victory awards the defeated creature's XP once, crosses the configured level threshold, and redraws the new level and XP bar;
- Run finishes a wild battle through the domain state machine and exposes the result panel;
- a field encounter opens the graphical screen, and battle growth persists into the captured-creature roster after exploration resumes.
