# Engine World Rework Reference

This file is the descriptive baseline for the current world/entity/simulation
implementation. Target design belongs in
[goals.md](goals.md). Implementation order belongs in [roadmap.md](roadmap.md).
Active task slices belong in [todo.md](todo.md).

## 1. Purpose

`src/engine/world` owns the engine's simulation infrastructure. The current
implementation is already beyond the original component-only foundation:
entities, components, relations, and event queues are live. Several later
folders still contain placeholders for future systems.

When this file disagrees with code, inspect code first and refresh this file.

## 2. Current Public Shape

The main runtime surface is `World` in `worldManager.zig`.

`World` currently owns:

* active entity tracking;
* an `EntityIdRegistry`;
* `CompManager`;
* `RelationManager`;
* `EventManager`;
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

Zero-sized component payloads are rejected. Use future traits/metaproperties for
classification instead of empty marker components.

World component APIs include:

* `registerComp`;
* `unregisterComp`;
* `getCompStore`;
* `getCompView`;
* `getCompViewGeneration`;
* `addComp`;
* `getComp`;
* `hasComp`;
* `removeComp`.

Component add/remove emits generic component events when those event queues are
registered.

## 5. Component Views

`CompView` is a transient typed view over registered component stores. Views
cache store pointers and use `World.viewGeneration` to detect invalidation
after component store registration changes.

Current views are component-only. They are not the future broad query system for
relations, events, traits, archetypes, or history.

## 6. Relations

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
* `hasRelation`;
* `removeRelation`.

Adding a relation requires both endpoints to be live. Removing or destroying an
entity cleans relation rows that reference it. Generic relation events are
emitted when those event queues are registered.

## 7. Events

Events are live as typed transient queues.

`EventRecord(EventType)` stores:

* event metadata;
* the plain Zig event payload.

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
* `clearEvents`;
* `getEventCount`.

Generic event payloads currently include entity, component, and relation event
types. Event queues are transient; retained event history is not implemented.

## 8. Timing

`TickInfo` is the timing snapshot passed into World once per consumed engine
base tick. It includes:

* base tick index;
* target delta;
* measured delta;
* forced-tick flag.

`World.tick(...)` begins event tick metadata for the base tick. World does not
own base-tick pacing; that remains an engine timing responsibility.

## 9. Placeholder Systems

The following folders or files are currently placeholders or minimal notes:

* `commands`;
* `systems`;
* `rules`;
* `traits`;
* `archetypes`;
* `queries`;
* `views` beyond component views;
* `scheduler`;
* `particles`;
* `context`.

These should not be described as complete systems until code and tests exist.

## 10. Tilemap

The older tilemap path still lives under `src/engine/world/tilemap`. It is not
the main fact-oriented World rework surface. Do not use tilemap code as proof
that the new World relation/event/trait systems are complete.

## 11. Boundaries

`engine/world` owns simulation facts and fact managers. It should not depend on
game-specific concepts or rendering-specific behavior.

Rendering should read simulation facts through render adapters. Games own their
domain-specific components, relations, events, traits, archetypes, systems, and
views.

## 12. Validation

Docs-only changes need no build.

World implementation changes should normally run:

* `zig build`;
* `zig build test`.

Do not run formatting passes such as `zig fmt`.
