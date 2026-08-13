# Pokedot

A Godot 4 PC creature-collection RPG developed as a series of tested, decoupled modules.

## Completed modules

Creature Data & Stats provides:

- Versioned JSON content files and a formal species schema
- Typed species, creature, move, type, status, and growth-curve definitions
- JSON repository and cross-reference validation
- Deterministic stat, experience, learnset, and type-effectiveness calculations
- Headless automated tests

The Combat Vertical Slice adds:

- A one-versus-one battle state machine
- Validated move commands and per-battle move uses
- Priority, Speed, and seeded tie-breaking
- Accuracy, physical/special damage, criticals, variance, STAB, and types
- Decoupled battle events and signals consumed by presentation and tests
- Deterministic battle replay behavior
- A playable graphical wild-battle screen with original code-drawn creatures
- Mouse and keyboard controls for moves, capture capsules, Potions, and retreat
- Live HP, status, move-use, turn, combat-log, and outcome feedback

Statuses and Battle AI adds:

- Composable before-action, stat, damage, switch, and end-turn status hooks
- Persistent, volatile, finite-duration, and stackable status lifecycle
- Parties of up to six creatures with manual and forced switching
- Deterministic move, status, and low-HP switch decisions
- Status and switching domain events for presentation

Capture and Inventory adds:

- Versioned item content with validated capture devices, healing, remedies, and key items
- Atomic inventory stack and slot transactions
- Deterministic HP-, status-, device-, and encounter-modified capture probability
- Explicit trainer-versus-wild battle rules and capture/item commands
- Automatic captured-creature routing to party or storage

Exploration adds:

- A playable top-down field map with keyboard movement and collision
- Versioned map, encounter-zone, and NPC dialogue content
- Seeded weighted encounters with level ranges and cooldowns
- NPC interaction and observer events
- A typed handoff that creates a live capturable wild battle

Progression and Persistence adds:

- Species XP yields, wild/trainer reward formulas, and participant sharing
- Multi-level stat growth with conscious/fainted HP rules
- Automatic and choice-based move learning
- One-time battle reward claims
- Versioned, validated party/storage, inventory, creature, and field snapshots
- Transactional party/storage transfers and lead ordering
- Recoverable JSON save slots with legacy migration

The Original Content Pipeline adds:

- Five original, playable creature concepts spanning the existing elemental roster
- Structured wildlife, folklore, silhouette, anatomy, palette, pose, and exclusion briefs
- A shared 96×96 pixel-sprite art direction with versioned JSON schemas
- Deterministic DALL-E 3 and Midjourney prompt compilation
- Cross-reference, originality, and art-brief validation
- Atomic export of provider-ready prompt manifests

The Production Pass adds:

- Deterministic balance and aggregate release-readiness reports
- Persistent high-contrast, text-size, reduced-motion, and mute controls
- Observer-driven visual feedback and original procedural audio cues
- Original application branding, version metadata, and a Windows Desktop export preset
- A one-click Windows playtest launcher and hands-on verification guide

The Captured Creature Roster adds:

- An explorer-accessible collection menu opened with P
- A complete party-and-storage list with levels, elements, HP, moves, and location
- Mouse and keyboard selection of the creature that leads the next wild battle
- Live refresh after captures and support for choosing stored creatures

The Battle Experience UI adds:

- Automatic cumulative XP awards for every defeated opposing creature
- Immediate level updates when a growth-curve threshold is crossed
- A live current-level XP bar, exact progress, and reward/level-up feedback in battle
- XP percentages on roster cards and exact progress in the selected creature details
- One shared read-only progress projection for consistent battle and roster values

The Object Menu and Persistent HP module adds:

- A map-accessible object list opened with B
- Potion, Mega Potion, and Ultra Potion tiers restoring 20, 50, and 100 HP
- Creature targeting across the complete captured collection
- Atomic field use that consumes stock only after a valid healing target is chosen
- Persistent post-battle damage instead of automatic field-map healing

See [Creature Data & Stats](docs/creature-data-and-stats.md) for formulas and extension rules.
See [Combat Vertical Slice](docs/combat-vertical-slice.md) for the state machine, damage formula, and event contract.
See [Statuses and Battle AI](docs/statuses-battle-ai.md) for hooks, party switching, and AI policy.
See [Capture and Inventory](docs/capture-inventory.md) for item contracts, encounter rules, and the capture formula.
See [Exploration](docs/exploration.md) for controls, map content, encounter selection, and battle transitions.
See [Progression and Persistence](docs/progression-persistence.md) for XP, move learning, save validation, and recovery.
See [Original Content Pipeline](docs/content-pipeline.md) for the five concepts, prompt contracts, validation, and export workflow.
See [Production Pass and Playtest Guide](docs/production-pass.md) to launch the game, test controls, run audits, and create a Windows build.
See [Playable Battle UI](docs/playable-battle-ui.md) for controls, presentation architecture, and encounter integration.
See [Captured Creature Roster](docs/captured-creature-roster.md) for collection-menu controls and next-battle selection behavior.
See [Progression and Persistence](docs/progression-persistence.md#live-battle-and-roster-presentation) for live reward and XP-bar behavior.
See [Object Menu and Persistent HP](docs/object-menu-potions.md) for potion tiers, targeting, and post-battle HP rules.
Progress and module completion evidence are tracked in [the delivery roadmap](docs/roadmap.md).

## Run

On Windows, double-click `play_pokedot.cmd`, or open `project.godot` in Godot 4.7.1 and run the project. The startup help panel lists all controls, and the bootstrap loads and validates all content.

Run tests from the repository root:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
