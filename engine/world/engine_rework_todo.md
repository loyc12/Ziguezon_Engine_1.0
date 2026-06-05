# ENGINE REWORK TODO

Action checklist for the active implementation slice of the engine rework.
Architectural intent lives in `engine_rework_reference.md`; implementation
sequence lives in `engine_rework_roadmap.md`. If this file conflicts with
either, the reference takes precedence, followed by the roadmap.


## 0. Current State

Phase 1A established the first `World` boundary:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation and the legacy borrowed component registry.
* `EngineStep` forwards each consumed base tick through
  `World.tick(TickContext)`.
* Current component stores remain game-owned and use string lookup plus manual
  `@ptrCast(@alignCast(...))`.
* `floppy`, `ping`, and `orbiter` register/unregister their borrowed stores
  through `World`.

The next task is Phase 1B of the roadmap's World Wrapper phase. It should
establish a real World-owned typed component-store path without also
implementing entity destruction, migrating every game, or adding dense/sparse
storage policies.


## 1. Active Slice: World-Owned Typed Component Stores

Implement World-owned typed component registration, storage, and CRUD, then
prove the contract by fully migrating `games/floppy`.

This slice is complete when:

* `World` can create, own, retrieve, and deinitialize a component store from a
  user-defined component type.
* Callers can register, add, get, test, and remove typed components through
  `World` without user-provided string keys or manual pointer casts.
* Hot systems can retrieve a typed store pointer once instead of performing a
  World registry lookup for every entity operation.
* Borrowed game-owned stores remain supported through APIs whose names clearly
  identify them as compatibility paths.
* `games/floppy` uses only the World-owned typed path for its transform and
  shape components.
* `games/ping` and `games/orbiter` still compile on the renamed borrowed-store
  compatibility path.


## 2. Fixed Decisions

* Implement the owned-store registry in
  `engine/world/components/componentManager.zig`.
* `World` owns and initializes one `ComponentManager`.
* Keep `ComponentStoreFactory(ComponentType)` as the underlying default
  hash-map store for this slice.
* `ComponentManager` owns the lifetime of every typed store registered through
  it:
  allocate, initialize, deinitialize, and destroy.
* Use `@typeName(ComponentType)` only as the manager's internal runtime key.
  Users must not provide component names or handle that key directly.
* Use a small erased registry entry containing the store pointer and the
  type-specific deinitialization/destruction callback needed for ownership.
  Do not add unrelated relation/event/query metadata yet.
* Reject duplicate typed registration. Do not silently replace or reinitialize
  an existing store.
* Registration failure after allocation must deinitialize/destroy the partial
  store before returning.
* Provide typed World APIs with these responsibilities:

      registerComponent( ComponentType )
      unregisterComponent( ComponentType )
      getComponentStore( ComponentType )
      addComponent( ComponentType, entityId, value )
      getComponent( ComponentType, entityId )
      hasComponent( ComponentType, entityId )
      removeComponent( ComponentType, entityId )

  Exact Zig signatures and error/boolean returns may follow existing style,
  but registration/allocation failures must not be silently ignored.
* Rename the current borrowed-store compatibility API to make its ownership
  explicit:

      registerBorrowedComponentStore
      unregisterBorrowedComponentStore
      getBorrowedComponentStore
      hasBorrowedComponentStore

* Keep borrowed compatibility storage separate from the new owned component
  manager. A borrowed pointer must never be deinitialized by `World`.
* Do not add `destroyEntity()` in this slice. It would only clean the new
  owned stores while leaving rows in borrowed stores, creating a false
  lifecycle guarantee.
* Do not implement dense/sparse selection yet. The typed ownership/access
  contract must stabilize before changing the underlying store policy.


## 3. Performance Constraint

The initial typed manager will still use a runtime erased registry and the
current `AutoHashMap`-backed component stores. This is a practical ownership
foundation, not the final high-performance iteration path.

* World typed CRUD may perform an internal type-key lookup.
* Tight systems should call `getComponentStore(ComponentType)` once and reuse
  the typed pointer while iterating or processing many entities.
* Do not hide a registry lookup inside every iteration of a hot entity loop.
* Do not optimize with dense/sparse policies until the owned-store API and
  migration behavior are validated.


## 4. Implementation Checklist

### 4.1 Implement ComponentManager Ownership

- [ ] Replace the placeholder in
      `engine/world/components/componentManager.zig`.
- [ ] Define the erased owned-store entry with only the pointer and lifecycle
      callback/data required to safely deinitialize and destroy its concrete
      store.
- [ ] Give `ComponentManager` explicit allocator, registry, and initialization
      state ownership.
- [ ] Implement defensive `init` and `deinit`; manager deinit must release
      every still-registered owned store exactly once.
