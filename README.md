# Pokedot

A Godot 4 PC creature-collection RPG developed as a series of tested, decoupled modules.

## Current module

Creature Data & Stats provides:

- Versioned JSON content files and a formal species schema
- Typed species, creature, move, type, status, and growth-curve definitions
- JSON repository and cross-reference validation
- Deterministic stat, experience, learnset, and type-effectiveness calculations
- Headless automated tests

See [Creature Data & Stats](docs/creature-data-and-stats.md) for formulas and extension rules.
Progress and module completion evidence are tracked in [the delivery roadmap](docs/roadmap.md).

## Run

Open `project.godot` in Godot 4.7.1 and run the project. The bootstrap loads and validates all content.

Run tests from the repository root:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```
