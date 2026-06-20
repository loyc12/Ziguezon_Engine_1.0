# Engine World Rework Reference

This file is the descriptive baseline for the current world/entity/simulation
implementation. Target design belongs in
[goals.md](goals.md). Implementation order belongs in [roadmap.md](roadmap.md).
Active task slices belong in [todo.md](todo.md).

## 1. Purpose

`src/engine/world` owns the engine's simulation infrastructure. The current
implementation is already beyond the original component-only foundation:
entities, components, relations, traits, event queues, command queues, and
compact rules are live. Several later folders still contain placeholders for
future features.

When this file disagrees with code, inspect code first and refresh this file.

## 2. Current Public Shape

The main runtime surface is `World` in `worldManager.zig`.

`World` currently owns:

* active entity tracking;
* an `EntityIdRegistry`;
* `CompManager`;
* `RelationManager`;
* `TraitManager`;
* `EventManager`;
* `CommandManager`;
* `ArchetypeManager`;
* component-view generation tracking.

`World.init()` initializes entity tracking and fact managers. `World.deinit()`
releases registered stores, invalidates entity ids, and bumps the component
view generation.

## 3. Entities

Entities are stable ids created through `World.createEntity()`.

`World` tracks live ids in `activeEntities`. Entity id `0` is invalid. World
operations that attach or inspect facts reject dead entities.

`World.destroyEntity()` currently:

* rejects uninitialized, invalid, and dead ids;
* removes relation facts for the entity first;
* removes component facts for the entity after relation cleanup;
* removes trait facts before invalidating the entity id;
* removes the id from the live set;
* emits `EntityDestroyed` when that event type is registered.

`EntityCreated` is emitted when creation succeeds and that event type is
registered.

## 4. Components

Component storage is registered by payload type with `World.registerComp()`.
Duplicate or unregistered operations fail instead of silently creating stores.

Component types must declare:

```zig
pub const compStorePolicy : eng.CompStorePolicy = .PACKED;
```

Current policies:

* `.PACKED` for array-backed storage with an entity-to-row index;
* `.SPARSE` for hash-map storage.

Zero-sized component payloads are rejected. Use traits/metaproperties for
classification instead of empty marker components.

World component APIs include:

* `registerComp`;
* `unregisterComp`;
* `getCompStore`;
* `getCompView`;
* `getCompViewGeneration`;
* `addComp`;
* `getComp`;
* `getCompConst`;
* `hasComp`;
* `removeComp`.

Component add/remove emits generic component events when those event queues are
registered.

## 5. Component Views

`CompView` is a transient typed view over registered component stores. Views
cache store pointers and use `World.viewGeneration` to detect invalidation
after component store registration changes.

Views remain component-only. They are not the broad query surface for relations,
events, traits, archetypes, or history.

Read-only component view helpers include `getConst` and `iteratorConst`.
Mutable `get` and `iterator` remain available for logic that intentionally edits
component rows.

## 6. Queries

`WorldQuery` in `queries/query.zig` is the broad read-only inspection facade.
It is transient and wraps an initialized `World`; it does not own facts, cache
mutable store state, retain event history, or replace `CompView`.

Current query helpers cover:

* entity liveness through `hasEntity`;
* component presence and read-only point lookup through `hasComp` and
  `getComp`;
* component view validation through `isCompViewValid`, `hasViewComp`, and
  `getViewComp`;
* relation presence, read-only payload lookup, and source/target traversal
  through `hasRelation`, `getRelation`, `getRelationsFrom`, and
  `getRelationsTo`;
* trait presence and read-only entity-id traversal through `hasTrait` and
  `getTraitEntityIterator`;
* event count, indexed peek, and queue traversal through `getEventCount`,
  `peekEvent`, and `getEventIterator`.

Unsupported broad-query shapes are rejected explicitly by
`rejectUnsupportedBroadQuery`; archetype query integration, particle/effect,
command, scheduler, and save/load query integration are still outside the live
surface.

## 7. Relations

Relations are live as typed source-target fact stores.

`RelationStoreFactory(RelType)` currently stores relation rows by `RelationKey`
and maintains source and target indexes for lookup. Relation types may be:

* payload-bearing structs;
* dataless zero-sized facts queried through `has`;
* policy-constrained by `cardinalityPolicy`.

Current cardinality policies support many-to-many, many-to-one, one-to-many,
and one-to-one shapes.

World relation APIs include:

* `registerRelation`;
* `unregisterRelation`;
* `getRelationStore`;
* `addRelation`;
* `getRelation`;
* `getRelationConst`;
* `hasRelation`;
* `removeRelation`;
* `getRelationsFrom`;
* `getRelationsTo`.

Adding a relation requires both endpoints to be live. Removing or destroying an
entity cleans relation rows that reference it. Generic relation events are
emitted when those event queues are registered.

## 8. Events

Events are live as typed transient queues.

`EventRecord(EventType)` stores:

* event metadata;
* the plain Zig event payload.

Event payload types must be structs. Dataless event structs are valid.

`EventMeta` tracks:

* monotonic event sequence;
* order within the current World tick;
* base tick index when known;
* inferred primary entity when available.

`EventManager` owns registered queues by event payload type. Events are emitted
only after their queue type is registered.

World event APIs include:

* `registerEvent`;
* `unregisterEvent`;
* `getEventQueue`;
* `emitEvent`;
* `popEvent`;
* `peekEvent`;
* `getEventIterator`;
* `clearEvents`;
* `getEventCount`.

Generic event payloads currently include entity, component, relation, and trait
event types. Event queues are transient; retained event history is not
implemented.

## 9. Commands

Commands are live as typed transient requested-change queues.

`CommandRecord(CommandType)` stores:

* command metadata;
* the plain Zig command payload.

