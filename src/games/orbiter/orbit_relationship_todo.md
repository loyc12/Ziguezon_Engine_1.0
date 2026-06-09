# ORBIT RELATIONSHIP TODO

Action checklist for migrating Orbiter's orbital-parent facts onto the generic
World relation system while removing the assumption that `BodyName` maps directly
to `EntityId`.

This file is implementation guidance for Orbiter only. Engine architecture lives
in `../../engine/world/engine_rework_reference.md`. If this todo conflicts with
the engine reference or the current code, the current code wins until the
contradiction is resolved explicitly.


## 0. Original State

Before this migration, Orbiter stored orbital parentage outside `World`:

* `data/orbitanceData.zig` owns a fixed `orbitArray`, mapping each orbiter id to
  its orbited parent id.
* `idFromName()` and `nameFromId()` assume `BodyName == EntityId - 1`.
* `G_CONSTS.starId`, `G_CONSTS.homeId`, target selection, and several loops rely
  on body ids being dense, ordered, and equivalent to body enum order.
* `loadOrbitanceTree()` fills the fixed array during static-data loading.
* Orbit ticking and orbit rendering read the parent id through
  `gbl.ORBITANCE.getOrbitedId(id)`.
* The transfer solver caches parent ids in `TransferNode.parentId`, also sourced
  from `gbl.ORBITANCE.getOrbitedId(id)`.
* `OrbitComp` stores orbital shape/state and should remain a component for this
  slice.
* The econ tick does not need live relation lookups if parent ids remain cached.

The engine now supports first-class relation storage:

* `World.registerRelation`, `World.addRelation`, `World.hasRelation`,
  `World.getRelation`, and `World.removeRelation` exist.
* Relation stores support dataless facts, payload facts, source iteration,
  target iteration, exact lookup, removal, cardinality checks, and entity
  destruction cleanup.
* Relation endpoints must be live entities when `World.addRelation` is called.


## 1. Slice Scope

Move only the orbital-parent fact to a first-class relation, and make Orbiter's
body setup entity-id agnostic.

This slice is complete when:

* Orbiter defines and registers an `Orbits` relation type.
* `Orbits` represents `orbiter entity -> orbited entity`.
* The relation has `MANY_TO_ONE` cardinality: many orbiters can share a parent,
  but each orbiter can have only one orbital parent.
* Static parent data is expressed as `BodyName -> BodyName`, not `EntityId ->
  EntityId`.
* Orbiter creates a runtime body registry that maps `BodyName` to live
  `EntityId`.
* Body generation and body iteration use an explicit controlled body order, not
  raw entity-id ranges.
* `World.addRelation(Orbits, ...)` is called after both endpoints are live.
  Because child body enum/order entries are strictly after their parents, this
  can happen during ordered body creation instead of requiring a separate
  all-entities-first pass.
* Hot paths use a compact Orbiter-owned parent-id cache derived from `Orbits`,
  not repeated relation hash lookups.
* `OrbitComp` remains a component.
* The transfer solver continues to read cached parent ids through
  `TransferNode.parentId`.
* `data/orbitRelationData.zig` no longer owns the authoritative live parent
  lookup.
* Deprecated id/name conversion helpers and dense-id assumptions are removed.
* Validation covers relation registration, endpoint resolution, relation-backed
  cache rebuild, orbit ticking, orbit rendering, and transfer-cache refresh.


## 2. Fixed Decisions

* Keep `OrbitComp` as a component in this slice.
* Do not move orbital radii, mass, angular state, period, or render color into a
  relation payload.
* Make `Orbits` dataless unless a concrete relation payload becomes necessary.
* Treat `BodyName` as Orbiter's stable domain key.
* Treat `EntityId` as a runtime World handle only.
* Treat the body registry as a name/entity resolver, not as the parentage source
  of truth.
* Treat the `Orbits` relation store as the source of truth for live orbital
  parentage after entities are created.
* Treat the parent cache as derived state that can be rebuilt from `Orbits`.
* Keep parent lookup cheap in tick/render/transfer paths by caching parent ids.
* Keep parent-before-child generation order explicit and controlled by Orbiter.
* Do not add relation-aware component views in this slice.
* Do not add a generic query system in this slice.
* Do not wait for future traits/tags. Traits can later replace discovery of
  "which entities are bodies", but ordered orbit simulation still needs explicit
  ordering or relation-topology sorting.