- [ ] Implement typed registration using
      `ComponentStoreFactory(ComponentType)`, allocation through the manager's
      allocator, and internal `@typeName(ComponentType)` lookup.
- [ ] Ensure every typed registration failure path unwinds any store allocation
      or initialization already completed.
- [ ] Implement typed unregistration that deinitializes/destroys the selected
      store and removes its registry entry.
- [ ] Implement typed store retrieval with the cast contained inside
      `ComponentManager`, never at the user call site.
- [ ] Keep `componentManager.zig` independent of the broad engine facade where
      practical; use direct world/component/entity imports to avoid cycles.
- [ ] Replace `component.zig`'s broad engine-facade dependency for `EntityId`
      with a direct entity-module import if required by the new manager path.

### 4.2 Expose Typed Component Operations Through World

- [ ] Add `ComponentManager` ownership to `World`.
- [ ] Initialize/deinitialize the owned manager with World lifecycle.
- [ ] Add the typed registration, unregistration, store retrieval, add, get,
      has, and remove helpers listed in section 2.
- [ ] Keep the helpers compact wrappers over `ComponentManager` and the typed
      store; do not duplicate store behavior in `worldManager.zig`.
- [ ] Ensure typed operations fail cleanly when World is uninitialized or the
      requested component type is unregistered.
- [ ] Keep entity id `0` invalid. Do not add components for an invalid entity
      id.

### 4.3 Make Borrowed Compatibility Explicit

- [ ] Rename the four existing borrowed-store World helpers as listed in
      section 2.
- [ ] Rename the World-owned legacy registry field to
      `borrowedComponentRegistry` so code cannot mistake it for the new owned
      component manager.
- [ ] Update the existing borrowed-registry test to use the renamed helpers.
- [ ] Migrate `games/ping` and `games/orbiter` to the renamed compatibility
      helpers without changing their store ownership or CRUD behavior.
- [ ] Confirm no old ambiguous compatibility calls remain:

      rg -n "registerComponentStore|unregisterComponentStore|getComponentStore|hasComponentStore" engine games

  The only valid `getComponentStore` calls after this slice should be typed
  owned-store access.

### 4.4 Migrate Floppy As The Typed Reference Consumer

- [ ] Remove `floppy`'s game-owned transform/shape store variables and manual
      store init/deinit.
- [ ] Register `eng.TransComp` and `eng.ShapeComp` as World-owned component
      types when the game opens.
- [ ] Unregister those component types when the game closes so repeated
      open/close cycles remain valid.
- [ ] Replace component creation with `World.addComponent`.
- [ ] Replace manual registry lookup/casts and direct point lookups with
      `World.getComponent`.
- [ ] Preserve existing gameplay behavior and component values.
- [ ] Keep `ping` and `orbiter` as compatibility consumers in this slice; do
      not expand the proof migration.

### 4.5 Focused Tests

- [ ] Test typed registration and duplicate-registration rejection.
- [ ] Test typed store retrieval without a caller-side cast.
- [ ] Test World typed add/get/has/remove behavior with a small generic test
      component.
- [ ] Test that unregistering an owned component type removes access and
      permits a clean re-registration.
- [ ] Test that World deinit releases registered owned stores.
- [ ] Keep or update the borrowed-store test to prove World does not
      deinitialize borrowed pointers.


## 5. Validation

- [ ] Run `zig build`.
- [ ] Run `zig build floppy`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Do not run a formatting pass.
- [ ] Confirm `games/floppy` contains no component-store pointer casts:

      rg -n "getBorrowedComponentStore|@ptrCast|@alignCast" games/floppy

- [ ] Confirm `EngineTiming` and the existing World tick phase order are
      unchanged.
- [ ] Confirm the work did not add entity destruction, storage policies,
      relations, events, rules, traits, archetypes, scheduling, or queries.


## 6. Completion Notes To Record

When finishing this slice, update this file with:

* the final typed `World` component API;
* the final owned-store entry/lifecycle contract;
* the final names and remaining users of borrowed compatibility helpers;
* the measured or observed cost model for repeated typed store lookups;
* validation commands and their results;
* concrete blockers or decisions required for entity destruction and storage
  policies.


## 7. Later, Not Part Of This Task

* Migrate `ping` and `orbiter` from borrowed stores to World-owned typed
  stores.
* Track active entity validity and implement `World.destroyEntity()` only when
  every registered component path can participate in cleanup.
* Add component cleanup callbacks/indexing needed by entity destruction.
* Remove the borrowed component registry after its final consumer is migrated.
* Implement explicit `.dense` / `.sparse` store policies and fill
  `denseStore.zig` / `sparseStore.zig`.
* Add relations only after World entity/component ownership and cleanup
  behavior are stable.
