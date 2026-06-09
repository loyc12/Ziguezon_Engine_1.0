# ENGINE REWORK TODO

Action checklist for the next implementation slice of the world/entity/simulation
rework.

Architectural intent lives in `engine_rework_reference.md`. Implementation
sequence lives in `engine_rework_roadmap.md`. If this todo conflicts with either
file, the reference takes precedence first, then the roadmap.


## 0. Current State

Phase 1 completed the World-owned component foundation.
Phase 2 completed entity lifecycle and component cleanup.
Phase 3 completed first-class relation storage:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation, active entity tracking, and destruction.
* `World.destroyEntity(id)` removes that id from relation stores first, then
  registered component stores.
* `World.addComp`, `World.getComp`, `World.hasComp`, and `World.removeComp`
  reject dead or never-created entity ids.
* Packed and sparse component stores are implemented.
* Component types must declare an explicit `compStorePolicy`.
* Component views remain transient typed store-access helpers.
* `World.registerRelation`, `World.addRelation`, `World.getRelation`,
  `World.hasRelation`, and `World.removeRelation` are implemented.
* Relation stores support payload-bearing and dataless source-target facts,
  source queries, target queries, exact lookup, removal, and destruction cleanup.
* `EngineStep` forwards each consumed base tick through `World.tick(TickInfo)`.
* Generic World-owned event records/queues, rules, traits, archetypes,
  particle/effects systems, logical scheduling, broad queries, and world context
  remain deferred.

Preliminary cleanup already completed:

* `World` has small private helpers for fact-manager init/deinit and
  entity-fact cleanup.
* Relation endpoint validation now goes through one `World` helper.
* `Engine` no longer owns or initializes the legacy callback `EventManager`.
* `engineDef.zig` no longer exports the legacy `Event`, `EventType`,
  `EventData`, listener, or queue aliases.
* No current game code used the legacy engine event API. Remaining event usage
  is UI-local, docs/todo text, or the dormant legacy event source files waiting
  for the Phase 4 rewrite.

The requested trait/metaproperty system is not the next unblocked slice under
the roadmap. Traits should be implemented after generic events and a minimal
rule/reaction layer exist, because traits need to emit/record `TraitApplied` and
`TraitRemoved` facts and rules need to observe traits without a second
classification path.


## 1. Slice Scope

### Phase 4: Generic World-Owned Event Records And Queues

Replace the legacy fixed event union/callback manager with the first generic
event foundation owned by `World`.

This phase is complete when:

* `engine/world/events/event.zig` defines generic event concepts for
  user-defined event types.
* `engine/world/events/eventQueue.zig` owns transient typed event queues.
* `engine/world/events/eventManager.zig` registers typed event queues and
  provides the World-facing event API.
* `engine/world/events/eventLog.zig` remains a small optional-retention
  boundary, not a full replay/history implementation.
* `World` initializes, deinitializes, and exposes event registration and event
  emission/drain operations.
* Events can record generic entity-related facts such as entity creation,
  entity destruction, component changes, relation changes, and future trait
  changes.
* Event processing order is explicit and tied to `World.tick(TickInfo)`.
* Existing game-facing event behavior is either preserved behind compatibility
  code or intentionally left untouched until a separate migration slice.
* No rule, trait, archetype, scheduler, broad query, context, or particle/effects
  implementation is started.


## 2. Fixed Decisions

* Keep `engine_rework_reference.md` as the architectural guide.
* Keep `engine_rework_roadmap.md` as the implementation-sequencing guide.
* Keep this slice focused on events only.
* Events record change. Commands request change; callbacks are observers, not
  the event model itself.
* Event types should be user-defined plain Zig structs, not a fixed engine enum
  with a large generic data union.
* Engine-level event examples must stay minimal and generic.
* World-owned events should carry enough metadata to inspect what happened
  without assuming a particular game domain.
* Transient queues are enough for the first event slice.
* Optional retained history must remain possible, but full history, replay, and
  audit tooling are deferred.
* Trait work is blocked until this slice and the minimal rule/reaction slice are
  complete.
* Do not use marker components as a temporary classification workaround.
* Do not add trait-like relation tags while waiting for traits.


## 3. Recommended Shape

This section is a practical target, not a requirement if the code argues for a
smaller equivalent.

### 3.1 Event Type Contract

User-defined event fact types should be plain Zig structs owned by typed event
queues.

Likely shape:

    pub const EntityDestroyed = struct
    {
      entityId : EntityId = 0,
    };

Event fact types may be dataless only when existence and ordering are the whole
fact. Most useful generic engine events should carry at least the affected
entity id or relation endpoints.

Add event metadata only where the first slice needs it:

* monotonically increasing event sequence or tick-local order;
* optional `TickInfo` snapshot or base tick index;
* optional primary entity id;
* no real-time ownership changes outside `EngineTiming`.

### 3.2 Event Queue

Implement a typed transient queue that can append and drain events in insertion
order.

