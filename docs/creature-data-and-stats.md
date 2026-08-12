# Creature Data & Stats

This module separates authored definitions from runtime creature state and keeps all calculations independent from Godot scenes.

## Content documents

Every file under `data/` is a versioned document with this envelope:

```json
{
  "schema_version": 1,
  "items": []
}
```

Stable lowercase `snake_case` IDs are used for every cross-reference and save-game reference. `JsonContentRepository` converts JSON into typed resources. `ContentValidator` then checks domain constraints and references across all files.

The formal JSON Schema for creature species is in `data/schemas/species.schema.json`. Runtime validation remains authoritative because it also checks references to moves, types, and growth curves.

## Definition versus instance

`CreatureSpeciesDefinition` contains shared, immutable design data. `CreatureInstance` contains mutable data for one owned or encountered creature. Save files should serialize the instance and retain only the species ID.

## Derived stat formula

Inputs are bounded before calculation:

- Base stat: at least 1; authored content is validated from 1 to 255.
- Level: 1 to 200; current authored curves stop at 100.
- Genetic potential: 0 to 20 per stat.
- Training: 0 to 200 per stat and 500 total.
- Aptitude multiplier: 0.5 to 1.5; normal is 1.0.

```text
trained_value = 2 × base + genetic_potential + floor(training / 10)
scaled_value  = floor(trained_value × level / 100)

HP         = scaled_value + level + 15
Other stat = floor((scaled_value + 5) × aptitude_multiplier)
```

All arithmetic is centralized in `StatCalculator` so balancing changes do not leak into UI, combat, or save code.

## Experience curves

The safe, data-driven total-experience formula is:

```text
total_xp(level) = floor(scale × (level ^ exponent - 1))
```

Level 1 always begins at zero XP. Content controls `scale`, `exponent`, and `max_level`; arbitrary expressions are never evaluated from data files.

## Type effectiveness

Each attacking type stores only non-neutral defensive matchups. Missing entries equal `1.0`. Multiple defender types multiply:

```text
final_multiplier = matchup(defender_type_1) × matchup(defender_type_2)
```

## Extension rules

- Add fields to JSON with backward-compatible defaults or increment `schema_version` and provide a migration.
- Put calculations in application services, not definition resources.
- Do not let scenes read JSON directly; depend on `ContentCatalog`.
- Add a validator rule and at least one test whenever a new content constraint is introduced.
