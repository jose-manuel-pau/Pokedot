# Production Pass and Playtest Guide

Pokedot version 0.13.0 is a production-hardened PC vertical slice. It includes balance diagnostics, persistent accessibility preferences, semantic audio/visual feedback, original branding, a verified Windows export preset, playable graphical wild battles, cumulative XP and level-ups, persistent battle damage, explorer-accessible creature and object menus, and Elixir revival.

## Start playing

### Fastest option on this workspace

Double-click `play_pokedot.cmd` in the project root. The launcher uses the bundled Godot 4.7.1 executable and keeps editor/game settings inside the workspace's ignored `.godot-user` directory.

If Windows displays a security prompt for a local batch file, inspect the short script first, then choose to run it. It only locates Godot, redirects Godot's settings directory, and starts this project.

### Godot editor

1. Start Godot 4.7.1.
2. Import or open `project.godot` from the Pokedot folder.
3. Press **F6** only for an explicitly selected scene, or **F5** / the Run Project button to launch the intended `src/main.tscn` entry point.
4. The Pokedot Playtest panel appears first. Press Enter, Space, or Escape to enter Mosslight Crossing.

### Command line

From PowerShell in the repository root:

```powershell
& '.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe' --path .
```

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or Arrow Keys |
| Interact / advance dialogue | E, Space, or Enter |
| Open captured-creature roster | P |
| Choose next battle creature | Click/focus a roster card and press Enter |
| Close captured-creature roster | P or Escape |
| Open object menu | B |
| Navigate object menu | Up/Down through objects, creatures, Use, and Close |
| Choose object and target creature | Click/focus cards and press Enter |
| Close object menu | B or Escape |
| Select battle move | 1–4 or click a move button |
| Throw Basic Capsule | C or click Capsule |
| Use Potion | I or click Potion |
| Run from wild encounter | R, Escape, or click Run |
| Continue after battle | Enter, Space, Escape, or click Continue |
| Open/close help | F1 |
| Toggle high contrast | F2 |
| Cycle text size: 100%, 125%, 150% | F3 |
| Toggle reduced motion | F4 |
| Mute/unmute feedback audio | M |

Accessibility choices save immediately. A corrupt, missing, or future-version preferences file falls back to safe defaults rather than blocking startup.

## Suggested first playtest

1. Confirm the initial help panel is readable, then enter the map.
2. Walk into a wall and verify movement is blocked with red visual/audio feedback.
3. Walk toward Ranger Mira, face her, and press E to read both dialogue lines.
4. Walk through bright grass (`g`) and mistferns (`f`) until a seeded wild encounter appears.
5. Press P on the explorer map and confirm every party and storage capture is listed. Select a creature and close the menu with P or Escape.
6. Confirm the graphical battle uses the selected creature and shows both original silhouettes, levels, HP, statuses, the combat log, two to four moves, capsule count, Potion count, and Run.
7. Select moves and verify the wild AI responds, HP bars change, move uses decrease, statuses appear, and the turn counter advances.
8. Defeat the wild creature and verify the XP reward, level-up message when a threshold is crossed, and updated blue XP bar.
9. Press R after taking damage, return to the map, and verify the creature is not automatically healed.
10. Press B, confirm Potion, Mega Potion, Ultra Potion, and Elixir are first. Use Up/Down to reach the creature and Use controls, heal a damaged creature, and verify its HP and object quantity update.
11. Let a creature reach zero HP, then use Elixir from the B menu. Verify it revives with half maximum HP and the Elixir count decreases by one.
12. Reopen the roster and confirm HP, earned XP, and level persist; also confirm a new capture appears, then select it and verify it leads the following encounter.
13. Toggle F2, F3, F4, and M. Restart the game and verify those preferences remain active.
14. Check that map-start, movement, collision, dialogue, encounter, battle, and resume feedback remain visually distinct.

Wild encounters are now command-driven one-versus-one battles. The UI observes the same tested battle events used by headless coverage; it does not duplicate damage, status, AI, inventory, capture, or progression rules. Battle XP rewards and automatic level-ups are exposed in this compact screen; party switching and save-slot management remain domain-complete but do not yet have dedicated battle/menu controls.

## Production diagnostics

Run the deterministic balance audit:

```powershell
& '.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tools/audit_balance.gd
```

It reports base-stat totals, catch rates, XP-to-stat ratios, damaging-move power and elemental coverage, encounter appearances, and per-zone weight shares. Current production content passes with zero errors and zero warnings.

Run the aggregate release-readiness check:

```powershell
& '.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tools/verify_release.gd
```

Reports are generated under ignored `builds/reports/` paths.

## Tests and export verification

Run every automated suite:

```powershell
& '.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd
```

Verify the production resource pack without installing platform templates:

```powershell
& '.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-pack "Windows Desktop" builds/windows/Pokedot.pck
```

To create a distributable `Pokedot.exe`, install the matching Godot 4.7.1 export templates from **Editor → Manage Export Templates**, open **Project → Export**, select **Windows Desktop**, and choose **Export Project**. The committed preset supplies the product name, icon, version, resource filters, and default `builds/windows/Pokedot.exe` path.

## Architecture

- `BalanceAnalyzer` is a read-only application service; thresholds do not leak into battle formulas.
- `ProductionReadinessService` composes balance, prompt, project, branding, preferences, and export checks.
- `PlayerPreferencesService` owns mutations and observer notifications.
- `PreferencesRepository` owns versioned JSON, default fallback, and atomic temp/backup promotion.
- `ExplorationFeedbackRouter` translates domain events into semantic cues without knowing about nodes or audio devices.
- `ProceduralAudioFeedback` synthesizes short original tones at runtime, avoiding licensed audio assets.
- `ExplorationScreen` remains an input/rendering adapter and observes preferences and cues.
- `BattleScreen` translates player controls into domain commands and battle events into HUD/log feedback.
- `BattleArena` supplies replaceable code-drawn original creature graphics without entering the battle domain.
- `CreatureRosterMenu` reads the live collection and emits only the selected instance ID; exploration owns the next-battle decision.
- `ObjectMenu` presents shared inventory and collection state with explicit vertical focus navigation while `FieldItemUseService` owns atomic field restoration.

Generated reports, exports, local settings, and imported editor data remain ignored by Git.
