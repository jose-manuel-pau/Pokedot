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

See [Creature Data & Stats](docs/creature-data-and-stats.md) for formulas and extension rules.
See [Combat Vertical Slice](docs/combat-vertical-slice.md) for the state machine, damage formula, and event contract.
Progress and module completion evidence are tracked in [the delivery roadmap](docs/roadmap.md).

## Run

Open `project.godot` in Godot 4.7.1 and run the project. The bootstrap loads and validates all content.

Run tests from the repository root:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
