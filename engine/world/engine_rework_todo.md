# ENGINE REWORK TODO

Completion record for the Phase 1B implementation slice of the engine rework.
Architectural intent lives in `engine_rework_reference.md`; implementation
sequence lives in `engine_rework_roadmap.md`. If this file conflicts with
either, the reference takes precedence, followed by the roadmap.


## 0. Current State

Phase 1B established the first World-owned typed component-store path:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation, one typed `CompManager`, and the
  separate borrowed component registry.
* `EngineStep` forwards each consumed base tick through
  `World.tick(TickContext)`.
* `floppy` uses World-owned typed transform and shape stores.
* `ping` and `orbiter` remain on the explicitly named borrowed compatibility
  path.
* Entity destruction and dense/sparse storage policies remain deferred.


## 1. Completed Slice: World-Owned Typed Comp Stores

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
  `engine/world/components/compManager.zig`.
* `World` owns and initializes one `CompManager`.
* Keep `CompStoreFactory(CompType)` as the underlying default
  hash-map store for this slice.
* `CompManager` owns the lifetime of every typed store registered through
  it:
  allocate, initialize, deinitialize, and destroy.
* Use `@typeName(CompType)` only as the manager's internal runtime key.
  Users must not provide component names or handle that key directly.
* Use a small erased registry entry containing the store pointer and the
  type-specific deinitialization/destruction callback needed for ownership.
  Do not add unrelated relation/event/query metadata yet.
* Reject duplicate typed registration. Do not silently replace or reinitialize
  an existing store.
* Registration failure after allocation must deinitialize/destroy the partial
  store before returning.
* Provide typed World APIs with these responsibilities:

      registerComp( CompType )
      unregisterComp( CompType )
      getCompStore( CompType )
      addComp( CompType, entityId, value )
      getComp( CompType, entityId )
      hasComp( CompType, entityId )
      removeComp( CompType, entityId )

  Exact Zig signatures and error/boolean returns may follow existing style,
  but registration/allocation failures must not be silently ignored.
* Rename the current borrowed-store compatibility API to make its ownership
  explicit:

      registerBorrowedCompStore
      unregisterBorrowedCompStore
      getBorrowedCompStore
      hasBorrowedCompStore

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
* Tight systems should call `getCompStore(CompType)` once and reuse
  the typed pointer while iterating or processing many entities.
* Do not hide a registry lookup inside every iteration of a hot entity loop.
* Do not optimize with dense/sparse policies until the owned-store API and
  migration behavior are validated.


## 4. Implementation Checklist

### 4.1 Implement CompManager Ownership

- [x] Replace the placeholder in
      `engine/world/components/compManager.zig`.
- [x] Define the erased owned-store entry with only the pointer and lifecycle
      callback/data required to safely deinitialize and destroy its concrete
      store.
- [x] Give `CompManager` explicit allocator, registry, and initialization
      state ownership.
- [x] Implement defensive `init` and `deinit`; manager deinit must release
      every still-registered owned store exactly once.
- [x] Implement typed registration using
      `CompStoreFactory(CompType)`, allocation through the manager's
      allocator, and internal `@typeName(CompType)` lookup.
- [x] Ensure every typed registration failure path unwinds any store allocation
      or initialization already completed.
- [x] Implement typed unregistration that deinitializes/destroys the selected
      store and removes its registry entry.
- [x] Implement typed store retrieval with the cast contained inside
      `CompManager`, never at the user call site.
- [x] Keep `compManager.zig` independent of the broad engine facade where
      practical; use direct world/component/entity imports to avoid cycles.
- [x] Replace `component.zig`'s broad engine-facade dependency for `EntityId`
      with a direct entity-module import if required by the new manager path.

### 4.2 Expose Typed Comp Operations Through World

- [x] Add `CompManager` ownership to `World`.
- [x] Initialize/deinitialize the owned manager with World lifecycle.
- [x] Add the typed registration, unregistration, store retrieval, add, get,
      has, and remove helpers listed in section 2.
- [x] Keep the helpers compact wrappers over `CompManager` and the typed
      store; do not duplicate store behavior in `worldManager.zig`.
- [x] Ensure typed operations fail cleanly when World is uninitialized or the
      requested component type is unregistered.
- [x] Keep entity id `0` invalid. Do not add components for an invalid entity
      id.

### 4.3 Make Borrowed Compatibility Explicit

- [x] Rename the four existing borrowed-store World helpers as listed in
      section 2.
