# ENGINE REWORK TODO

Action checklist for the first implementation slice of the engine rework.
Architectural intent lives in `engine_rework_reference.md`; implementation
sequence lives in `engine_rework_roadmap.md`. If this file conflicts with
either, the reference takes precedence, followed by the roadmap.


## 0. Active Slice: World Foundation And Tick Boundary

Implement the first useful `World` boundary without also attempting the
component-storage-policy rework.

This is Phase 1A of the roadmap's World Wrapper phase, not completion of that
whole phase. World-owned typed stores, typed component add/get/remove access,
entity destruction cleanup, and storage-policy selection remain follow-up
work.

This slice is complete when:

* `Engine` owns one `World`.
* `World` owns entity-id creation and the existing compatibility component
  registry.
* Existing games create entities and find/register component stores through
  `World`, not through registries stored directly on `Engine`.
* Every consumed or forced Engine base tick is forwarded to
  `World.tick(TickContext)`.
* The existing game hooks and tilemap tick behavior still compile and retain
  their current relative order.

The existing typed component stores remain game-owned during this slice. The
current registry stores borrowed `*anyopaque` pointers and cannot safely own
or deinitialize arbitrary typed stores. Do not pretend that moving the
registry into `World` solves typed store ownership; that is the next
component-foundation slice.


## 1. Fixed Decisions

* Add the implementation to `engine/world/worldManager.zig`.
* Name the engine-owned field `Engine.world`.
* `World` owns the current `EntityIdRegistry` and `ComponentRegistry`.
* Provide `World.createEntity()` as the entity-creation entry point.
* Provide clearly named compatibility helpers for the current registry:
  `registerComponentStore`, `unregisterComponentStore`, `getComponentStore`,
  and `hasComponentStore`.
* Keep the compatibility component helpers string-keyed and `*anyopaque` for
  this slice only. Typed component access and storage policies belong in the
  following slice.
* Define `TickContext` beside `World`. Its initial fields should be:

      baseTickIndex : u128
      targetDelta   : utl.TimeVal
      measuredDelta : utl.TimeVal
      isForced      : bool

* Build `TickContext` after `EngineTiming.consumeTick()` or
  `EngineTiming.consumeForcedTick()` so `baseTickIndex` identifies the tick
  being executed.
* Keep `EngineTiming` as the sole owner of base-tick pacing. `World.tick`
  receives ticks; it must not add a timer, accumulator, `shouldTick`, or
  catch-up loop.
* Preserve the current base-tick phase order and insert the new World phase
  without reordering existing behavior:

      OnTickUpdate compatibility hook
      World.tick(TickContext)
      tilemap tick and marked-tilemap cleanup
      OffTickUpdate compatibility hook

* Keep `World.tick` intentionally small in this slice. It establishes the
  simulation boundary; systems, rules, logical time, and scheduling come
  later.
* Do not add `destroyEntity()` until World-owned component cleanup or another
  explicit cleanup contract exists. A destroy call that leaves component
  rows alive would create a false lifecycle guarantee.


## 2. Implementation Checklist

### 2.1 Add The World Type

- [ ] Replace the placeholder in `engine/world/worldManager.zig` with
      `TickContext` and `World`.
- [ ] Give `World` an `EntityIdRegistry`, a `ComponentRegistry`, and the
      minimum initialization state needed to make repeated init/deinit calls
      safe.
- [ ] Implement `World.init(alloc)`:
      reset entity-id state, initialize the compatibility component registry,
      and reject or safely ignore double initialization.
- [ ] Implement `World.deinit()`:
      deinitialize only World-owned state and make a second deinit safe.
      It must not deinitialize borrowed game-owned component stores.
- [ ] Implement `World.createEntity()` by delegating id creation to the
      World-owned entity registry.
- [ ] Implement the four compatibility component-store helpers listed in
      section 1 by delegating to the World-owned component registry.
- [ ] Implement `World.tick(TickContext)` as the explicit future simulation
      phase boundary. Do not add unrelated simulation behavior yet.
- [ ] Use direct world-module imports where practical so `worldManager.zig`
      does not depend on the broad engine facade merely to access world-owned
      types.

### 2.2 Integrate World Into Engine Lifecycle

- [ ] Export the world module, `World`, and the tick-context type through
      `engine/engineDef.zig`.
- [ ] Add `world : eng.World = .{}` to `Engine` in
      `engine/core/engine.zig`.
- [ ] Remove the direct `Engine.componentRegistry` and
      `Engine.entityIdRegistry` fields after all callers are migrated.
- [ ] Initialize `ng.world` during `engineState.start`.
- [ ] Deinitialize `ng.world` during `engineState.stop`, after
      `OnGameStop` has allowed games to deinitialize their borrowed stores.
- [ ] Keep the existing event and tilemap managers on `Engine` for now. Their
      redesign/migration is outside this slice.

### 2.3 Forward Base Ticks Into World

- [ ] Update `engine/core/engineStep.zig` so both due ticks and forced ticks
      tell the shared tick path whether the tick was forced.
- [ ] Construct one `TickContext` per consumed tick from `ng.times`.
- [ ] Call `ng.world.tick(context)` in the phase order documented in
      section 1.
- [ ] Do not move timing ownership or tick-loop control out of
      `EngineTiming`/`EngineStep`.
- [ ] Add a short code comment beside the phase sequence if needed to keep
      the compatibility order explicit.

### 2.4 Migrate Current Callers

- [ ] Replace every `ng.entityIdRegistry.getNewEntity()` call with
      `ng.world.createEntity()`.
- [ ] Replace every `ng.componentRegistry.register(...)` call with
      `ng.world.registerComponentStore(...)`.
- [ ] Replace every `ng.componentRegistry.get(...)` call with
      `ng.world.getComponentStore(...)`.
- [ ] Migrate any remaining unregister/has calls to the matching World
      compatibility helper.
- [ ] Confirm the main affected game paths are migrated:
      `games/floppy`, `games/ping`, and `games/orbiter`.
- [ ] Confirm no direct Engine registry access remains:

      rg -n "ng\.componentRegistry|ng\.entityIdRegistry" engine games

- [ ] Keep the existing game-owned store init/deinit code intact. Do not move
      typed stores into `World` during this slice.

### 2.5 Focused Tests

- [ ] Add focused tests for World initialization/deinitialization and
      sequential nonzero entity creation.
- [ ] Test the compatibility store boundary with a small dummy component
      store pointer: register, has, get, unregister.
- [ ] Ensure tests do not imply that World owns or deinitializes the borrowed
      store.


## 3. Validation

- [ ] Run `zig build`.
- [ ] Run `zig build check_games`.
- [ ] Run `zig build test`.
- [ ] Do not run a formatting pass.
- [ ] Confirm `EngineTiming` is still the only base-tick pacing authority.
- [ ] Confirm the work did not introduce relations, rules, traits,
      archetypes, scheduler behavior, query/view helpers, or a new event
      system.


## 4. Completion Notes To Record

When finishing this slice, update this file with:

* the final `World` public API;
* the final documented base-tick phase order;
* any compatibility helpers that remain and why;
* validation commands and their results;
* concrete blockers or decisions required for the next slice.


## 5. Next Slice, Not Part Of This Task

Design and implement actual World-owned typed component storage before adding
dense/sparse policy selection.

That follow-up must resolve:

* how user-defined component types register typed stores with `World`;
* how `World` initializes, owns, and deinitializes those stores;
* how entity destruction removes rows from every relevant store;
* how callers use typed add/get/remove access without string lookup and manual
  `@ptrCast(@alignCast(...))`;
* how existing games migrate without combining the entire storage-policy
  redesign into one change.