Command payload types must be structs. Dataless command structs are valid for
signal-style requests. Commands describe requested future changes; they are not
completed-event records and do not own execution behavior.

`CommandMeta` tracks:

* monotonic command sequence;
* order within the current World tick;
* base tick index when known.

`CommandManager` owns registered queues by command payload type. Commands are
enqueued only after their queue type is registered.

World command APIs include:

* `registerCommand`;
* `unregisterCommand`;
* `getCommandQueue`;
* `enqueueCommand`;
* `popCommand`;
* `peekCommand`;
* `getCommandIterator`;
* `clearCommands`;
* `getCommandCount`.

Command queues are transient. Retained command history, replay, undo, delayed
commands, and command execution ownership are not implemented.

## 10. Traits

Traits are live as dataless typed classification facts.

`TraitSetFactory(TraitType)` stores entity-id presence only. Trait declarations
must be empty zero-sized struct types. Field-bearing or payload-bearing trait
types are rejected at compile time; per-entity data belongs in components.

The generic engine trait example is:

* `Persistent`, marking entities whose related facts should be save-relevant
  once save/load exists.

World trait APIs include:

* `registerTrait`;
* `unregisterTrait`;
* `getTraitSet`;
* `applyTrait`;
* `hasTrait`;
* `removeTrait`;
* `getTraitEntityIterator`.

Applying or removing a trait requires the entity to be live. Destroying an
entity removes its trait rows before the entity id is invalidated. Generic
trait events are emitted when those event queues are registered.

Use these selection rules:

* components for per-entity payload state;
* relations for source-target facts between entities;
* traits for dataless classification, flags, tags, and presence facts;
* events for queued records that something happened;
* commands for queued requests that something should change.

## 11. Archetypes

Archetypes are live as data-only reusable bundles of initial World facts.

`Archetype` is a declaration with:

* `name`, the stable registration key;
* `spawnFn`, a callback that receives `*ArchetypeSpawnContext` and returns
  whether initial fact attachment succeeded.

`ArchetypeSpawnContext` lives in `archetypes/spawnContext.zig` and is wired to
the concrete `World` type by `worldManager.zig`. It intentionally exposes only:

* `createEntity`;
* `setRootEntity`;
* `reportEntity`;
* `addComp`;
* `addRelation`;
* `applyTrait`.

Archetype callbacks may create entities, attach components, add relations, and
apply traits through those helpers. They must not enqueue commands, register
rules, register RuleSets, add scheduler behavior, or emit archetype-specific
spawn events.

Spawn callbacks should treat helper failures as fatal. The context records
failed helper calls, and `World.spawnArchetype()` rejects the result when a
helper failed, the root entity is missing, or a reported id was not created by
that spawn.

`ArchetypeSpawnResult` exposes:

* `rootId`, the primary created entity;
* up to `MAX_REPORTED_SPAWN_IDS` named entity ids for additional created
  entities.

Failed spawns destroy every entity created by that archetype callback through
normal `World.destroyEntity()` cleanup before returning `null`.

`ArchetypeManager` owns registered declarations by name. Duplicate names,
empty names, and uninitialized registration or lookup fail cleanly. The manager
does not own game-specific payload data and does not add tick work when no
archetypes are registered.

World archetype APIs include:

* `registerArchetype`;
* `spawnArchetype`;
* `getArchetypeCount`.

`PersistentLinkArchetype` in `archetypes/baseArchetypes.zig` is the minimal
generic engine example. It creates two entities, applies `Persistent` to both,
links the root to the second entity with `LinkedTo`, and reports the second id
as `"linked"`.

Archetype spawning uses the existing World fact APIs, so registered generic
entity/component/relation/trait event queues may still receive the ordinary
fact events those APIs emit. There is no separate archetype-spawn event in the
live surface.

## 12. Rules

Rules are live as compact explicit simulation-logic callbacks.

`RuleContext` passes:

* transient read-only `WorldQuery` access, including component/relation/trait
  inspection and event peeking/iteration;
* a `CommandManager` pointer for enqueuing requested changes.

`Rule` stores a name, order value, and callback. `RuleManager` owns an ordered
list of these declarations and runs them through explicit `runAll(world)` calls.
Lower `order` values run first; duplicate names are rejected.

Rules cover both broad current-fact passes and event/fact reactions. They may
observe queued events or current queried facts and enqueue commands. Peeking and
iterating events through rules does not consume event records.

Rules do not mutate broad query results through the rule surface. `World` does
not own or automatically run a rule manager yet; cadence, phases, broad rule
graph ownership, temporary rules, and scheduler integration are future work.

`RuleSet` is the planned name for reusable groups of executable rule
declarations. A RuleSet should be a logic grouping and registration helper, not
an archetype, not a second callback primitive, and not an owner of entity fact
rows.

## 13. Timing

`TickInfo` is the timing snapshot passed into World once per consumed engine
base tick. It includes:

* base tick index;
* target delta;
* measured delta;
* forced-tick flag.

`World.tick(...)` begins event and command tick metadata for the base tick.
World does not own base-tick pacing; that remains an engine timing
responsibility.

## 14. Future Placeholders

The following folders or files are currently placeholders or minimal notes:

* `scheduler`;
* `particles`;
* `context`.

These should not be described as complete features until code and tests exist.

## 15. Boundaries

`engine/world` owns simulation facts and fact managers. It should not depend on
game-specific concepts or rendering-specific behavior.

Rendering should read simulation facts through render adapters. Games own their
domain-specific components, relations, events, traits, archetypes, rules,
RuleSets, and views.

## 16. Validation

Docs-only changes need no build.

World implementation changes should normally run:

* `zig build`;
* `zig build test`.

Do not run formatting passes such as `zig fmt`.
