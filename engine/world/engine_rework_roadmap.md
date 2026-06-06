# ENGINE REWORK ROADMAP - ZIGUEZON ENGINE

This file holds implementation sequencing and migration notes for the
world/entity/simulation rework.

The guiding reference is:

    engine/world/engine_rework_reference.md

If this roadmap conflicts with the reference, the reference takes precedence.


## Current Starting Point

Phase 1C has established the first World-owned typed component path:

- `Engine` owns one `World`.
- `World` owns entity-id creation and typed component stores.
- `floppy` and `ping` use World-owned typed component stores.
- `orbiter` still uses the borrowed-store compatibility path.
- Component store policy metadata exists, but only the current sparse hash-map
  backend is implemented.
- Explicit `.DENSE` policy is recognized and rejected until dense storage
  exists.

## Build Direction

The engine rework should build toward `World` as the central engine-owned
simulation database.

The target is not a pure ECS. The target is a data-oriented simulation layer
where entity identity, components, relations, events, rules, traits,
archetypes, schedules, queries, and views can be defined, stored, inspected,
and run cleanly.

Near-term sequence:

1. Add `engine/world/worldManager.zig`.

2. Move entity identity and component access behind `World`.

3. Stabilize the current ECS/component path under `World`.

4. Rework component storage around explicit user-selectable policies:

       pub const storeType = .DENSE;

   and:

       pub const storeType = .SPARSE;

5. Keep at least one minimal generic reference component in engine code.

6. Add relation storage as the first major `World` extension after the world
   wrapper and component ownership are clear.

7. Keep at least one minimal generic reference relation in engine code.

8. Add generic event records/queues after entity, component, and relation
   ownership is stable. This means reworking the current event system entirely.

9. Keep at least one minimal generic reference event in engine code.

10. Add rule/reaction support after events exist.

11. Keep at least one minimal generic reference rule/reaction in engine code.

12. Add traits/metaproperties after the base world data model is usable.

13. Keep at least one minimal generic reference trait/metaproperty in engine
    code.

14. Add archetypes/templates for bundles of initial facts.

15. Keep at least one minimal generic reference archetype/template in engine
    code.

16. Add World logical-time and scheduler support progressively, driven by base
    ticks received from the existing `EngineTiming` system.

17. Add query/view helpers progressively, driven by real game and debug needs.

18. Keep `engine/world/context` reserved for future save/load/replay-facing
    world context work. Do not implement it until reusable save/load
    primitives exist in `utils`.


## World Responsibilities

`World` should eventually organize:

- entity identity and lifecycle
- component tables
- relation tables
- event records / event queues
- rules and reactions
- traits / metaproperties
- archetypes / templates
- logical simulation time and scheduling
- query and view helpers
- context records for future save/load/replay-facing world state

Entities should remain identifiers. Components, relations, events, traits, and
rules store the facts that make those identifiers meaningful.

The user-facing API should let game code express common simulation operations
without manually handling registry casts or container internals at every call
site:

- create entity
- add component
- add relation
- emit event
- apply trait
- spawn archetype
- run/query systems


## Implementation Phases

### 1. World Wrapper

Add `World` as the owner/interface for entity and component storage.

Keep this slice small:

- entity lifecycle
- component store ownership
- component add/get/remove helpers
- a `World.tick(TickContext)` boundary called from `EngineStep`
- a documented base-tick phase order
- enough migration glue for existing games

Avoid adding relations, rules, traits, or archetypes in this first slice unless
they are required to prevent a bad ownership boundary.

`World` must not add another base-tick pacing loop. Preserve the existing flow:

1. `EngineTiming` measures elapsed real time and determines when base ticks are
   due.
2. `EngineStep` consumes due or forced ticks.
3. `EngineStep` forwards a tick context into `World.tick(...)`.
4. `World` executes the simulation phases for that base tick.

The initial tick context should expose the existing tick index and relevant
timing values without moving their ownership out of `EngineTiming`.

### 2. Component Storage Policies

Rework component storage so users can choose dense or sparse storage where it
matters.

Default storage should stay sensible. Performance-relevant storage choices
should be explicit on the data type passed to the store generator.

Prefer dense arrays, sparse sets, hash maps, indexed tables, and
relation-specific indexes unless profiling proves another structure is
justified.

Once dense component storage is implemented, the generic engine-owned
components in `baseComps.zig` should opt into `.DENSE`. Until then, they should
remain on the working sparse/hash-map path so existing typed games can keep
registering them successfully.

### 3. Relations

Add first-class relation storage for facts that connect entities.

Initial engine examples should stay generic:

- Owns
- Contains
- ParentOf
- MemberOf
- LinkedTo
- DependsOn

