# ENGINE REWORK TODO

Action checklist for the next implementation slices after Phase 1C.
Architectural intent lives in `engine_rework_reference.md`; implementation
sequence lives in `engine_rework_roadmap.md`. For this todo, the requested
next work takes precedence where it is more specific than the roadmap.


## 0. Current State

Phase 1C established the first World-owned typed component path:

* `Engine` owns and initializes one `World`.
* `World` owns entity-id creation, one typed `CompManager`, and a separate
  borrowed component registry.
* `EngineStep` forwards each consumed base tick through
  `World.tick(TickContext)`.
* `floppy` uses World-owned typed transform and shape stores.
* `ping` uses World-owned typed transform, shape, hitbox, mobile, and particle
  stores.
* `ping` currently uses a game-local `PingStores` bundle to cache typed store
  pointers.
* `orbiter` remains on the explicitly named borrowed compatibility path.
* `CompManager` reads optional component store policy metadata.
* Missing or explicit `.SPARSE` policy uses the current hash-map store.
* Explicit `.DENSE` policy is recognized but rejected until dense storage is
  implemented.
* `baseComps.zig` components currently remain on default sparse behavior.
* Entity destruction, relations, events, rules, traits, archetypes, scheduling,
  and broad query systems remain deferred.

The next work should turn the policy metadata into real storage selection,
then remove the manual store-pointer bundle pattern by introducing a focused
component-view helper and migrating real games onto it.


## 1. Slice Order

### Phase 1D: Dense/Sparse Stores And Mandatory Store Policy

Implement real `.DENSE` and `.SPARSE` component stores, integrate them into
`CompManager`, make component `storeType` declarations mandatory, and move all
engine base components to `.DENSE`.

This phase is complete when:

* `storeTypes/denseStore.zig` contains a real dense component store.
* `storeTypes/sparseStore.zig` contains a real sparse component store.
* `CompManager.register(CompType)` instantiates the correct store for
  `CompType.storeType`.
* Components without `storeType` fail loudly at compile time.
* `eng.TransComp`, `eng.ShapeComp`, `eng.HitboxComp`, and `eng.SpriteComp`
  explicitly declare `.DENSE`.
* `floppy`, `ping`, and `orbiter` compile after every live component type has
  an explicit policy declaration.
* No relation/event/rule/trait/archetype work is started.

### Phase 1E: Component Views And Game Migration

Introduce a focused `ComponentView` system for component-store gathering and
typed access, then move `ping` and `orbiter` onto it.

This phase is complete when:

* Game code can request a typed component view from `World` without manually
  bundling engine-owned store pointers.
* `ping` no longer has `PingStores`.
* `ping` uses `ComponentView` for body-part lookup, mobile/particle updates,
  hitbox sync, render, and particle creation/cleanup.
* `orbiter` registers engine-owned components and no longer uses borrowed
  component stores.
* `orbiter` uses `ComponentView` where it currently benefits from cached store
  pointers.
* Game-owned component-store logic is deprecated once `orbiter` no longer
  needs it.
* `BorrowedCompRegistry` has no remaining production game users. Removing it
  may be done in this phase only if every build target remains clean and the
  compatibility tests are updated or intentionally removed.


## 2. Fixed Decisions

* Keep `engine/world/engine_rework_reference.md` as the architectural guide.
* Keep this work inside component storage and component views. Do not start
  relations yet.
* Store policy is no longer optional after Phase 1D.
* Component declarations should read:

      pub const storeType : eng.CompStorePolicy = .DENSE;

  or:

      pub const storeType : eng.CompStorePolicy = .SPARSE;

* `baseComps.zig` components should use `.DENSE` once the dense backend exists.
* Dense storage should optimize packed iteration and cache locality.
* Sparse storage should preserve the current lookup-oriented behavior.
* Component views are for typed component access and store-pointer caching.
  They are not the full future query system over relations, events, traits,
  archetypes, or history.
* Persistent truth should remain entity ids and table rows, not raw pointers.
  Cached store pointers are allowed as transient view internals.
* Keep game-specific component definitions under `games/`.
* Keep engine-level examples minimal and generic.


## 3. Recommended Store Shapes

These container choices are the default implementation target unless the code
strongly argues for a smaller equivalent:

### 3.1 Dense Store

Use a packed, swap-removal dense table:

* `std.ArrayList(EntityId)` for dense entity ids.
* `std.ArrayList(CompType)` for dense component rows.
* `std.AutoHashMap(EntityId, usize)` for id-to-dense-index lookup.

Expected behavior:

* `add(id, value)` appends `id` and `value`, then records the index.
* `get(id)` finds the dense index through the hash map.
* `has(id)` checks the hash map.
* `remove(id)` swap-removes the dense id/component rows and repairs the moved
  entity's index.