- [x] Rename the World-owned legacy registry field to
      `borrowedCompRegistry` so code cannot mistake it for the new owned
      component manager.
- [x] Update the existing borrowed-registry test to use the renamed helpers.
- [x] Migrate `games/ping` and `games/orbiter` to the renamed compatibility
      helpers without changing their store ownership or CRUD behavior.
- [x] Confirm no old ambiguous compatibility calls remain:

      rg -n "registerCompStore|unregisterCompStore|getCompStore|hasCompStore" engine games

  The only valid `getCompStore` calls after this slice should be typed
  owned-store access.

### 4.4 Migrate Floppy As The Typed Reference Consumer

- [x] Remove `floppy`'s game-owned transform/shape store variables and manual
      store init/deinit.
- [x] Register `eng.TransComp` and `eng.ShapeComp` as World-owned component
      types when the game opens.
- [x] Unregister those component types when the game closes so repeated
      open/close cycles remain valid.
- [x] Replace component creation with `World.addComp`.
- [x] Replace manual registry lookup/casts and direct point lookups with
      `World.getComp`.
- [x] Preserve existing gameplay behavior and component values.
- [x] Keep `ping` and `orbiter` as compatibility consumers in this slice; do
      not expand the proof migration.

### 4.5 Focused Tests

- [x] Test typed registration and duplicate-registration rejection.
- [x] Test typed store retrieval without a caller-side cast.
- [x] Test World typed add/get/has/remove behavior with a small generic test
      component.
- [x] Test that unregistering an owned component type removes access and
      permits a clean re-registration.
- [x] Test that World deinit releases registered owned stores.
- [x] Keep or update the borrowed-store test to prove World does not
      deinitialize borrowed pointers.


## 5. Validation

- [x] Run `zig build`.
- [x] Run `zig build floppy`.
- [x] Run `zig build check_games`.
- [x] Run `zig build test`.
- [x] Do not run a formatting pass.
- [x] Confirm `games/floppy` contains no component-store pointer casts:

      rg -n "getBorrowedCompStore|@ptrCast|@alignCast" games/floppy

- [x] Confirm `EngineTiming` and the existing World tick phase order are
      unchanged.
- [x] Confirm the work did not add entity destruction, storage policies,
      relations, events, rules, traits, archetypes, scheduling, or queries.


## 6. Completion Notes To Record

Final typed `World` component API:

    registerComp( CompType )
    unregisterComp( CompType )
    getCompStore( CompType )
    addComp( CompType, entityId, value )
    getComp( CompType, entityId )
    hasComp( CompType, entityId )
    removeComp( CompType, entityId )

The owned manager uses `@typeName(CompType)` as its internal
`StringHashMap` key. Each erased entry contains only the allocated store
pointer and its type-specialized deinit/destroy callback. Registration
allocates and initializes a `CompStoreFactory(CompType)` store;
unregistration and manager deinit remove and release each owned store exactly
once. Failed registration after store allocation unwinds the initialized
store.

Borrowed compatibility helpers are:

    registerBorrowedCompStore
    unregisterBorrowedCompStore
    getBorrowedCompStore
    hasBorrowedCompStore

The remaining production borrowed-store users are `games/ping` and
`games/orbiter`. Borrowed pointers remain game-owned and are never
deinitialized by `World`.

Observed cost model:

* `World.getCompStore(CompType)` performs one `StringHashMap` lookup
  by the static type-name key, then one contained erased-pointer cast.
* World typed CRUD performs that manager lookup plus the existing
  `AutoHashMap(EntityId, CompType)` store operation.
* Hot loops should cache the typed store pointer to avoid repeating the
  manager lookup.

Validation results:

* `zig build`: passed.
* `zig build floppy`: passed.
* `zig build check_games`: passed.
* `zig build test`: passed (`6/6` focused engine tests).
* The old ambiguous compatibility helper grep returns no code calls.
* The `games/floppy` borrowed-access/pointer-cast grep returns no matches.
* `EngineTiming` and World tick phase order were unchanged.
* No entity destruction, storage policies, relations, events, rules, traits,
  archetypes, scheduling, or queries were added.

Deferred decisions and blockers:

* Entity destruction requires active entity validity tracking and an erased
  remove-by-entity contract for every registered component path. It remains
  blocked while borrowed stores cannot participate in cleanup.
* Storage-policy selection remains deferred. A later slice must choose the
  concrete store from component type policy while preserving the typed World
  API and owned lifecycle contract established here.


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
