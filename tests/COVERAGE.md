# Automated Behavior Coverage

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
| Battle participants | HP synchronization, four active moves, per-battle move uses |
| Damage | Physical/special stats, accuracy boundary, status moves, critical, variance, STAB, weakness, immunity |
| Turn order | Move priority, Speed, and reproducible exact ties |
| State machine | Initialization, phases, turn readiness, next turn, terminal state, both victory outcomes |
| Commands | Missing, invalid side, unknown/unlearned/depleted move, duplicate submission |
| Resolution | Damage application, misses, move-use consumption, knockout and skipped queued action |
| Events/signals | Observer notifications, ordered history, status resolution, defeat and final outcome |
| Determinism | Identical seed and command sequence produce identical HP and event types |
| Status lifecycle | Application, duplicate rejection, persistence sync/restore, finite expiry, stack composition |
| Status hooks | Action denial, Speed reduction, switch lock, physical penalty, end-turn damage |
| Status integration | Status moves, secondary chance success/failure, ordering, knockout and emitted events |
| Parties | Size and unique-ID validation, bench retention, usable-member outcome evaluation |
| Switching | Priority, target validation, incoming damage, persistent retention, volatile cleanup, forced replacement |
| Battle AI | Expected-damage scoring, status utility, depleted moves, low-HP switch, movement lock, no-action result |
| AI determinism | Equal-score commands and integration submission produce reproducible selections |
| Item content | Typed item lookup, category rules, stack limits, key-item invariants, status cross-references |
| Inventory transactions | Add/remove, zero cleanup, invalid amounts, insufficient stock, atomic stack and slot limits |
| Item effects | Flat and fractional healing, max-HP cap, defeated/full rejection, remedy persistence sync |
| Creature collection | Party insertion, storage routing, missing data and duplicate instance rejection |
| Capture probability | HP, status, device and encounter multipliers, min/max clamps, deterministic success and critical rolls |
| Encounter rules | Trainer capture rejection, wild failure continuation, device consumption, successful terminal state |
| Battle items | Command priority, healing/remedy events, stock consumption, target and item validation |
| Capture events | Attempt evidence, collection destination, terminal outcome, queued counterattack suppression |