* Do not change the travel-estimator model except where parent lookup plumbing is
  required.


## 3. Recommended Shape

This section is a practical target, not a requirement if the code argues for a
smaller equivalent.

### 3.1 Relation Type

Define a game-owned dataless relation near the other Orbiter game definitions:

    pub const Orbits = struct
    {
      pub const cardinalityPolicy : eng.RelationCardinalityPolicy = .MANY_TO_ONE;
    };

Source id is the orbiter. Target id is the orbited parent.

Examples:

    TERRA  -> Orbits -> SOL
    LUNA   -> Orbits -> TERRA
    PHOBOS -> Orbits -> MARS

### 3.2 Body Order And Runtime Registry

Keep body generation order explicit. Current enum order already places child
bodies after their parent bodies; this should become a named Orbiter data
contract instead of an implicit entity-id trick.

Likely shape:

    pub const bodyOrder = [_]BodyName{
      .SOL,
      .MERCURY,
      .VENUS,
      .TERRA,
      .LUNA,
      ...
    };

Add an Orbiter-owned runtime registry:

    pub const BodyRegistry = struct
    {
      ids : [ BodyName.count ]eng.EntityId = std.mem.zeroes([ BodyName.count ]eng.EntityId ),

      pub inline fn clear( self : *BodyRegistry ) void { ... }
      pub inline fn idOf( self : *const BodyRegistry, name : BodyName ) eng.EntityId { ... }
      pub inline fn setId( self : *BodyRegistry, name : BodyName, id : eng.EntityId ) void { ... }
    };

The registry should answer `BodyName -> EntityId`. It should not answer orbital
parentage. Parentage belongs to `Orbits`, with the cache derived from `Orbits`.

### 3.3 Static Orbit Relation Data

Keep the hardcoded body-parent table small and explicit, but store body names,
not entity ids.

Likely shape:

    pub const OrbitRelationPair = struct
    {
      orbiter : BodyName,
      orbited : BodyName,
    };

    pub const orbitRelationPairs = [_]OrbitRelationPair{ ... };

Required helper direction:

    getOrbitedName(orbiter : BodyName) ?BodyName

`SOL` should not have an `Orbits` relation. Every non-star body in `bodyOrder`
should have exactly one static parent entry.

### 3.4 Ordered Body Setup

During `initStellarSystem()`:

1. Iterate `bodyOrder`.
2. Create the body entity.
3. Store the entity in `BodyRegistry`.
4. If the body is not `SOL`, resolve its parent name from
   `orbitRelationPairs`.
5. Resolve parent id through `BodyRegistry.idOf(parentName)`.
6. Add `ng.world.addRelation(Orbits, bodyId, parentId, .{})`.
7. Refresh that body's parent-cache entry from the relation store.
8. Initialize body, orbit, transform, and render components.

This keeps setup single-pass while still testing relation registration,
endpoint validation, insertion, source iteration, and cache derivation.

If a parent id is missing during setup, treat that as an order/data error and
log it directly. Do not fall back to the old `BodyName -> EntityId` conversion.

### 3.5 Parent-Id Cache

Add an Orbiter-owned parent cache for hot-path lookup.

Likely shape:

    orbitParentIds : [ BodyName.count ]eng.EntityId = std.mem.zeroes([ BodyName.count ]eng.EntityId ),

Cache entries are keyed by `BodyName.toIdx()`, not by `EntityId`.

Required helpers:

    clearOrbitParentCache()
    refreshOrbitParentCacheEntry(ng, orbiterName)
    rebuildOrbitParentCache(ng)
    getOrbitedIdCached(bodyName)
    getOrbitedIdCachedById(bodyId) // only if call sites cannot cheaply carry BodyName

Cache rebuild should read the `Orbits` relation store. The current relation API
has source and target iterators, not a whole-store iterator, so rebuild can scan
`bodyOrder`, resolve each body id through the registry, and read the source-side
iterator for that id. With `MANY_TO_ONE`, each non-star source should produce
exactly one target.

The cache should be rebuilt after initial relation loading and after any future
orbit relation mutation. For this slice, refreshing entries during setup plus a
full rebuild validation is enough if orbital relationships remain static.