Target operations:

    push( value )
    pop()
    drain(...)
    clear()
    count()

Prefer simple array-backed storage for the first slice. Avoid linked-list queues
unless a real profile proves the array-backed path is a problem.

### 3.3 Event Manager

`EventManager` should mirror the useful registration/lifecycle pattern from
`CompManager` and `RelationManager` without preserving the old fixed enum
surface as the core model.

Likely shape:

* allocator-backed lifecycle;
* string-keyed typed queue registry using `@typeName(EventType)`;
* erased deinit callback;
* `register(EventType)` / `unregister(EventType)`;
* `getQueue(EventType)`;
* `emit(EventType, value)`;
* `pop(EventType)` or a focused drain API;
* optional retained-log callback hook, if it stays small.

### 3.4 World API

The public World event surface should be small and explicit:

    registerEvent(EventType)
    unregisterEvent(EventType)
    emitEvent(EventType, value)
    popEvent(EventType)
    clearEvents(EventType)

World event APIs should reject uninitialized worlds and unregistered event types
predictably. Events that reference entities should not claim a dead or
never-created entity is alive; validation helpers can be added once the event
metadata shape is clear.

`World.tick(TickInfo)` should be the eventual processing boundary. The first
event slice may only store the tick context and drain explicit queues, but it
must not add another timing loop.

### 3.5 Minimal Engine Examples

Add only the minimal generic event examples needed for tests and reference
usage. Prefer examples such as:

* `EntityCreated`
* `EntityDestroyed`
* `ComponentAdded`
* `ComponentRemoved`
* `RelationAdded`
* `RelationRemoved`

Defer `TraitApplied` and `TraitRemoved` until the trait slice begins, but leave
the event model ready for them.


## 4. Phase 4 Checklist

### 4.1 Inventory And Compatibility

- [x] Inspect current `event.zig`, `eventManager.zig`, `eventQueue.zig`, and
      `eventLog.zig`.
- [x] Find all imports and call sites for the legacy `EventType`, `EventData`,
      `Event`, and callback subscription API.
- [x] Decide whether the legacy callback event manager remains as compatibility
      surface for games during this slice or is removed immediately.
- [x] Confirm the event implementation does not require trait, rule, archetype,
      scheduler, query, context, or particle/effects code.
- [x] Choose final names consistent with existing style, preferably
      `registerEvent`, `emitEvent`, and `popEvent`.

### 4.2 Event Concepts

- [x] Replace or isolate the fixed engine-specific `EventType` enum.
- [x] Replace or isolate the fixed generic `EventData` union.
- [x] Define a generic event metadata type if the first API needs it.
- [x] Define minimal generic engine event examples.
- [x] Decide whether dataless event facts are allowed in this slice.
- [x] Keep game-specific event payloads under `games/`.
- [x] Add tests for metadata ordering and basic event construction if those
      types have non-trivial logic.

### 4.3 Event Queue

- [x] Implement typed event queue initialization and deinitialization.
- [x] Add event push/pop/count/clear operations.
- [x] Preserve insertion order.
- [x] Add explicit drain behavior if it is needed by `World.tick`.
- [x] Keep retained-history behavior out of the queue unless it is only a small
      callback/hook.
- [x] Add tests for push/pop order, empty pop, clear, and deinit cleanup.

### 4.4 Event Manager

- [x] Add allocator-backed `EventManager` lifecycle.
- [x] Add typed event-queue registration.
- [x] Add typed event-queue unregistration.
- [x] Add typed event-queue lookup.
- [x] Add erased queue deinit/destroy callback.
- [x] Add manager-level emit and pop/drain helpers.
- [x] Preserve duplicate event registration rejection.
- [x] Add tests for registration, lookup, unregister, duplicate rejection, and
      deinit cleanup.

### 4.5 World Integration

- [x] Add `eventManager` ownership to `World`.
- [x] Initialize event storage in `World.init`.
- [x] Deinitialize event storage in `World.deinit`.
- [x] Add `World.registerEvent` and `World.unregisterEvent`.
- [x] Add `World.getEventQueue` only if direct queue access is useful.
- [x] Add `World.emitEvent`.
- [x] Add `World.popEvent` or a focused drain API.
- [x] Emit minimal generic entity/component/relation events only if that does
      not distort the first slice.
- [x] Keep event processing tied to `World.tick(TickInfo)`.
- [x] Add tests for event operations on uninitialized worlds and unregistered
      event queues.

### 4.6 Legacy Game Touchpoints

- [x] Build an inventory of current game event usage.
- [x] Avoid migrating game domain events unless needed to keep builds passing.
- [x] Keep compatibility code compact if legacy callbacks are temporarily
      preserved.
- [x] Record any intentional incompatibility in this todo before finishing the
      phase.

### 4.7 Documentation Updates

- [x] Update `engine_rework_roadmap.md` only if implementation choices change
      the sequence or expose a contradiction.
