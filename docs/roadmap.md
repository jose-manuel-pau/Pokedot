# Delivery Roadmap

Each module is considered complete only after its automated behavior coverage passes in headless Godot.

| Module | Status | Completion evidence |
| --- | --- | --- |
| 1. Creature Data & Stats | Complete — 2026-08-12 | Typed domain model, JSON repository, validator, formulas, sample content |
| 2. Combat vertical slice | Complete — 2026-08-12 | One-versus-one state machine, command queue, deterministic RNG, damage, events |
| 3. Statuses and battle AI | Complete — 2026-08-12 | Composable status hooks, durations, party switching, deterministic enemy decisions; cumulative 68 cases / 292 assertions passing |
| 4. Capture and inventory | Complete — 2026-08-12 | Validated item catalog, atomic inventory, deterministic capture, restorative commands, wild encounters, party/storage routing; cumulative 95 cases / 444 assertions passing |
| 5. Exploration | Complete — 2026-08-12 | Playable top-down map, collision, NPC dialogue, deterministic encounter zones, cooldowns, battle handoff; cumulative 114 cases / 557 assertions passing |
| 6. Progression and persistence | Complete — 2026-08-12 | XP yields/rewards, multi-level growth, move choices, participation sharing, roster transactions, validated snapshots, migration, recoverable slots; cumulative 149 cases / 744 assertions passing |
| 7. Original content pipeline | Complete — 2026-08-12 | Five playable creatures, structured art briefs, shared direction, deterministic provider prompts, validated atomic manifest export; cumulative 159 cases / 841 assertions passing |
| 8. Production pass | Complete — 2026-08-12 | Balance/readiness audits, persistent accessibility, semantic audio/VFX, branding, Windows preset and verified PCK export; cumulative 177 cases / 924 assertions passing |
| 9. Playable battle presentation | Complete — 2026-08-12 | Graphical original-creature arena, live HUD/log, move/capture/item/run controls, wild AI response, encounter bridge; cumulative 183 cases / 966 assertions passing |