* iteration walks packed component rows.
* dense iteration order is not stable after removals. Games that need stable
  draw/order semantics should keep explicit ordered id lists or use later
  order-aware view/query helpers.

### 3.2 Sparse Store

Use the current hash-map-style store:

* `std.AutoHashMap(EntityId, CompType)` for direct id-to-component lookup.

Expected behavior:

* preserve the current add/get/has/remove behavior;
* preserve current sparse iteration semantics;
* serve as the default choice for rare, optional, or highly lookup-oriented
  components.

### 3.3 Shared Store Interface

Both stores should expose the common API used by `World` and game code today:

      init(alloc)
      deinit()
      add(id, value)
      remove(id)
      get(id)
      has(id)
      iterator()

Names may follow the existing code style, but `CompManager`, `World`, and
component views should not need to know the concrete container internals.


## 4. Phase 1D Checklist

### 4.1 Store Policy Contract

- [ ] Change the policy helper so missing `storeType` is a compile-time error.
- [ ] Keep explicit `.DENSE` and `.SPARSE` declarations typed through
      `CompStorePolicy`.
- [ ] Ensure misspelled or invalid policy values fail loudly.
- [ ] Update all live engine/game component types so they declare a policy.
- [ ] Keep `CompStorePolicy` near component storage and re-export it through
      the engine facade for game declarations.
- [ ] Update tests that previously expected missing policy to default to
      `.SPARSE`.

### 4.2 Implement Store Backends

- [ ] Implement `DenseCompStoreFactory(CompType)` or equivalent in
      `storeTypes/denseStore.zig`.
- [ ] Implement `SparseCompStoreFactory(CompType)` or equivalent in
      `storeTypes/sparseStore.zig`.
- [ ] Move the current `AutoHashMap` store behavior into the sparse backend,
      or wrap it without duplicating logic.
- [ ] Keep allocation failure paths explicit and leak-free.
- [ ] Keep duplicate add rejection.
- [ ] Keep remove/get/has behavior for unregistered entity ids predictable.
- [ ] Add dense-store tests for add/get/has/remove.
- [ ] Add dense-store tests for swap-remove index repair.
- [ ] Add dense-store tests for iteration over packed rows.
- [ ] Add sparse-store tests matching current hash-map behavior.

### 4.3 Integrate Stores With CompManager

- [ ] Route `.DENSE` registration to the dense backend.
- [ ] Route `.SPARSE` registration to the sparse backend.
- [ ] Preserve one erased owned registry entry per component type.
- [ ] Preserve store deinit/destroy through an erased lifecycle callback.
- [ ] Preserve duplicate registration rejection.
- [ ] Preserve allocation failure cleanup.
- [ ] Preserve `World.addComp`, `World.getComp`, `World.hasComp`,
      `World.removeComp`, and `World.getCompStore` behavior for both policies.
- [ ] Avoid exposing dense/sparse internals through the broad `World` API.

### 4.4 Move Base Components To Dense

- [ ] Add `storeType : eng.CompStorePolicy = .DENSE` to `TransComp`.
- [ ] Add `storeType : eng.CompStorePolicy = .DENSE` to `ShapeComp`.
- [ ] Add `storeType : eng.CompStorePolicy = .DENSE` to `HitboxComp`.
- [ ] Add `storeType : eng.CompStorePolicy = .DENSE` to `SpriteComp`.
- [ ] Confirm base component registration now succeeds through the dense path.
- [ ] Keep base components data-first. Do not add behavior beyond storage
      policy metadata.

### 4.5 Update Game Component Policies

- [ ] Add explicit policies to `games/ping` components.
- [ ] Add explicit policies to `games/orbiter` components before or during its
      typed migration.
- [ ] Use `.DENSE` for components primarily iterated every tick or render pass.
- [ ] Use `.SPARSE` for rare, optional, or mostly point-lookup components.
- [ ] Document any non-obvious policy choice in the local game code or in this
      todo's completion notes.

### 4.6 Phase 1D Validation

- [ ] Run `zig build`.
- [ ] Run `zig build ping`.
- [ ] Run `zig build floppy`.
- [ ] Run `zig build orbiter`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Confirm missing `storeType` declarations fail at compile time with a
      clear error.
- [ ] Confirm `.DENSE` no longer rejects registration.
- [ ] Confirm `.SPARSE` still preserves current sparse behavior.
- [ ] Confirm no relation/event/rule/trait/archetype/scheduler work was added.
- [ ] Do not run a formatting pass.


## 5. Phase 1E Checklist

### 5.1 Component View API

- [ ] Add a focused component-view module under `engine/world/views` or
      `engine/world/components`, whichever best fits the code after Phase 1D.
- [ ] Provide a `ComponentView` / `CompView` naming choice consistent with the
      existing code style.
- [ ] Let game code request a view from `World` for a fixed set of component
      types.