### 3.6 Call-Site Direction

Replace direct `gbl.ORBITANCE.getOrbitedId(id)` usage with relation-derived cache
helpers in:

* stellar body initialization;
* initial absolute position calculation;
* orbit ticking;
* orbit rendering;
* transfer node refresh.

Replace loops over dense entity-id ranges with loops over `bodyOrder`, resolving
the live entity id through the body registry.

Target cycling should track body order or body name, not increment/decrement raw
entity ids. `drawTargetInfo()` should validate against entity liveness or body
registry membership, not `id <= bodyCount`.

Avoid repeated relation-store lookup in tick/render/transfer paths. The intent is
to validate relations without making the frame or econ tick depend on hash-map
lookups.

### 3.7 Cleanup Boundary

When Orbiter closes:

* destroy stellar entities by iterating the body registry or `bodyOrder`;
* rely on `World.destroyEntity` to remove relation facts involving those ids;
* unregister the `Orbits` relation store after entities are destroyed;
* clear the body registry;
* clear the parent cache;
* clear cached component views as today.


## 4. Implementation Checklist

### 4.1 Inventory

- [x] List all uses of `gbl.ORBITANCE`.
- [x] List all uses of `getOrbitedId`.
- [x] List all uses of `getNextOrbiterId`.
- [x] List all uses of `idFromName`, `nameFromId`, `toNttId`, and `fromNttId`.
- [x] List all uses of `G_CONSTS.starId`, `G_CONSTS.homeId`, `maxEntityId`, and
      loops that assume body ids are dense from `1..bodyCount`.
- [x] Confirm `OrbitComp` has no hidden parent-id field to preserve.
- [x] Confirm `TransferNode.parentId` remains the travel solver's cached parent
      surface.

### 4.2 Relation Definition And Registration

- [x] Add the Orbiter-owned `Orbits` relation type.
- [x] Export `Orbits` through the local Orbiter definition module if needed.
- [x] Register `Orbits` during Orbiter world setup.
- [x] If `Orbits` registration fails, unwind already registered Orbiter stores
      consistently with the existing `registerOrbiterComps()` style.
- [x] Unregister `Orbits` during Orbiter close.
- [x] Do not clear component-only cached views merely because relation
      registration changes. Clear the parent cache and body registry as their own
      Orbiter runtime data.

### 4.3 Body Registry And Order

- [x] Add explicit `bodyOrder`.
- [x] Add `BodyRegistry` to Orbiter-owned runtime data.
- [x] Add `clear`, `idOf`, `setId`, and any small membership helper needed by
      target/debug code.
- [x] Replace `stellarEntitiesIds` as the primary body iteration surface.
- [x] Update body creation to store each created entity by `BodyName`.
- [x] Ensure setup logs a clear error if an ordered child resolves a parent that
      has not been created yet.

### 4.4 Static Data Conversion

- [x] Replace `OrbitanceData.orbitArray` with a compact static `BodyName` pair
      list, or add the pair list first and leave the old array unused until
      cleanup.
- [x] Add `getOrbitedName(orbiter : BodyName) ?BodyName`.
- [x] Move live relation insertion out of `loadOrbitanceTree()`.
- [x] Add relation insertion during ordered body setup, after both child and
      parent entities are live.
- [x] Make insertion failure visible through logs.
- [x] Confirm `SOL` has no static parent pair.
- [x] Confirm every non-star body in `bodyOrder` has exactly one static parent
      pair.

### 4.5 Cache

- [x] Add `orbitParentIds` to Orbiter-owned runtime data, keyed by
      `BodyName.toIdx()`.
- [x] Add a helper to clear the parent cache to zero.
- [x] Add a helper to refresh one body cache entry from the `Orbits` relation
      store by source id.
- [x] Add a helper to rebuild the whole parent cache from the `Orbits` relation
      store by scanning `bodyOrder` and using source-side relation iteration.
- [x] Validate that each non-star cached parent id is non-zero and alive.
- [x] Validate that each non-star source produces exactly one relation target.
- [x] Rebuild or refresh the cache after static `Orbits` insertion.
- [x] Clear the cache on game close.

### 4.6 Call-Site Migration

