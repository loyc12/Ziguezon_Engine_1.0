# ENGINE REWORK TODO

Action checklist for the next implementation slice of the world/entity/simulation
rework.

Architectural intent lives in `engine_rework_reference.md`. Implementation
sequence lives in `engine_rework_roadmap.md`. If this todo conflicts with either
file, the reference takes precedence first, then the roadmap.


## 0. Current State

Phase 1 completed the current World-owned component foundation, ending with the
1D/1E dense-store and component-view slices:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation and typed component stores.
* `EngineStep` forwards each consumed base tick through `World.tick(TickInfo)`.
* Dense and sparse component stores are implemented.
* Component types must declare an explicit `storeType`.
* `floppy`, `ping`, and `orbiter` use World-owned typed component stores.
* `ping` and `orbiter` use `CompView` / `ComponentView` for transient typed
  store access.
* Borrowed component-store compatibility was removed.
* Relations, events, rules, traits, archetypes, particle/effects systems,
  logical scheduling, broad queries, and entity destruction remain deferred.

The next useful slice is entity lifecycle and component cleanup. It should make
entity identity explicit enough that later relation storage can rely on
well-defined creation, validity, and destruction behavior.


## 1. Slice Scope

### Phase 2: Entity Lifecycle And Component Cleanup

Add active entity validity, entity destruction, and registered component-store
cleanup.

This phase is complete when:

* `World` can answer whether an entity id is currently alive.
* `World.destroyEntity(id)` exists and rejects id 0, uninitialized worlds, and
  already-dead or never-created ids predictably.
* Destroying an entity removes that id from every registered component store.
* `World.addComp`, `World.getComp`, `World.hasComp`, and `World.removeComp`
  respect entity validity.
* Component views remain transient typed access helpers and do not become the
  broad future query system.
* Dense and sparse component stores retain their current public behavior for
  direct component add/get/has/remove calls.
* Existing game behavior remains unchanged except where invalid entity/component
  operations now fail earlier.
* No relation, event, rule, trait, archetype, scheduler, broad query, or
  particle/effects implementation is started.


## 2. Fixed Decisions

* Keep `engine/world/engine_rework_reference.md` as the architectural guide.
* Keep this slice focused on entity lifecycle plus component cleanup.
* Do not implement entity id reuse in this phase. Monotonic ids are simpler and
  avoid generation/id-reuse questions before relations exist.
* Prefer ids over raw pointers as persistent truth.
* Component row pointers and component-view store pointers remain transient.
* Destroying an entity should invalidate component membership for that id, but
  should not invalidate component-store pointers unless component registration
  changes.
* Dense storage may keep swap-removal semantics. Stable iteration/draw order
  remains a game-owned id-list concern until later order-aware queries exist.
* Do not add marker components or zero-sized tag components. Classification
  remains a future traits/metaproperties concern.
* Keep game-specific simulation content under `games/`.


## 3. Recommended Shape

This section is a practical target, not a requirement if the code argues for a
smaller equivalent.

### 3.1 Entity Validity

Keep `EntityIdRegistry` as the monotonic id source.

Add active-entity tracking owned by `World` or by the registry, whichever keeps
the lifecycle API cleaner:

* id 0 is never alive;
* `createEntity()` marks the new id alive;
* `isEntityAlive(id)` returns the current live/dead state;
* `destroyEntity(id)` marks the id dead only after component cleanup succeeds;
* `World.deinit()` clears all live entity tracking.

Do not reuse ids yet. If future id reuse is added, it should be a separate
generation-aware slice.

### 3.2 Component Cleanup

`CompManager` should be able to remove an entity id from every registered
component store without knowing each store's concrete type.

Likely shape:

* extend the erased store entry with a remove-by-id callback;
* register that callback beside `deinitDestroyFn`;
* add `CompManager.removeEntity(id)` or similarly named cleanup helper;
* have `World.destroyEntity(id)` call that helper before marking the entity dead.

The cleanup helper should tolerate stores where the id is absent. A destroyed
entity may have zero components.

### 3.3 World API

The public World lifecycle surface should be small:

    createEntity()
    isEntityAlive(id)
    destroyEntity(id)

Keep `registerComp`, `unregisterComp`, `addComp`, `getComp`, `hasComp`,
`removeComp`, `getCompStore`, and `getCompView` behavior compatible with the
current component path, except that component operations through `World` should
reject dead or never-created ids.


## 4. Phase 2 Checklist

### 4.1 Inventory And Naming

- [ ] Inspect current entity creation, component add/remove, and game cleanup
      call sites before editing behavior.
- [ ] Choose names consistent with existing style, preferably
      `isEntityAlive(id)` and `destroyEntity(id)` unless a better local pattern
      is obvious.
- [ ] Decide whether active-id tracking lives inside `World` or
      `EntityIdRegistry`.
