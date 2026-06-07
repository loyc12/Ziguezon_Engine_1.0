# ENGINE REWORK TODO

Action checklist for the next implementation slice of the world/entity/simulation
rework.

Architectural intent lives in `engine_rework_reference.md`. Implementation
sequence lives in `engine_rework_roadmap.md`. If this todo conflicts with either
file, the reference takes precedence first, then the roadmap.


## 0. Current State

Phase 1 completed the World-owned component foundation.
Phase 2 completed entity lifecycle and component cleanup:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation, active entity tracking, and destruction.
* `World.destroyEntity(id)` removes that id from registered component stores.
* `World.addComp`, `World.getComp`, `World.hasComp`, and `World.removeComp`
  reject dead or never-created entity ids.
* Dense and sparse component stores are implemented.
* Component types must declare an explicit `storeType`.
* Component views remain transient typed store-access helpers.
* `EngineStep` forwards each consumed base tick through `World.tick(TickInfo)`.
* Relations, events, rules, traits, archetypes, particle/effects systems,
  logical scheduling, broad queries, and world context remain deferred.

The next useful slice is first-class relation storage. Entity creation,
validity, and destruction now exist, so relation rows can safely depend on
source/target entity ids and can participate in entity-destruction cleanup.


## 1. Slice Scope

### Phase 3: Relation Storage And World Relation API

Add World-owned relation storage for typed facts that connect two live entities.

This phase is complete when:

* `engine/world/relations/relation.zig` defines the generic relation concepts
  needed by user-defined relation types.
* `engine/world/relations/relationManager.zig` owns typed relation stores.
* `World` initializes, deinitializes, and exposes relation registration and
  relation row operations.
* Relation operations reject id 0, dead entities, never-created entities,
  uninitialized worlds, and unregistered relation types predictably.
* Relation storage supports source queries, target queries, exact
  source-target lookup, and removal.
* Destroying an entity removes relation rows where that entity is either the
  source or the target.
* At least one minimal generic engine relation example exists for tests and
  copyable structure.
* No event, rule, trait, archetype, scheduler, broad query, context, or
  particle/effects implementation is started.


## 2. Fixed Decisions

* Keep `engine_rework_reference.md` as the architectural guide.
* Keep `engine_rework_roadmap.md` as the implementation-sequencing guide.
* Keep this slice focused on relations only.
* Relations connect meaningful entities. Do not use relations as string-like
  tags or marker classifications.
* Classification remains a future traits/metaproperties concern.
* Prefer ids over raw pointers as persistent truth.
* Relation row pointers, relation-store pointers, and query iterators remain
  transient.
* Relation cleanup must follow entity destruction. A destroyed entity should
  leave no dangling source or target relation rows.
* Do not add retained event history for relation changes in this phase.
* Keep game-specific relation types under `games/`.
* Keep engine relation examples minimal and generic.


## 3. Recommended Shape

This section is a practical target, not a requirement if the code argues for a
smaller equivalent.

### 3.1 Relation Type Contract

User-defined relation fact types should be plain Zig structs owned by typed
relation stores.

Likely shape:

    pub const LinkedTo = struct
    {
      // optional relation payload fields
    };

Relation fact types may be zero-sized when the relation kind itself is the
fact. That is different from marker components: a relation row still stores
source and target entity ids and represents a typed connection between two
entities. Dataless relation facts should use keyed existence, not a clamped
dummy payload byte. `getRelation` must explicitly reject dataless relation fact
types; `hasRelation` is the intended access path for those rows.

Add relation metadata only when it is needed by the first store/API slice.
Cardinality policy is useful, but it should stay small:

* many source entities to many target entities by default;
* optional one-target-per-source policy if it is cheap and clarifies the API;
* defer richer uniqueness, ownership, cascading, and rule semantics.

### 3.2 Relation Storage

Implement a typed relation store that can answer the common relation questions
without scanning every row for normal use.

Target operations:

    add( sourceId, targetId, value )
    remove( sourceId, targetId )
    has( sourceId, targetId )
    get( sourceId, targetId )
    removeEntity( entityId )
    sourceIterator( sourceId )
    targetIterator( targetId )

Prefer explicit indexes:

* exact source-target key for lookup/removal;
* source index for outgoing relations;
* target index for incoming/reverse lookup.

Keep storage practical. A pair-key hash map plus source/target index lists is
enough unless the implementation shows a smaller robust option.

### 3.3 Relation Manager

`RelationManager` should mirror the useful parts of `CompManager` without
forcing relation storage to look like component storage.

Likely shape:

* allocator-backed lifecycle;
* string-keyed typed store registry using `@typeName(RelType)`;
* erased deinit callback;
* erased remove-entity cleanup callback;
* `register(RelType)` / `unregister(RelType)`;
* `getStore(RelType)`;
* `removeEntity(entityId)` returning a cleanup result.

Relation cleanup should tolerate relation types where the destroyed entity has
no rows.

### 3.4 World API

The public World relation surface should stay small and symmetrical with the
component path:

    registerRelation(RelType)
    unregisterRelation(RelType)
    getRelationStore(RelType)
    addRelation(RelType, sourceId, targetId, value)
    getRelation(RelType, sourceId, targetId)
    hasRelation(RelType, sourceId, targetId)
    removeRelation(RelType, sourceId, targetId)

Relation operations through `World` should require both endpoints to be alive.
Direct store APIs may remain lower-level, but tests should make the boundary
clear. `World.getRelation` should only be available for payload-bearing
relation facts. Calling it on a dataless relation fact must fail at compile
time if possible, or return no relation with a clear logged error if runtime
dispatch forces that path.

When `World.destroyEntity(id)` succeeds, it should clean up both components and
relations before marking the entity dead. If relation cleanup can fail, keep the
entity alive and report failure the same way component cleanup currently does.

