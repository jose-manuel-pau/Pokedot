# Creature Data & Stats Coverage

Coverage is requirements- and branch-oriented. A future CI pipeline may add engine-level line instrumentation, but completion of this module requires all behavior below to pass headlessly.

| Area | Covered behavior |
| --- | --- |
| Stat formula | HP, non-HP, aptitude increase/decrease, complete instance |
| Stat boundaries | Invalid base, level, potential, training, and aptitude bounding |
| Training | Per-stat and total allocation limits |
| Experience | Threshold calculation, reverse lookup, progress, minimum and maximum level |
| JSON repository | All five content documents, typed conversion, expected counts |
| Catalog | Species, move, type, status, and growth-curve lookup |
| Cross-references | Species types, learnsets, growth curves, move types and statuses |
| Validation | Bad stats, catch rate, type count, learn level, references, accuracy, move category, matchup range |
| Learnsets | Unlock queries at multiple levels |
| Type effectiveness | Weakness, resistance, neutral, dual-type multiplication, unknown attack type |

