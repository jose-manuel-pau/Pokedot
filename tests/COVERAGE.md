# Automated Behavior Coverage

Coverage is requirements- and branch-oriented. A future CI pipeline may add engine-level line instrumentation, but completion of this module requires all behavior below to pass headlessly.

| Area | Covered behavior |
| --- | --- |
| Stat formula | HP, non-HP, aptitude increase/decrease, complete instance |
| Stat boundaries | Invalid base, level, potential, training, and aptitude bounding |
| Training | Per-stat and total allocation limits |
| Experience | Threshold calculation, reverse lookup, progress, minimum and maximum level |
| JSON repository | All nine content documents, typed conversion, expected counts |
| Catalog | Species, move, type, status, and growth-curve lookup |
| Cross-references | Species types, learnsets, growth curves, move types and statuses |
| Validation | Bad stats, catch rate, type count, learn level, references, accuracy, move category, matchup range |
| Learnsets | Unlock queries at multiple levels |
| Type effectiveness | Weakness, resistance, neutral, dual-type multiplication, unknown attack type |
| Battle participants | HP synchronization, four active moves, per-battle move uses |
| Damage | Physical/special stats, accuracy boundary, status moves, critical, variance, STAB, weakness, immunity |
| Turn order | Move priority, Speed, and reproducible exact ties |
| State machine | Initialization, phases, turn readiness, next turn, terminal state, both victory outcomes, wild retreat |
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
| Item effects | Flat and fractional healing, max-HP cap, defeated/full rejection, fainted-only 50% revival, remedy persistence sync |
| Creature collection | Party insertion, storage routing, missing data and duplicate instance rejection |
| Complete collection queries | Stable party/storage aggregation, instance lookup, and location lookup |
| Capture probability | HP, status, device and encounter multipliers, min/max clamps, deterministic success and critical rolls |
| Encounter rules | Trainer capture rejection, wild failure continuation, device consumption, successful terminal state |
| Battle items | Command priority, healing/remedy events, stock consumption, target and item validation |
| Capture events | Attempt evidence, collection destination, terminal outcome, queued counterattack suppression |
| Exploration content | Typed maps, tile grids, encounter tables, NPC dialogue, treasure chests, schema and cross-reference validation |
| Map queries | Dimensions, boundary behavior, terrain collision, zone, NPC, and chest lookup |
| Exploration movement | Cardinal validation, facing, blocked terrain/NPC/chests, successful steps, and state mutation |
| NPC interaction | Facing-based lookup, dialogue copy, empty interaction rejection, and observer event |
| Treasure chest service | Four deterministic roll boundaries, missing/unknown content, stack/slot capacity, atomic deposits |
| Treasure interaction | Facing-based collection, one-time state/event, retry after deposit failure, live object-menu quantity, opened feedback |
| Wild encounters | Trigger boundary, weighted first/last entries, inclusive levels, invalid tables, seeded reproducibility |
| Encounter state | Active/transition phases, movement lock during transition, resume, and cooldown roll suppression |
| Battle handoff | Request validation, wild instance identity/XP/moves, capturable battle initialization, error forwarding |
| Playable scene | Project bootstrap, keyboard adapter, code-drawn map, dialogue panel, and live graphical battle |
| Battle presentation | Original creature silhouettes, all-species viewport/HUD clearance at default and maximum text size, combatant HUDs, move/capsule/Potion/run actions, logs and outcomes |
| Encounter UI bridge | Wild handoff opens command-ready battle, retreat closes it, and exploration resumes |
| Captured roster menu | Party/storage cards, detail view, live capture refresh, selection, close signal and invalid ID rejection |
| Next-fighter handoff | P-key access, field-input blocking, stored-creature selection, 1v1 participant identity and retained lead |
| Field restorative service | 20/50/100 HP tiers, maximum cap, 50% Elixir revival, stock consumption, failed-use atomicity, conscious/fainted/unknown rejection |
| Object menu | Restorative-first ordering, quantities, potency, complete-collection targeting, HP/revival feedback, Up/Down action focus, disabled-action skipping, input and state guards |
| Persistent field HP | Exact battle damage survives map return and is restored only through shared restorative inventory |
| XP rewards | Species yields, wild formula, trainer premium, invalid inputs, minimum reward |
| Creature growth | XP normalization, no-level award, multi-level jump, max-level clamp, six-stat recalculation |
| Growth HP | Conscious maximum-HP increase, existing-damage preservation, defeated creature remains at zero |
| Move learning | Automatic open-slot learning, full-set pending choices, replacement, decline, invalid choices |
| Battle rewards | Victory-only rule, entry participation, manual switch sharing, deterministic remainder, one-time claim |
| XP progress projection | Current-level bar ratio, cumulative total, remaining XP, legacy normalization, invalid content and max level |
| Live progression UI | Battle victory reward, immediate level/bar refresh, result feedback, and exploration-to-roster persistence |
| Save serialization | JSON-compatible full aggregate round-trip and reference independence |
| Save validation | Profile, exploration, inventory, party/storage identity, XP/level, HP, build, moves, statuses |
| Save migration | Current deep copy, version-zero upgrade, invalid root and future-version rejection |
| Save repository | Write/load, overwrite, sorted slots, invalid-state rejection, corrupt/missing file, backup recovery |
| Party/storage roster | Transfer, six-member limit, final-member guard, lead reordering, atomic invalid requests |
| Original creature roster | Five typed gameplay species, eleven moves, concept/species/art-direction cross-references |
| Art direction | Prompt version, sprite canvas, camera, lighting, composition and shared exclusions |
| Creature concepts | Elements, inspirations, silhouette, anatomy, materials, personality, palette, pose and signature features |
| Content originality guard | Obvious third-party franchise references block pipeline compilation |
| Prompt compilation | Five lexical packages, provider-specific formatting, palettes, negative terms and deterministic manifests |
| Pipeline failure gate | Invalid or missing catalogs produce diagnostics and no generated artifacts |
| Prompt manifest export | JSON write, safe overwrite, temp/backup cleanup, output and manifest rejection |
| Pipeline CLI | Headless source load, compile, custom output selection and non-zero failure contract |
| Balance audit | Base-stat envelope, move power, elemental coverage, encounter dominance and obtainability |
| Balance metrics | Deterministic species, reward, move and encounter report serialization |
| Player preferences | Defaults, bounds, high contrast, text scale, reduced motion, mute and observer signals |
| Preferences repository | Versioned round-trip, atomic overwrite, missing/corrupt/future fallback and null rejection |
| Exploration feedback | Semantic map, movement, collision, dialogue, encounter and resume cues |
| Optional audio/VFX | Muted/headless safety, distinct cue colors/frequencies, reduced-motion presentation seam |
| Production readiness | Main scene, icon, version, launcher, Windows preset, prompts, preferences and balance gate |
| Export packaging | Windows preset resource collection and headless PCK generation |
| Playtest onboarding | Startup help, complete keyboard controls, accessibility status and vertical-slice scope |