### 3.5 Minimal Engine Example

Add one generic relation example for tests and reference usage. Prefer a neutral
name such as `LinkedTo` unless the implementation needs a stronger example.

Do not add a full library of `Owns`, `Contains`, `ParentOf`, `MemberOf`, and
`DependsOn` yet. Those are valid target examples from the roadmap, but this
slice only needs enough engine-level relation content to prove the system.


## 4. Phase 3 Checklist

### 4.1 Inventory And Naming

- [ ] Inspect current `World`, `CompManager`, and component-store lifecycle
      patterns before adding relation code.
- [ ] Confirm whether relation cleanup should run before or after component
      cleanup inside `World.destroyEntity`.
- [ ] Choose names consistent with existing style, preferably
      `registerRelation`, `addRelation`, and `removeRelation`.
- [ ] Keep `relations/relation.zig` for generic relation concepts.
- [ ] Keep `relations/relationManager.zig` for typed relation-store ownership.
- [ ] Avoid broad query/view naming in this phase.

### 4.2 Relation Concepts

- [ ] Define source/target relation row concepts in `relation.zig`.
- [ ] Define a source-target key type or equivalent hashable key.
- [ ] Decide whether relation rows store relation fact payload values, pointers
      to values, or both through typed store access.
- [ ] Decide whether zero-sized relation fact payloads are allowed.
- [ ] Ensure dataless relation facts use keyed existence instead of dummy
      byte storage.
- [ ] Ensure `getRelation` explicitly rejects dataless relation fact types.
- [ ] Add only minimal cardinality metadata if the first API needs it.
- [ ] Add tests for relation key equality and basic row behavior if those types
      have non-trivial logic.

### 4.3 Relation Store

- [ ] Implement typed relation store initialization and deinitialization.
- [ ] Add relation row add/remove/get/has operations.
- [ ] Reject duplicate exact source-target rows predictably.
- [ ] Add outgoing/source lookup.
- [ ] Add incoming/target lookup.
- [ ] Add cleanup for all rows touching a destroyed entity.
- [ ] Keep cleanup tolerant of absent rows.
- [ ] Ensure removing one relation repairs all indexes.
- [ ] Add tests for add/get/has/remove.
- [ ] Add tests for duplicate rejection.
- [ ] Add tests for source and target queries.
- [ ] Add tests for remove-entity cleanup touching source rows, target rows,
      and entities with no relation rows.

### 4.4 Relation Manager

- [ ] Add allocator-backed `RelationManager` lifecycle.
- [ ] Add typed relation-store registration.
- [ ] Add typed relation-store unregistration.
- [ ] Add typed relation-store lookup.
- [ ] Add erased store deinit/destroy callback.
- [ ] Add erased remove-entity cleanup callback.
- [ ] Preserve duplicate relation registration rejection.
- [ ] Add tests for registration, lookup, unregister, and deinit cleanup.
- [ ] Add tests for manager-level remove-entity cleanup across multiple
      relation types.

### 4.5 World Integration

- [ ] Add `relationManager` ownership to `World`.
- [ ] Initialize relation storage in `World.init`.
- [ ] Deinitialize relation storage in `World.deinit`.
- [ ] Add `World.registerRelation` and `World.unregisterRelation`.
- [ ] Add `World.getRelationStore`.
- [ ] Add `World.addRelation`.
- [ ] Add `World.getRelation`.
- [ ] Add `World.hasRelation`.
- [ ] Add `World.removeRelation`.
- [ ] Make World relation operations reject dead or never-created source ids.
- [ ] Make World relation operations reject dead or never-created target ids.
- [ ] Make `World.destroyEntity` clean relation rows involving the destroyed id.
- [ ] Add tests for relation operations on uninitialized worlds, id 0,
      dead ids, never-created ids, and unregistered relation stores.
- [ ] Add tests that entity destruction removes source-side and target-side
      relation rows.
- [ ] Add tests that entity destruction preserves unrelated relation rows.

### 4.6 Game Touchpoints

- [ ] Check whether any current game code is manually modeling relationships
      with component fields or id lists that would benefit from a tiny proof
      migration.
- [ ] Avoid migrating game domain logic unless it is a small, clear validation
      of the generic relation API.
- [ ] Keep existing game-owned stable ordering lists in place.
- [ ] Do not replace current game-specific component references with relations
      unless the relation carries real source-target semantics.

### 4.7 Documentation Updates

- [ ] Update `engine_rework_roadmap.md` only if implementation choices change
      the sequence or expose a contradiction.
- [ ] Append completion notes to this todo when Phase 3 is finished.
- [ ] Record the final relation type contract.
- [ ] Record the final relation store/index shape.
- [ ] Record the final relation manager callback/API names.
- [ ] Record whether any game code moved to the new relation API.
- [ ] Record validation commands and results.

### 4.8 Validation

- [ ] Run `zig build`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Run any focused game build touched by the relation proof migration.
- [ ] Confirm no event/rule/trait/archetype/scheduler/broad-query
      implementation was added.
- [ ] Confirm no first-class particle/effects implementation was added.
- [ ] Do not run a formatting pass.


## 5. Later, Not Part Of Phase 3

* Entity id reuse or generation counters.
* Relation-driven events, retained relation history, and audit logs.
* Rich cardinality policies, cascading ownership rules, or relation-specific
  lifecycle policies beyond entity-destruction cleanup.
* Generic event records/queues.
* Rules/reactions.
* Traits/metaproperties and archetypes/templates.
* World logical-time scheduler.
* Broad query planning over components, relations, events, traits, archetypes,
  and effect records.
* Save/load/replay context wiring.
* First-class particle/effects infrastructure.
