# ENGINE REWORK REFERENCE - ZIGUEZON ENGINE

## Purpose

This document records the core goals, principles, and boundaries for the
world/entity/simulation layer of Ziguezon Engine: a lightweight, flexible,
simulation-oriented 2D game engine.

The design is loosely inspired by simulation-heavy games such as Thief: The
Dark Project, Dwarf Fortress, RimWorld, and similar systems-driven games. The
goal is not to copy any one engine or game structure, but to build a modern Zig
implementation that uses low-level control, explicit data ownership, and
performance-aware storage to help users create complex simulation games cleanly.

It is not primarily an implementation roadmap. Detailed implementation order,
migration steps, and code-level breakdowns belong in:

    engine/world/engine_rework_roadmap.md

This file should be short enough to reread often, but dense enough that future
engine work does not need to re-litigate the same architectural goals.

## 1. CORE DIRECTION

### 1.1 The engine is simulation-oriented, not ECS-oriented

ECS remains important, but it is not the whole architecture.

The core design question is:

    "How do we model entities, data, relationships, events, rules, and
     emergent behavior in a clean, reusable way?"

not only:

    "How do we iterate components as fast as possible?"

Component iteration speed matters, but simulation games also need first-class
support for:

- relationships
- ownership
- containment
- history
- rules
- reactions
- traits
- archetypes
- scheduled simulation
- inspection and explanation

### 1.2 World is the central simulation database

The main engine-owned simulation primitive should be World.

World should eventually organize:

- entity identity
- component tables
- relation tables
- event records / queues
- rules and reactions      for entity interactions
- traits / metaproperties  for marking and classification
- archetypes / templates
- simulation scheduling
- query and view helpers
- context records          for save/load/replay-facing world state

This is closer to a simulation database than to an object hierarchy.

Entities are identifiers. Components, relations, events, traits, and rules
store the facts that make those identifiers meaningful.

### 1.3 Components are one table family

Components describe per-entity state:

- transform
- movement
- hitbox
- renderable shape
- sprite state
- simulation counters
- domain-specific state

Components should be data-first. Behavior belongs in systems. Rendering
belongs in render systems/adapters.

Components should not be forced to represent every fact. If a fact primarily
connects two or more entities, it is probably a relation.

Do not use marker components as the canonical way to tag or classify entities.
Presence-only markers, zero-data components, and component-store special cases
for "has this label" semantics create two competing classification paths.
Use traits/metaproperties for that purpose.

### 1.4 Relations are first-class simulation data

Relationships between entities must not be hidden inside arbitrary components
by default.

Relation examples should stay generic in the engine:

- Owns
- Contains
- ParentOf
- MemberOf
- LinkedTo
- DependsOn

Games may define specialized relations on top of these patterns.

Relations are not a tag system. Use a relation when the target is another
meaningful entity with identity, lifecycle, queries, state, rules, or ownership
semantics. For example, `MemberOf` means "this entity is a member of that group
entity", not "this entity has a string-like label". If there is no meaningful
target entity, use a trait/metaproperty instead.

Relations should eventually support source/target queries, reverse lookups,
cardinality rules, and cleanup behavior when entities are destroyed.

### 1.5 Events record change

Events are not only callbacks. They are records that something happened.

Event examples should stay generic in the engine:

- EntityCreated
- EntityDestroyed
- ComponentAdded
- ComponentRemoved
- RelationAdded
- RelationRemoved
- TraitApplied
- TraitRemoved

Games may define domain events on top of these.

Some events may be transient. Some may be retained for debugging, UI, replay,
audit, or future history systems. The architecture should allow both.

### 1.6 Rules and reactions create emergence

The rule/reaction layer should let facts produce behavior without forcing
games into large piles of special-case object logic.

Rules observe:

- components
- relations
- events
- traits
- time/schedules

Rules emit:

- commands
- events
- component changes
- relation changes
- trait changes

The engine should provide only a minimal generic rule/reaction example at
first. Game-specific rules belong in games.

### 1.7 Traits and archetypes support reuse

Traits/metaproperties classify entities and may attach reusable behavior or
data.

Traits/metaproperties are the canonical way to mark, tag, classify, or flag
entities. Prefer traits over marker components and over relation-shaped tags
whenever the fact is simply "this entity has this classification".

Archetypes/templates create bundles of initial facts.

Engine examples should stay generic:

- Selectable
- Visible
- Simulated
- Container
- Indexed

## 2. CONTRIBUTOR DIRECTIVES

### 2.1 Keep built-in systems minimal and generic

Core engine systems should include only what most games/simulations are likely
to need.

Each major concept should have at least one small reference implementation so
users can see how to define their own:

- at least one component type
- at least one relation type
- at least one event type
- at least one trait/metaproperty type
- at least one archetype/template
- at least one rule/reaction example

Add a few examples when genuinely useful. Do not grow a large built-in content
library inside the engine.

### 2.2 Engine code must remain game-agnostic

The engine may provide generic patterns. It should not assume:

- space games
- economy games
- combat games
- survival games
- RPGs
- colony sims

Game-specific components, relations, events, traits, rules, and archetypes
belong under games/
Except for its focus on simulation-heavy games, the system should stay
genre-agnostic.

### 2.3 Users should think in simulation concepts

Engine users should be able to express:

- create entity
- add component
- add relation
- emit event
- apply trait
- spawn archetype
- run/query systems

without manually handling registry casts or container internals at every call
site.

Storage remains configurable, but it should not dominate user-facing code.

### 2.4 Storage policy must be explicit when needed

