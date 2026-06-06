# ENGINE REWORK ROADMAP - ZIGUEZON ENGINE

This file holds implementation sequencing and migration notes for the
world/entity/simulation rework.

The guiding reference is:

    engine/world/engine_rework_reference.md

If this roadmap conflicts with the reference, the reference takes precedence.


## Current Starting Point

Phase 1D/1E completed the current World-owned component foundation:

- `Engine` owns one `World`.
- `World` owns entity-id creation and typed component stores.
- `EngineStep` forwards consumed base ticks through `World.tick(TickInfo)`.
- Dense and sparse component stores are implemented.
- Component types must declare an explicit `storeType`.
- `floppy`, `ping`, and `orbiter` use World-owned typed component stores.
- `ping` and `orbiter` use `CompView` / `ComponentView` for transient typed
  store access.
- Borrowed component-store compatibility was removed.
- Relations, events, rules, traits, archetypes, logical scheduling, broad
  queries, and entity destruction remain deferred.

## Build Direction

The engine rework should build toward `World` as the central engine-owned
simulation database.

The target is not a pure ECS. The target is a data-oriented simulation layer
where entity identity, components, relations, events, rules, traits,
archetypes, schedules, queries, and views can be defined, stored, inspected,
and run cleanly.

Remaining sequence:

1. Add active entity tracking and component cleanup hooks.

2. Implement `World.destroyEntity()` once every registered component path can
   participate in cleanup.

3. Keep component views component-only until relation/event/trait query
   semantics exist.

4. Do not add marker-component support. Traits/metaproperties are the canonical
   way to mark, tag, classify, or flag entities.

5. Add relation storage as the first major `World` extension after entity and
   component cleanup are stable.

6. Keep at least one minimal generic reference relation in engine code.

7. Add generic event records/queues after entity, component, and relation
   ownership is stable. This means reworking the current event system entirely.

8. Keep at least one minimal generic reference event in engine code.

9. Add rule/reaction support after events exist.

10. Keep at least one minimal generic reference rule/reaction in engine code.

11. Add traits/metaproperties after the base world data model is usable.

12. Keep at least one minimal generic reference trait/metaproperty in engine
    code.

13. Add archetypes/templates for bundles of initial facts.

14. Keep at least one minimal generic reference archetype/template in engine
    code.

15. Add World logical-time and scheduler support progressively, driven by base
    ticks received from the existing `EngineTiming` system.

16. Add broad query helpers progressively, driven by real game and debug needs.

17. Keep `engine/world/context` reserved for future save/load/replay-facing
    world context work. Do not implement it until reusable save/load
    primitives exist in `utils`.

18. Add a particle/effects system after events, rules, render adapters, and
    relevant query/view helpers are stable.


## World Responsibilities

`World` should eventually organize:

- entity identity and lifecycle
- component tables
- relation tables
- event records / event queues
- rules and reactions
- traits / metaproperties for marking and classification
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

### 1. Entity Lifecycle And Cleanup

Add active entity validity, entity destruction, and registered-store cleanup.

Keep this slice small:

- active entity tracking
- entity existence checks for World-owned operations
- erased component cleanup callbacks for destroyed entities
- `World.destroyEntity()` once every registered component path can clean up
- tests for destroy cleanup across dense and sparse component stores

Avoid adding relations, events, rules, traits, or archetypes in this slice
unless they are required to prevent a bad lifecycle boundary.

`World` must still not add another base-tick pacing loop. Preserve the existing
flow:

1. `EngineTiming` measures elapsed real time and determines when base ticks are
   due.
2. `EngineStep` consumes due or forced ticks.
3. `EngineStep` forwards a tick context into `World.tick(...)`.
4. `World` executes the simulation phases for that base tick.

The initial tick context should expose the existing tick index and relevant
timing values without moving their ownership out of `EngineTiming`.

### 2. Component Storage And Views

Keep the current component storage and view foundation stable while later World
features are added.

Default storage should stay sensible. Performance-relevant storage choices
should be explicit on the data type passed to the store generator.

Prefer dense arrays, sparse sets, hash maps, indexed tables, and
relation-specific indexes unless profiling proves another structure is
justified.

The generic engine-owned components in `baseComps.zig` currently opt into
`.DENSE`. Keep dense storage focused on packed iteration and cache locality, and
keep sparse storage focused on rare, optional, or lookup-oriented components.

Do not add storage special cases for marker components or zero-data tag
components. Component stores are for per-entity state. Classification belongs in
traits/metaproperties.

Component views should remain transient typed access helpers. They are not the
full future query system over relations, events, traits, archetypes, or history.

### 3. Relations

Add first-class relation storage for facts that connect entities.

Initial engine examples should stay generic:

- Owns
- Contains
- ParentOf
- MemberOf
- LinkedTo
- DependsOn

Do not use relations as mere tags. Use a relation only when both endpoints are
meaningful entities. `MemberOf` means membership in another entity, such as a
group, container, inventory, selection set, or collection that has identity,
state, lifecycle, rules, or query value of its own. If the target would only
exist to hold a label, model the label as a trait/metaproperty instead.

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

Traits/metaproperties are the canonical replacement for marker components and
relation-shaped tags. Use them for facts like "selectable", "visible",
"simulated", or other presence-style classifications.

Initial engine examples should stay generic:

- Selectable
- Visible
- Simulated
- Container
- Indexed

Add archetypes/templates for bundles of initial facts after traits and the base
world data model are usable.

Except for the engine's focus on simulation-heavy games, engine-level traits and
archetypes should stay genre-agnostic.

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
continue through entity cleanup, relations, events, rules, traits, archetypes,
scheduler, and broad queries before context work becomes implementation-ready.

### 10. Particles And Transient Effects

Add a particle/effects system after the event/rule path and render adapters are
stable enough to drive visual effects from world facts.

Particles that are only visual should not be entities. Use entities for
gameplay-relevant projectiles, hazards, selectable objects, or anything that
participates in components, relations, rules, or collision. Use a particle pool
for smoke, sparks, trails, impact dust, brief feedback effects, and similar
transient visual effects.

The target split is:

- emitter components on entities for persistent effect sources;
- world events or rules for effect triggers;
- `ParticleConfigs` for effect definitions and spawn ranges;
- a packed transient particle pool for simulation and rendering;
- render systems/adapters that draw particles without exposing pool internals
  to game code.

For save/load and replay, prefer recording deterministic effect triggers,
configs, and seeds over serializing individual particle rows. Individual
particles should be excluded from normal saves unless a later feature
explicitly needs retained visual-effect state.

`games/ping` should eventually replace pseudo-particle entities with this
system, but not before the generic event/rule/render pieces exist. Treat that
as the first concrete migration proof for the particle/effects system.


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
- Except for the engine's focus on simulation-heavy games, keep engine-level
  systems, examples, traits, and archetypes genre-agnostic.
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
