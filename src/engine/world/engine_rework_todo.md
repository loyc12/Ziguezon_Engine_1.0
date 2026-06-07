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

- [ ] Inspect current `event.zig`, `eventManager.zig`, `eventQueue.zig`, and
      `eventLog.zig`.
- [ ] Find all imports and call sites for the legacy `EventType`, `EventData`,
      `Event`, and callback subscription API.
- [ ] Decide whether the legacy callback event manager remains as compatibility
      surface for games during this slice or is removed immediately.
- [ ] Confirm the event implementation does not require trait, rule, archetype,
      scheduler, query, context, or particle/effects code.
- [ ] Choose final names consistent with existing style, preferably
      `registerEvent`, `emitEvent`, and `popEvent`.

### 4.2 Event Concepts

- [ ] Replace or isolate the fixed engine-specific `EventType` enum.
- [ ] Replace or isolate the fixed generic `EventData` union.
- [ ] Define a generic event metadata type if the first API needs it.
- [ ] Define minimal generic engine event examples.
- [ ] Decide whether dataless event facts are allowed in this slice.
- [ ] Keep game-specific event payloads under `games/`.
- [ ] Add tests for metadata ordering and basic event construction if those
      types have non-trivial logic.

### 4.3 Event Queue

- [ ] Implement typed event queue initialization and deinitialization.
- [ ] Add event push/pop/count/clear operations.
- [ ] Preserve insertion order.
- [ ] Add explicit drain behavior if it is needed by `World.tick`.
- [ ] Keep retained-history behavior out of the queue unless it is only a small
      callback/hook.
- [ ] Add tests for push/pop order, empty pop, clear, and deinit cleanup.

### 4.4 Event Manager

- [ ] Add allocator-backed `EventManager` lifecycle.
- [ ] Add typed event-queue registration.
- [ ] Add typed event-queue unregistration.
- [ ] Add typed event-queue lookup.
- [ ] Add erased queue deinit/destroy callback.
- [ ] Add manager-level emit and pop/drain helpers.
- [ ] Preserve duplicate event registration rejection.
- [ ] Add tests for registration, lookup, unregister, duplicate rejection, and
      deinit cleanup.

### 4.5 World Integration

- [ ] Add `eventManager` ownership to `World`.
- [ ] Initialize event storage in `World.init`.
- [ ] Deinitialize event storage in `World.deinit`.
- [ ] Add `World.registerEvent` and `World.unregisterEvent`.
- [ ] Add `World.getEventQueue` only if direct queue access is useful.
- [ ] Add `World.emitEvent`.
- [ ] Add `World.popEvent` or a focused drain API.
- [ ] Emit minimal generic entity/component/relation events only if that does
      not distort the first slice.
- [ ] Keep event processing tied to `World.tick(TickInfo)`.
- [ ] Add tests for event operations on uninitialized worlds and unregistered
      event queues.

### 4.6 Legacy Game Touchpoints

- [ ] Build an inventory of current game event usage.
- [ ] Avoid migrating game domain events unless needed to keep builds passing.
- [ ] Keep compatibility code compact if legacy callbacks are temporarily
      preserved.
- [ ] Record any intentional incompatibility in this todo before finishing the
      phase.

### 4.7 Documentation Updates

- [ ] Update `engine_rework_roadmap.md` only if implementation choices change
      the sequence or expose a contradiction.
- [ ] Append completion notes to this todo when Phase 4 is finished.
- [ ] Record the final event type contract.
- [ ] Record the final queue/manager shape.
- [ ] Record the final World event API names.
- [ ] Record whether legacy callback events were preserved, moved, or removed.
- [ ] Record validation commands and results.

### 4.8 Validation

- [ ] Run `zig build`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Run any focused game build touched by event compatibility work.
- [ ] Confirm no rule/trait/archetype/scheduler/broad-query implementation was
      added.
- [ ] Confirm no first-class particle/effects implementation was added.
- [ ] Do not run a formatting pass.


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
