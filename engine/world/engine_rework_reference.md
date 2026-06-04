# ENGINE REWORK REFERENCE - ZIGUEZON ENGINE

## Purpose

This document records the core goals, principles, and boundaries for the
world/entity/simulation layer of Ziguezon Engine.

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
- event records / event queues
- rules and reactions
- traits / metaproperties
- archetypes / templates
- simulation scheduling
- query and view helpers

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

Archetypes/templates create bundles of initial facts.

Engine examples should stay generic:

- Selectable
- Visible
- Simulated
- Container
- Indexed

Avoid assuming a particular game genre in engine-level traits or archetypes, only that it is a simulation game.

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

Game-specific components, relations, events, traits, rules, and archetypes belong under games/

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

Users should be able to choose the storage policy of their data structs,
for example with a declaration on the type passed to the store generator:

    pub const storeType = .dense;

or:

    pub const storeType = .sparse;

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
- timing loop
- lifecycle transitions
- hooks
- configs
- frame/tick/render phase order

It coordinates systems. It should not own game-specific simulation data.

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
- simulation scheduler
- query/view helpers

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

World systems should not assume frame-rate timing.

The architecture must allow different simulation cadences:

- frame update
- fixed simulation tick
- scheduled systems
- delayed events
- game-defined time scales

The first implementation can be simple. The design should still leave room for
multi-cadence simulations.

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

## 5. TARGET SHAPE

Long-term conceptual shape:

    Engine
     |-- Core runtime
     |-- Resources
     |-- Render
     |-- UI ?
     |-- World
        |-- Entities
        |-- Components
        |-- Relations
        |-- Events
        |-- Rules
        |-- Traits
        |-- Archetypes
        |-- Scheduler
        |-- Queries / Views

The near-term work should build toward this in small steps:

 1. Add World as the owner/interface for entity and component storage.
 2. Rework component storage so users can choose dense/sparse policies.
 3. Add relations as one of the first major World extensions.
 4. Add events, rules, traits, archetypes, scheduler, and query helpers
    progressively, with minimal generic examples for each.

The success condition is not "the engine has a pure ECS".

The success condition is:

    A user can build a data-oriented simulation with many entities and many
    relationships, define their own simulation types cleanly, choose storage
    policies when needed, inspect what the world contains, and rely on a
    small set of generic engine examples as reference patterns.