- [ ] Keep existing `Entity` as a lightweight id wrapper.
- [ ] Do not introduce a broad entity object hierarchy.

### 4.2 Active Entity Tracking

- [ ] Add active entity tracking with allocator-backed lifecycle if needed.
- [ ] Initialize active tracking in `World.init`.
- [ ] Clear active tracking in `World.deinit`.
- [ ] Make `createEntity()` reject uninitialized worlds as it does now.
- [ ] Make successful `createEntity()` mark the id alive.
- [ ] Add `World.isEntityAlive(id)` or equivalent.
- [ ] Ensure id 0 is never alive.
- [ ] Add tests for creation and alive/dead state.
- [ ] Add tests for world deinit/reinit resetting entity lifecycle state.

### 4.3 Component Store Cleanup Hooks

- [ ] Extend `CompManager` erased store entries with a callback that removes a
      component row by entity id.
- [ ] Implement the callback through `CompStoreFactory(CompType).remove(id)`.
- [ ] Add a `CompManager` helper that removes one entity id from all registered
      stores.
- [ ] Make the helper return enough information to detect internal cleanup
      failures if a future store can fail cleanup.
- [ ] Keep cleanup tolerant of missing component rows.
- [ ] Preserve store deinit/destroy behavior.
- [ ] Preserve duplicate component registration rejection.
- [ ] Add tests for cleanup across both dense and sparse stores.

### 4.4 World Destroy API

- [ ] Add `World.destroyEntity(id)`.
- [ ] Reject id 0.
- [ ] Reject uninitialized worlds.
- [ ] Reject never-created or already-dead ids.
- [ ] Remove all registered components for the id.
- [ ] Mark the id dead after component cleanup.
- [ ] Ensure `destroyEntity(id)` is idempotent from the caller's perspective:
      first call succeeds, later calls fail predictably without mutating state.
- [ ] Add tests that destroyed entities lose dense components.
- [ ] Add tests that destroyed entities lose sparse components.
- [ ] Add tests that destroying an entity with no components succeeds.
- [ ] Add tests that destroying one entity does not disturb another entity's
      components.

### 4.5 World Component API Validity

- [ ] Update `World.addComp` to reject dead or never-created ids.
- [ ] Update `World.getComp` to reject dead or never-created ids.
- [ ] Update `World.hasComp` to return false for dead or never-created ids.
- [ ] Update `World.removeComp` to reject dead or never-created ids.
- [ ] Preserve current behavior for unregistered component stores.
- [ ] Keep direct store APIs unchanged; validity checks belong at the World
      boundary for this slice.
- [ ] Add tests for component operations on dead ids.
- [ ] Add tests for component operations on ids that were never created.

### 4.6 Game Touchpoints

- [ ] Check `games/ping` cleanup paths that manually remove components from
      particle/body ids.
- [ ] Check `games/floppy` and `games/orbiter` for assumptions that any
      non-zero id can receive components.
- [ ] Prefer using `World.destroyEntity(id)` where the game is truly deleting an
      entity.
- [ ] Keep game-owned stable ordering lists in place if they are still needed.
- [ ] Do not start the first-class particle/effects system in this phase; only
      preserve current ping behavior.

### 4.7 Documentation Updates

- [ ] Update `engine_rework_roadmap.md` only if implementation choices change
      the sequencing or expose a contradiction.
- [ ] Append completion notes to this todo when Phase 2 is finished.
- [ ] Record the final active-id storage shape.
- [ ] Record the final component cleanup callback/API names.
- [ ] Record whether any game cleanup paths moved to `World.destroyEntity`.
- [ ] Record validation commands and results.

### 4.8 Validation

- [ ] Run `zig build`.
- [ ] Run `zig build ping`.
- [ ] Run `zig build floppy`.
- [ ] Run `zig build orbiter`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Confirm no relation/event/rule/trait/archetype/scheduler/broad-query
      implementation was added.
- [ ] Confirm no first-class particle/effects implementation was added.
- [ ] Do not run a formatting pass.


## 5. Later, Not Part Of Phase 2

* Entity id reuse or generation counters.
* Relation storage, relation indexes, cardinality rules, and relation cleanup.
* Generic event records/queues.
* Rules/reactions.
* Traits/metaproperties and archetypes/templates.
* World logical-time scheduler.
* Broad query planning over components, relations, events, traits, archetypes,
  and effect records.
* First-class particle/effects infrastructure.
* Save/load/replay context records.


## 6. Completion Notes To Record

When finishing Phase 2, record:

* final active entity storage shape;
* final `World` entity lifecycle API names;
* final `CompManager` cleanup callback/helper names;
* how destroy cleanup behaves for dense and sparse component stores;
* how component operations behave for dead and never-created ids;
* any game cleanup paths changed to `World.destroyEntity`;
* validation commands and results;
* any blocker found before relation storage.
