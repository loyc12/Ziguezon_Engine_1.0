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
* RuleSets;
* particles/effects;
* scheduled simulation;
* inspection and explanation.

## 2. World Target

The engine should own simulation through `WorldManager`. `WorldManager` should
wrap one concrete `World` for now, while keeping the public shape ready for
later multi-world ownership without making games own concrete storage details.

The concrete `World` should remain the central simulation database under
`world/core/`. It should organize:

* entity identity and lifecycle;
* component tables;
* relation tables;
* event records and queues;
* rules and reactions;
* traits and metaproperties;
* archetypes;
* RuleSets;
* particle/effect records, emitters, configs, and pools;
* logical simulation time and scheduling;
* query and view helpers;
* future archive records for save/load/replay.

Entities remain stable identifiers. Components, relations, events, traits,
archetypes, effects, and scheduler records are facts that make those
identifiers meaningful.

## 3. Fact Model

Components are for per-entity payload state. They should stay data-first, with
behavior in rules and rendering in render adapters. Component types must carry
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

Archetypes create reusable data-only bundles of initial facts. Archetype
definitions are not entity rows unless explicitly stored as facts, and they do
not register executable logic as part of spawning.

Queries/views are transient inspection helpers. They should not become hidden
owners of simulation facts. `WorldQuery` should stay a stateless helper
namespace that receives the inspected World explicitly.

Rules/reactions observe facts and request changes through explicit world-owned
phase boundaries. `World` owns registered rule storage through a focused
`RuleManager`; rules receive a short-lived rule-only context backed by
World-owned manager pointers, not persistent `World` ownership. Rule contexts
should stay simple pointer bundles rather than duplicate broad manager helper
APIs unless a helper removes real ambiguity.

The default change path should be command emission followed by deterministic
command execution. Rules are not required to emit commands; a rule may inspect
state, validate invariants, emit suitable events/effect triggers, or request no
work at all. Direct fact mutation from rule code should stay exceptional and
documented when a specific phase owns it.

Commands are plain requested-change facts with execution registered alongside
their typed command queue. A command execution callback receives a short-lived
command-only context and a command record, then returns success or failure.
Command contexts should mirror the narrow manager-pointer pattern instead of
borrowing `RuleContext` or future archive machinery. Command execution should
pop attempted commands before running callbacks, log execution failures,
continue through later commands of the same type, and leave delayed, pending,
retry, undo, replay, and cross-type aggregate execution behavior for later
design passes.

`RuleSet` is the planned name for reusable groups of rule declarations; it is
the logic-side counterpart to data-side archetypes, not another name for
archetypes.

## 4. User-Facing Shape

Engine users should be able to express common simulation operations without
manually handling registry casts or container internals:

* create entity;
* add component;
* add relation;
* emit event;
* apply trait;
* spawn archetype;
* enqueue and execute commands;
* trigger effect;
* run/query rules or RuleSets.

Storage policy remains configurable, but it should not dominate ordinary
game-facing code. Add policies and policy bundles only when a concrete use case
needs them.

## 5. Runtime Cost Model

World features should follow a no-registration, minimal-runtime-cost rule. If a
game has not registered a component store, relation store, trait set, event
queue, command queue, RuleSet, scheduler item, effect pool, archetype registry,
or archive feature, normal per-tick runtime should not scan, update, dispatch,
or retain work for that feature.

Small setup and teardown costs are acceptable when initializing managers,
registering typed stores, unregistering typed stores, or deinitializing the
World. Runtime cost during normal play should scale mainly with the features a
game explicitly registered and the rows or queued records it actually owns.

## 6. Storage And Policies

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

## 7. Time And Scheduling

`EngineTiming` remains the base-tick and frame-pacing authority.

`World` receives consumed base ticks through `World.tick(...)`, advances
logical simulation time, and runs scheduled work inside that boundary. The
World scheduler must not implement a competing base-tick loop.

An empty or unused scheduler should add only minimal per-tick bookkeeping.

The target scheduler should support:

* rules that run every base tick;
* deterministic command execution after rules request changes;
* rules or RuleSets that run at slower or faster logical cadences;
* delayed events;
* temporary rules;
* game-defined logical time scales.

## 8. Effects And Particles

Particles and effects should be first-class engine features, but not ordinary
entities by default.

Persistent gameplay objects that emit or receive effects may be entities.
Individual smoke, sparks, dust, trails, and similar transient visuals should
usually live in dedicated particle/effect pools unless they need entity
identity, relations, rules, query visibility, save/load state, or gameplay
interaction.

Effect playback should be driven from world facts, commands, events, rules, and
deterministic seeds when replay/debug paths need them.

## 9. Boundaries

`utils` owns reusable primitives: data structures, math, timing helpers,
logging, RNG utilities, generic drawing helpers, generic camera primitives,
generic UI primitives, and the raylib import surface.

`engine/core` owns runtime orchestration: `Engine`, lifecycle, timing loop,
base-tick/frame pacing, hooks, configs, and phase order.

`engine/world` owns simulation infrastructure: `World`, entities, components,
relations, events, rules, RuleSets, traits, archetypes, particle/effects
records and pools, logical simulation time, scheduling, queries/views, future
archive records, and the `WorldManager` facade that the engine owns.

`engine/render` owns world-facing render adapters and debug render systems.
Simulation facts should not depend on rendering.

`games` owns game-specific components, relations, events, traits, rules,
RuleSets, archetypes, effect configs, views, and UI bindings.

## 10. Generic Examples

Core engine surfaces should include only minimal generic examples that help users
copy patterns:

* at least one component type;
* at least one relation type;
* at least one event type;
* at least one trait/metaproperty type, such as `Persistent`;
* at least one archetype;
* at least one rule/reaction example;
* at least one RuleSet example once grouped rule registration exists;
* at least one particle/effect example.

Do not grow a large built-in content library inside the engine.

## 11. Success Condition

A user can build a fact-oriented simulation with many entities and many
relationships, define their own simulation types cleanly, choose storage
policies when needed, drive first-class effects from world facts, inspect what
the world contains, and rely on a small set of generic engine examples as
reference patterns.