Some entity-related data will be used heavily and need dense storage.
Others will be rare and need sparse or lookup-oriented storage.

Users should be able to choose the storage policy of their data structs.
The engine should provide sensible defaults, but performance-relevant storage
choices must be available to users.

Prefer dense arrays, sparse sets, hash maps, indexed tables, and relation-specific
indexes unless profiling proves another structure is justified.

### 2.5 Separate principles from implementation plans

This reference document should stay stable and conceptual.

Use engine/world/engine_rework_roadmap.md for:

- build order
- file-level changes
- migration steps
- temporary compatibility plans
- API sketches
- unresolved implementation details

## 3. ARCHITECTURAL BOUNDARIES

### 3.1 utils

utils owns reusable primitives:

- data structures
- math
- timing primitives
- logging
- RNG utilities
- generic drawing helpers
- generic camera primitives
- UI primitives where they are not engine-world-specific
- the raylib import surface

utils should not become dependent on game concepts.

### 3.2 engine/core

engine/core owns runtime orchestration:

- Engine
- EngineState
- EngineTiming
- timing loop
- lifecycle transitions
- hooks
- configs
- frame/tick/render phase order

`EngineTiming` owns wall-clock sampling, frame pacing, base simulation-tick
pacing, queued/catch-up tick limits, forced ticks, and performance timing.

It coordinates systems. It should not own game-specific simulation data or the
World's logical simulation calendar.

### 3.3 engine/world

engine/world owns simulation infrastructure:

- World
- EntityId / entity lifecycle
- component database
- relation database
- event database
- generic rules/reactions
- generic traits/metaproperties
- generic archetypes/templates
- logical simulation time and scheduler
- query/view helpers
- context records and adapters for future save/load/replay support

This is the main target of the engine rework.

### 3.4 engine/render

engine/render owns world-facing render adapters:

- WorldCam
- world-space drawing wrappers
- sprite/world render helpers
- debug render systems

Simulation data should not depend on rendering.
Render systems read simulation data and draw it.

### 3.5 games

games own domain-specific simulation content:

- game components
- game relations
- game events
- game traits
- game archetypes
- game rules
- game-specific views and UI bindings

The engine should make these easy to define, register, inspect, and run.

## 4. DESIGN CONSTRAINTS

### 4.1 Save/load and replay are future concerns, but must not be blocked

Save/load primitives will eventually live in utils. The world layer does not
need a full save/load system immediately.

The `engine/world/context` folder is reserved for future World context records,
snapshot adapters, and save/load/replay-facing world-state descriptions. It
should remain mostly dormant until the reusable serialization/save-load
primitives exist in `utils`.

However, world architecture should avoid choices that make save/load,
deterministic replay, or debugging unnecessarily hard.

Prefer:

- ids over raw pointers as persistent truth
- table rows over hidden object graphs
- explicit phase order
- explicit event ordering
- inspectable metadata
- stable ownership boundaries

### 4.2 Simulation time is not render time

World systems should not assume frame-rate timing, but World should not replace
or duplicate the existing `EngineTiming` base-tick system.

Timing ownership should remain explicit:

1. `EngineTiming` measures elapsed real time and determines when a base simulation
   tick or render frame is due.
2. `EngineStep` consumes due base ticks and calls `World.tick(...)`.
3. `World` advances logical simulation time and executes simulation work for
   each received base tick.
4. The World scheduler runs systems, rules, and delayed events at game-defined
   logical cadences.

The World scheduler must not implement a competing `shouldTick()` loop. It runs
inside the base ticks paced by `EngineTiming`.

This separation must allow:

- a stable engine base-tick rate
- world-specific logical time scales
- systems that run every base tick
- systems that run at slower or faster logical cadences
- delayed events and temporary rules
- pausing or forcing base ticks through the existing Engine API

Changing World simulation speed should not require changing render pacing or
the Engine base-tick rate.

### 4.3 Queries and views are first-class

Simulation-heavy games need inspection and derived views.

World should eventually support queries over:

- components
- relations
- events
- traits
- archetypes

UI and debug tools should read through queries/views and emit commands/events,
not mutate simulation internals directly.

### 4.4 Data first, behavior second, rendering last

Keep the direction clear:

- data lives in components, relations, events, traits, and archetypes
- behavior lives in systems and rules
- rendering lives in render systems/adapters

This keeps simulation code testable, reusable, and inspectable.

Transient visual effects should not become entities unless they participate in
gameplay. A gameplay object that emits particles may be an entity with emitter
state, and the event that caused an effect may be world data, but individual
smoke/spark/trail particles should usually live in a render/effects pool.

Particle configuration belongs in data such as `ParticleConfigs`. Replay or
save/load paths should prefer recording the deterministic event/config/seed
that produced an effect instead of serializing every transient particle row.

## 5. TARGET SHAPE

Long-term conceptual shape:

    Engine
     |-- Core runtime
     |    |-- EngineTiming: wall clock, frame pacing, base-tick pacing
     |-- Resources
     |-- Render
     |-- UI ?
     |-- World
        |-- Logical simulation clock
        |-- Entities
        |-- Components
        |-- Relations
        |-- Events
        |-- Rules
        |-- Traits
        |-- Archetypes
        |-- Scheduler
        |-- Queries / Views

The near-term work should build toward this in small iterative steps.

The success condition is:

    A user can build a data-oriented simulation with many entities and many
    relationships, define their own simulation types cleanly, choose storage
    policies when needed, inspect what the world contains, and rely on a
    small set of generic engine examples as reference patterns.