- [ ] Cache typed store pointers inside the view.
- [ ] Fail clearly if any required component store is not registered.
- [ ] Expose typed point lookup by entity id.
- [ ] Expose enough iteration support to replace ping's manual store pointer
      loops.
- [ ] Keep the first view component-only. Do not include relations, events,
      traits, archetypes, filters, or query planning yet.
- [ ] Keep view lifetimes transient. Do not store long-lived views across
      component registration/unregistration unless invalidation rules are
      explicitly implemented.

Possible target shape:

      const bodyView = ng.world.getCompView( .{
        eng.TransComp,
        eng.ShapeComp,
        eng.HitboxComp,
      }) orelse return;

Exact syntax may differ to fit Zig constraints and project style.

### 5.2 Replace PingStores

- [ ] Remove `PingStores`.
- [ ] Replace ping's manual store bundle with component views.
- [ ] Keep ping's `entityIds` and `particleIds` arrays if stable ordering is
      still needed.
- [ ] Update body-part lookup to read through a view.
- [ ] Update hitbox sync to read through a view.
- [ ] Update mobile and particle iteration to read through views.
- [ ] Update render to read through a view.
- [ ] Update particle/entity cleanup to avoid direct game-owned store pointer
      bundles.
- [ ] Preserve ping gameplay values and behavior.
- [ ] Confirm ping no longer manually stores pointers to engine-owned stores.

### 5.3 Migrate Orbiter To Engine-Owned Components

- [ ] Inventory current `orbiter` game-owned component stores and borrowed
      registrations.
- [ ] Define explicit policies for every live `orbiter` component type.
- [ ] Register orbiter component types through `World.registerComp`.
- [ ] Replace component creation with `World.addComp`.
- [ ] Replace borrowed component lookups with `World.getComp`,
      `World.getCompStore`, or component views as appropriate.
- [ ] Prefer component views for systems that currently fetch multiple stores
      and reuse them through a phase.
- [ ] Remove `@ptrCast` / `@alignCast` use caused by borrowed component lookup.
- [ ] Preserve existing orbiter gameplay/setup behavior.
- [ ] Keep orbiter-specific simulation content under `games/orbiter`.
- [ ] Do not add relation storage to model orbiter relationships in this slice.
      Keep the migration focused on components and views.

### 5.4 Borrowed Compatibility Cleanup

- [ ] Confirm no production game still calls:

      registerBorrowedCompStore
      unregisterBorrowedCompStore
      getBorrowedCompStore
      hasBorrowedCompStore

- [ ] Deprecate the game-owned component-store path once `orbiter` is migrated.
- [ ] Remove or clearly mark any helper/API/documentation that teaches users to
      allocate, initialize, register, and cast game-owned component stores.
- [ ] Keep any temporary compatibility surface explicitly named as deprecated
      and borrowed/game-owned.
- [ ] Decide whether to remove `BorrowedCompRegistry` immediately or leave it
      for one more cleanup slice.
- [ ] If removed, update `World`, tests, exports, and docs in the same slice.
- [ ] If retained temporarily, mark it as deprecated compatibility with no
      production users.

### 5.5 Phase 1E Validation

- [ ] Run `zig build`.
- [ ] Run `zig build ping`.
- [ ] Run `zig build floppy`.
- [ ] Run `zig build orbiter`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Confirm ping no longer defines `PingStores`.
- [ ] Confirm ping and orbiter contain no borrowed-store lookups or component
      store pointer casts.
- [ ] Confirm component views do not expose dense/sparse container internals.
- [ ] Confirm no relation/event/rule/trait/archetype/scheduler work was added.
- [ ] Do not run a formatting pass.


## 6. Completion Notes To Record

When finishing Phase 1D, record:

* final dense store type/factory names;
* final sparse store type/factory names;
* exact dense container layout;
* exact sparse container layout;
* mandatory `storeType` error behavior;
* final policies chosen for base components;
* final policies chosen for ping and orbiter components that were touched;
* validation commands and results;
* any blocker found before component views.

When finishing Phase 1E, record:

* final component-view type/API names;
* view lifetime and invalidation assumptions;
* how ping replaced `PingStores`;
* how orbiter migrated away from borrowed stores;
* how game-owned component-store APIs/docs were deprecated;
* whether `BorrowedCompRegistry` was removed or retained temporarily;
* validation commands and results;
* any blocker found before relation storage.


## 7. Later, Not Part Of This Task

* Track active entity validity in `World`.
* Add erased component cleanup callbacks/indexing needed by future entity
  destruction.
* Implement `World.destroyEntity()` only when every registered component path
  can participate in cleanup.
* Add relation storage after entity/component ownership and component views are
  stable.
* Add generic event records/queues after entity, component, and relation
  ownership is stable.
* Add rules/reactions, traits, archetypes, scheduler, and broad queries in the
  order described by the roadmap.