- [x] Append completion notes to this todo when Phase 4 is finished.
- [x] Record the final event type contract.
- [x] Record the final queue/manager shape.
- [x] Record the final World event API names.
- [x] Record whether legacy callback events were preserved, moved, or removed.
- [x] Record validation commands and results.

### 4.8 Validation

- [x] Run `zig build`.
- [x] Run `zig build check_games`.
- [x] Run `zig build test`.
- [x] Run any focused game build touched by event compatibility work.
- [x] Confirm no rule/trait/archetype/scheduler/broad-query implementation was
      added.
- [x] Confirm no first-class particle/effects implementation was added.
- [x] Do not run a formatting pass.

### 4.9 Completion Notes

Phase 4 is implemented.

Final event contract:

* Event fact types are user-defined plain Zig structs.
* `EventMeta` stores `sequence`, `tickOrder`, optional `baseTickIndex`, and
  optional `primaryEntity`.
* `EventRecord(EventType)` stores metadata plus the typed event value.
* Dataless event facts are allowed.
* Minimal generic engine events now exist: `EntityCreated`,
  `EntityDestroyed`, `ComponentAdded`, `ComponentRemoved`, `RelationAdded`,
  and `RelationRemoved`.
* Game-specific payloads remain outside the engine event modules.

Final queue and manager shape:

* `EventQueueFactory(EventType)` owns transient array-backed typed records and
  supports `push`, `pushRecord`, `pop`, `count`, `clear`, `init`, and `deinit`.
* `EventManager` owns a string-keyed typed queue registry using
  `@typeName(EventType)`.
* `EventManager` supports `register`, `unregister`, `getQueue`, `hasQueue`,
  `emit`, `pop`, `clear`, `count`, `clearAll`, `countAll`, and `beginTick`.
* Queue destruction is erased through stored deinit/destroy callbacks.
* `eventLog.zig` contains only a small optional bounded retention boundary via
  `EventLogFactory(EventType)`; replay/history/audit tooling remains deferred.

Final World API:

* `World.registerEvent(EventType)`
* `World.unregisterEvent(EventType)`
* `World.getEventQueue(EventType)`
* `World.emitEvent(EventType, value)`
* `World.popEvent(EventType)`
* `World.clearEvents(EventType)`
* `World.getEventCount(EventType)`

`World.tick(TickInfo)` now establishes the event tick metadata boundary by
recording the current `baseTickIndex` and resetting tick-local event order.
The first slice does not add a drain loop because no rule/reaction processor
exists yet.

Generic entity/component/relation events are emitted only when the relevant
event queue has been registered. Entity destruction cleanup still removes
relations before components; it does not synthesize per-store cleanup events
because the current erased cleanup callbacks do not expose typed row details.

Legacy callback event compatibility:

* The legacy fixed `EventType` enum, `EventData` union, `Event` record,
  listener structs, callback subscription API, and single fixed queue were
  removed from the active engine event modules.
* No compatibility shim was preserved because the inventory found no current
  game call sites for the legacy engine event API.
* UI-local events under `src/utils/ui` were intentionally left untouched.

Roadmap update:

* `engine_rework_roadmap.md` did not need changes; this implementation follows
  the existing Phase 4 sequence and exposed no roadmap/reference contradiction.

Validation:

* `zig build` passed.
* `zig build check_games` passed: 10 games checked, 0 failed.
* `zig build test` passed.
* No focused game compatibility build was required beyond `check_games`
  because no game event migration was performed.
* No rule, trait, archetype, scheduler, broad-query, context, or
  particle/effects implementation was added.
* No formatting pass was run.


## 5. Trait System Entry Criteria

Trait implementation may start after:

* Generic World-owned event records and queues exist.
* A minimal rule/reaction layer exists and can observe components, relations,
  events, traits, and time/schedules in the intended direction.
* The event model can represent `TraitApplied` and `TraitRemoved` without a
  special trait-only side channel.
* World APIs have a clear pattern for typed fact registration, lifecycle, and
  optional cleanup.
* There is no active marker-component or relation-shaped-tag workaround to
  preserve.

When unblocked, the trait slice should target:

* `traits/trait.zig` for generic trait concepts.
* `traits/traitManager.zig` for typed trait-store ownership.
* World APIs such as `registerTrait`, `unregisterTrait`, `applyTrait`,
  `hasTrait`, and `removeTrait`.
* Presence-only classification as the first-class path.
* Payload-bearing metaproperties only if the first implementation clearly needs
  them.
* Minimal generic examples such as `Selectable`, `Visible`, `Simulated`,
  `Container`, and `Indexed`.


## 6. Later, Not Part Of Phase 4

* Rule/reaction implementation.
* Trait/metaproperty implementation.
* Archetypes/templates.
* World logical-time scheduler.
* Broad query planning over components, relations, events, traits, archetypes,
  and effect records.
* Save/load/replay context wiring.
* Rich retained event history, audit tools, or replay tooling.
* First-class particle/effects infrastructure.