- [x] Replace parent lookup in `initStellarBody()`.
- [x] Replace parent lookup in initial start-position calculation.
- [x] Replace parent lookup in `tickOrbiters()`.
- [x] Replace parent lookup in `renderOrbiters()`.
- [x] Replace parent lookup in `refreshTransferNode()`.
- [x] Replace dense-id body loops with `bodyOrder` plus `BodyRegistry.idOf()`.
- [x] Replace target cycling so it tracks body order/body name rather than raw
      entity-id arithmetic.
- [x] Replace `drawTargetInfo()` body validation so arbitrary live entity ids are
      not rejected solely because they are greater than `bodyCount`.
- [x] Remove direct `gbl.ORBITANCE.getOrbitedId()` usage from hot paths.
- [x] Keep `OrbitComp` construction and math unchanged unless a parent lookup
      bug is exposed.

### 4.7 Cleanup

- [x] Remove obsolete live lookup fields from `OrbitanceData`.
- [x] Remove obsolete `getOrbitedId()` once all call sites use the relation-derived
      cache helper.
- [x] Remove obsolete `getNextOrbiterId()` if no current call site needs it.
- [x] Remove obsolete `idFromName()` and `nameFromId()`.
- [x] Remove obsolete `toNttId()` and `fromNttId()` if no remaining code needs
      enum/entity conversion.
- [x] Replace `G_CONSTS.starId` and `G_CONSTS.homeId` with `starBody` /
      `homeBody` body-name constants, resolving ids through the registry where
      needed.
- [x] Remove or replace `G_CONSTS.maxEntityId`.
- [x] Remove `gbl.ORBITANCE` once static orbit data is accessed through a clearer
      static-data API.
- [x] Rename `orbitanceData.zig` if its remaining role becomes only static orbit
      pair data and a clearer name emerges.
- [x] Remove any temporary compatibility helper once the migration is complete.

### 4.8 Validation

Validation status: build/static verification complete. Interactive visual
playtest was not run in this pass.

- [x] Run `zig build orbiter`.
- [x] Run `zig build test`.
- [x] Confirm `SOL` has no parent relation.
- [x] Confirm `LUNA` has an `Orbits` relation to `TERRA`.
- [x] Confirm `PHOBOS` and `DEIMOS` have `Orbits` relations to `MARS`.
- [x] Confirm `LUNA` caches `TERRA` as parent after reading the relation store.
- [x] Confirm `PHOBOS` and `DEIMOS` cache `MARS` as parent after reading the
      relation store.
- [x] Confirm all non-star bodies with `OrbitComp` have non-zero cached parents.
- [x] Confirm arbitrary created entity ids no longer need to match
      `BodyName.toIdx() + 1`.
- [x] Confirm orbit ticking still updates body transforms.
- [x] Confirm orbit rendering still draws paths around each body's cached
      parent.
- [x] Confirm target cycling still visits all bodies in body order.
- [x] Confirm `refreshAllTransferNodes()` fills `TransferNode.parentId`.
- [x] Confirm `estimateTransfer()` still finds ancestor chains for moon-parent
      routes.


## 5. Deferred Work

* Relation-aware component views.
* Generic world query integration.
* Trait/tag based body discovery.
* Dynamic orbit reassignment UI or gameplay.
* Payload-bearing orbit relations.
* Event emission for `RelationAdded` and `RelationRemoved`.
* Save/load support for relation facts.
* Relation-topology sorting if future body data no longer guarantees
  parent-before-child order.
* Profiling beyond the 1000-body low-hanging cache case.


## 6. Performance Notes

The migration should not put relation hash lookups in the econ tick or per-frame
orbit paths.

For a solar system with roughly 1000 bodies:

* relation insertion during setup is negligible;
* source-side relation iteration during cache rebuild is negligible when
  relationships are static or rarely changed;
* per-frame orbit ticking and rendering should use cached parent ids;
* weekly econ ticking should continue to use body position/velocity data and the
  travel solver's cached `TransferNode.parentId`;
* a relation lookup per body per frame would probably be acceptable, but it is
  avoidable and should not be the target implementation.

If future gameplay makes orbit relationships highly dynamic, profile before
adding more abstraction. The first response should be targeted cache invalidation
or a direct parent-cache refresh at mutation time, not a broader query system.