Relation storage should move toward:

- source/target queries
- reverse lookups
- cardinality rules
- cleanup behavior when entities are destroyed

### 4. Events

Add events as records that something happened, not only as callbacks.

Initial engine examples should stay generic:

- EntityCreated
- EntityDestroyed
- ComponentAdded
- ComponentRemoved
- RelationAdded
- RelationRemoved
- TraitApplied
- TraitRemoved

Support transient events first if that is the smallest useful slice, but do not
block retained event history for debugging, UI, replay, audit, or future
history systems.

### 5. Rules And Reactions

Add a minimal rule/reaction layer once events exist.

Rules should be able to observe:

- components
- relations
- events
- traits
- time/schedules

Rules should be able to emit:

- commands
- events
- component changes
- relation changes
- trait changes

Keep the first engine example minimal and generic. Game-specific rule content
belongs under `games/`.

### 6. Traits And Archetypes

Add traits/metaproperties for reusable classification and behavior/data flags.

Initial engine examples should stay generic:

- Selectable
- Visible
- Simulated
- Container
- Indexed

Add archetypes/templates for bundles of initial facts after traits and the base
world data model are usable.

Avoid assuming a specific game genre in engine-level traits or archetypes.

### 7. Scheduler

Add scheduling support after the base world data model is stable enough to run
systems cleanly.

The scheduler is World-specific, but it is not a replacement for `EngineTiming`.
It runs inside `World.tick(...)` and schedules logical simulation work relative
to base ticks received from Engine.

The design must leave room for:

- systems that run every Engine base tick
- logical World time and game-defined time scales
- scheduled systems
- delayed events
- temporary time-bound rules

The first scheduler can be simple. It must not assume simulation time is render
time, and it must not independently decide when Engine base ticks occur.

### 8. Queries And Views

Add query/view helpers so simulation-heavy games, debug tools, and UI can
inspect the world without mutating internals directly.

Queries should eventually cover:

- components
- relations
- events
- traits
- archetypes

UI and debug tools should read through queries/views and emit commands/events
instead of reaching into storage internals.

### 9. Context

Reserve `engine/world/context` for future save/load/replay-facing World state.

This folder should eventually hold World context records, snapshot adapters,
and related state-description helpers once `utils` has reusable save/load or
serialization primitives.

For now, do not wire this folder into runtime code. The active rework should
continue through component storage, component views, relations, events, rules,
traits, archetypes, scheduler, and broad queries before context work becomes
implementation-ready.


## Architectural Boundaries

Keep ownership aligned with the reference document:

- `utils` owns reusable primitives: data structures, math, timing, logging,
  RNG, generic drawing helpers, generic camera primitives, and non-world UI
  primitives.
- `engine/core` owns runtime orchestration: `Engine`, lifecycle, timing loop,
  `EngineTiming`, base-tick/frame pacing, hooks, configs, and phase order.
- `engine/world` owns simulation infrastructure: `World`, entities,
  components, relations, events, rules, traits, archetypes, logical simulation
  time, scheduler, queries/views, and future context records for
  save/load/replay-facing world state.
- `engine/render` owns world-facing render adapters: `WorldCam`, world-space
  drawing wrappers, sprite/world render helpers, and debug render systems.
- `games` owns domain-specific simulation content.

Simulation data should not depend on rendering. Render systems read simulation
data and draw it.


## Implementation Constraints

- Keep this file focused on build order, migration steps, API sketches,
  compatibility notes, and unresolved implementation details.
- Keep principles and architectural intent in
  `engine/world/engine_rework_reference.md`.
- Keep engine-level examples minimal and generic.
- Do not add specialized simulation content to `engine/world`.
- Do not grow a large built-in content library.
- Prefer data tables, explicit metadata, relation indexes, and query/view
  helpers over hidden object graphs.
- Avoid linked-list storage unless a specific profile proves it is justified.
- Prefer ids over raw pointers as persistent truth.
- Preserve room for future save/load, deterministic replay, debugging, and
  event history without building those full systems yet.
- Keep `engine/world/context` dormant until reusable save/load primitives exist
  in `utils`.
- Keep phase order and event ordering explicit.
- Keep `EngineTiming` as the sole base-tick/frame pacing authority; World logical
  time and scheduling must build on ticks forwarded by Engine.
- Keep game-specific components, relations, events, traits, rules,
  archetypes, views, and UI bindings under `games/`.


## Success Condition

A user can build a data-oriented simulation with many entities and many
relationships, define their own simulation types cleanly, choose storage
policies when needed, inspect what the world contains, and rely on a small set
of generic engine examples as reference patterns.
