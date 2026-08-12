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
- Decoupled battle events and signals for future presentation
- Deterministic battle replay behavior

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

See [Creature Data & Stats](docs/creature-data-and-stats.md) for formulas and extension rules.
See [Combat Vertical Slice](docs/combat-vertical-slice.md) for the state machine, damage formula, and event contract.
See [Statuses and Battle AI](docs/statuses-battle-ai.md) for hooks, party switching, and AI policy.
See [Capture and Inventory](docs/capture-inventory.md) for item contracts, encounter rules, and the capture formula.
See [Exploration](docs/exploration.md) for controls, map content, encounter selection, and battle transitions.
Progress and module completion evidence are tracked in [the delivery roadmap](docs/roadmap.md).

## Run

Open `project.godot` in Godot 4.7.1 and run the project. The bootstrap loads and validates all content.

Run tests from the repository root:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
