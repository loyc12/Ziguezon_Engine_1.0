# Engine World Rework Goals

This file is the target-state authority for the world/entity/simulation rework.
Current implementation facts belong in [reference.md](reference.md).
Implementation order belongs in [roadmap.md](roadmap.md).
Active task slices belong in [todo.md](todo.md).

## 1. Direction

The engine should be simulation-oriented, not only ECS-oriented.

The core design question is:

```text
How do we model entities, data, relationships, events, rules, and emergent
behavior in a clean, reusable way?
```

Component iteration speed matters, but simulation-heavy games also need
first-class support for:

* relationships;
* ownership;
* containment;
* history;
* rules;
* reactions;
* traits;
* archetypes;
* particles/effects;
* scheduled simulation;
* inspection and explanation.

## 2. World Target

`World` should become the central engine-owned simulation database. It should
organize:

* entity identity and lifecycle;
* component tables;
* relation tables;
* event records and queues;
* rules and reactions;
* traits and metaproperties;
* archetypes and templates;
* particle/effect records, emitters, configs, and pools;
* logical simulation time and scheduling;
* query and view helpers;
* context records for future save/load/replay-facing state.

Entities remain stable identifiers. Components, relations, events, traits,
archetypes, effects, and scheduler records are facts that make those
identifiers meaningful.

## 3. Fact Model

Components are for per-entity payload state. They should stay data-first, with
behavior in systems and rendering in render adapters. Component types must carry
entity data; dataless components are invalid.

Relations are source-target facts between meaningful entities. They should be
used for ownership, containment, membership, dependencies, links, and similar
relationships. They should not become a tag system.

Events record that something happened. Commands request change; events prove
that a change or occurrence was recorded. Event payloads should stay plain
queueable facts, with obvious invalid event shapes rejected when practical.

Traits/metaproperties are the canonical dataless classification path for tags,
labels, flags, and presence-style facts. Traits may eventually have type-level
metadata, but they must not hold per-entity payload data. Do not add
marker-component support as the main classification mechanism.

Archetypes/templates create reusable bundles of initial facts. Archetype
definitions are not entity rows unless explicitly stored as facts.

Queries/views are transient inspection helpers. They should not become hidden
owners of simulation facts.

Rules/reactions observe facts and emit commands, events, fact changes, or
effect triggers.

## 4. User-Facing Shape

Engine users should be able to express common simulation operations without
manually handling registry casts or container internals:

* create entity;
* add component;
* add relation;
* emit event;
* apply trait;
* spawn archetype;
* trigger effect;
* run/query systems.

Storage policy remains configurable, but it should not dominate ordinary
game-facing code. Add policies and policy bundles only when a concrete use case
needs them.

## 5. Storage And Policies

Some fact families need packed storage. Others need sparse or lookup-oriented
storage. Users should be able to choose performance-relevant storage policies
explicitly on their payload or fact definitions.

Prefer:

* packed arrays;
* sparse sets;
* hash maps;
* indexed tables;
* relation-specific indexes.

Use a single enum policy when there is one behavior axis. Introduce config
structs only when multiple independent choices need to travel together. Do not
add policies or configs preemptively.

Dataless facts should be queried through presence APIs. Payload retrieval APIs
should reject zero-sized payloads. Traits should use presence APIs only.

## 6. Time And Scheduling

`EngineTiming` remains the base-tick and frame-pacing authority.

`World` receives consumed base ticks through `World.tick(...)`, advances
logical simulation time, and runs scheduled work inside that boundary. The
World scheduler must not implement a competing base-tick loop.

The target scheduler should support:

* systems that run every base tick;
* systems that run at slower or faster logical cadences;
* delayed events;
* temporary rules;
* game-defined logical time scales.

## 7. Effects And Particles

Particles and effects should be first-class engine systems, but not ordinary
entities by default.

Persistent gameplay objects that emit or receive effects may be entities.
Individual smoke, sparks, dust, trails, and similar transient visuals should
usually live in dedicated particle/effect pools unless they need entity
identity, relations, rules, query visibility, save/load state, or gameplay
interaction.

Effect playback should be driven from world facts, commands, events, rules, and
deterministic seeds when replay/debug paths need them.

## 8. Boundaries

`utils` owns reusable primitives: data structures, math, timing helpers,
logging, RNG utilities, generic drawing helpers, generic camera primitives,
generic UI primitives, and the raylib import surface.

`engine/core` owns runtime orchestration: `Engine`, lifecycle, timing loop,
base-tick/frame pacing, hooks, configs, and phase order.

`engine/world` owns simulation infrastructure: `World`, entities, components,
relations, events, rules, traits, archetypes, particle/effects records and
pools, logical simulation time, scheduling, queries/views, and future context
records.

`engine/render` owns world-facing render adapters and debug render systems.
Simulation facts should not depend on rendering.

`games` owns game-specific components, relations, events, traits, rules,
archetypes, effect configs, views, and UI bindings.

## 9. Generic Examples

Core engine systems should include only minimal generic examples that help users
copy patterns:

* at least one component type;
* at least one relation type;
* at least one event type;
* at least one trait/metaproperty type, such as `Persistent`;
* at least one archetype/template;
* at least one rule/reaction example;
* at least one particle/effect example.

Do not grow a large built-in content library inside the engine.

## 10. Success Condition

A user can build a fact-oriented simulation with many entities and many
relationships, define their own simulation types cleanly, choose storage
policies when needed, drive first-class effects from world facts, inspect what
the world contains, and rely on a small set of generic engine examples as
reference patterns.
