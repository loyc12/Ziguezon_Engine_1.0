# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. Use
[reference.md](reference.md) as the current implementation snapshot,
[goals.md](goals.md) as the target-state authority, and
[roadmap.md](roadmap.md) as the implementation sequence.

The previous Phase 1A ownership/location scaffold is complete. The next slice
starts Phase 1B from roadmap section 4.2: resource and capacity-resource model
prep that is still smaller than the full `Facility`, population, and
`econPipeline` rewrite.

## Phase 1B - Resource And Storage Capacity Scaffold

Goal: make the current economy state distinguish ordinary stock from local
capacity, then remove the most misleading storage assumptions without forcing
the full facility or pipeline migration.

This slice should stay focused. Do not implement full `Facility`, dependant
population, route trade, government taxes/subsidies, or `econPipeline` yet.
Those need their own todo slices once the resource/storage baseline is cleaner.

## 1. Archive Before New Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-rewrite
version into `src/.oldFiles/` with the same relative path. Do not edit archived
files and keep only one archived version unless the user explicitly asks for
another.

Likely new archive candidates for this slice:

* `src/games/orbiter/econ/econSolver.zig`;
* `src/games/orbiter/data/infrastructureData.zig`;
* `src/games/orbiter/data/industryData.zig`;
* `src/games/orbiter/data/populationData.zig`.

Files already archived during Phase 1A can be edited without creating another
copy unless the user asks for a second archive.

## 2. Resource Metadata Baseline

Extend the current resource metadata only as far as needed for roadmap 4.2:

* keep `LABOUR` as capacity-like and non-transportable;
* add metadata needed for future capacity-resource pricing and storage
  handling, but avoid adding the full starred resource list yet;
* keep `FUEL` in this slice unless all dependent uses in industry, population
  comments, debug seeding, and resource data are obvious and low-risk;
* preserve `ResType.getInfStore()` until storage routing has a replacement,
  but mark the intended data-backed replacement in the todo or comments;
* make any new resource metadata visible in logs or debug output where that can
  be done locally without solver rewrites.

Validation:

* `zig build`;
* `zig build check_games`;
* `zig build test`;
* inspect one Terra debug economy tick if resource state publication or logging
  changes.

## 3. Shared Depot Storage

Start replacing the old per-resource depot-lane assumption:

* calculate one shared `DEPOT` storage pool for ordinary resources;
* exclude capacity-like resources from depot stock usage;
* keep `HOUSING` as the current `LABOUR` transition store until population and
  facility capacity are split;
* decide where `LIMIT_D` should be set for shared storage, or explicitly keep it
  deferred if it no longer maps cleanly to per-resource limits;
* keep existing resource caps stable enough that Terra debug initialization
  does not collapse because of the storage change.

Validation:

* depot usage should reflect ordinary resources collectively rather than the
  maximum of independent lanes;
* `LABOUR` should not consume depot capacity;
* Terra debug economy logs should still show coherent resource counts, access,
  and prices after one tick.

## 4. Storage Waste Prep

Prepare storage waste without replacing the whole solver:

* inspect `econSolver.clampResStocks()` and its existing overflow warning;
* decide whether to record wasted stock in `ResStockEnum.DESTR`,
  `ResState.COUNT_D`, logs, or a new minimal metric;
* if implementation is low-risk, record per-resource overflow waste after
  stock clamping;
* defer proportional waste by production share if that requires the full
  `econPipeline` pass ordering.

Validation:

* overflow logging should remain clear;
* resource accounting should not silently lose stock without at least a metric
  or log path;
* `testResFlowInvariant()` should be reviewed before being used as a guardrail.

## 5. Extractable Resource Accessibility Prep

Add only the static data surface needed for later Terra/Luna/Venus tuning:

* define where extractable-resource accessibility belongs in data;
* add Terra/Luna/Venus placeholder accessibility values only if the data shape
  is clear;
* do not tune Luna as a mineral source or Venus as a food producer in this
  slice;
* do not wire route-facing trade behavior yet.

Validation:

* the data surface should compile and be inspectable;
* unused placeholder data should be clearly documented as Phase 2-facing prep.

## 6. TODO Comment Review - Pending User Validation

Do not edit, remove, or expand these source TODO comments until the user
validates the disposition below.

Suggested address in Phase 1B:

* `data/resourceData.zig`: `getInfStore()` should move toward data-backed
  storage routing, but only after shared depot storage design is clear.
* `data/resourceData.zig`: `else => .DEPOT` should be revised or reworded when
  shared depot storage replaces per-resource depot lanes.
* `data/resourceData.zig`: `LIMIT_D` should be addressed if shared storage keeps
  meaningful per-resource limit deltas; otherwise defer with a clearer note.
* `econ/econSolver.zig`: stock overflow waste should be recorded or logged more
  explicitly if storage clamping is touched.

Suggested defer:

* `comp/bodyComp.zig`: infer `bodyType` from mass/orbit relationship. This is
  stellar/body setup work, not resource-model work.
* `comp/bodyComp.zig`: replace the stress-test settlement fallback. This belongs
  with broader settlement metadata, not Phase 1B storage.
* `comp/bodyComp.zig`: add Lagrange settlement economies. Goals and roadmap
  defer Lagrange economies until after MVP.
* `comp/bodyComp.zig`: activate locations through player-built infrastructure.
  This should wait for facility/construction lifecycle work.
* `data/economyData.zig`: keep removing economy-rule dependencies from
  `EconLoc`. This remains valid, but Phase 1B should not reopen travel/orbit
  location semantics unless resource work requires it.
* `data/travelData.zig`: precise L1-L5 positions and more accurate orbital data
  are transfer-model work, not resource/storage work.
* `econ/economy.zig`: habitat debug counts should be recomputed during facility
  baseline tuning, not before facility migration.
* `econ/economy.zig`: vessel construction is post-MVP unless route work proves
  it is needed.
* `econ/economy.zig`: prevent destroying habitats in use. This should wait for
  coherent facility lifecycle and area constraints.
* `econ/economy.zig`: infrastructure average usage as a real agent metric should
  wait for the `Facility`/`EconAgent` model.
* `econ/economy.zig`: `tickLocalGov()` and local-government behavior belong to
  later finance/government work.
* `econ/economy.zig`: `applyInflation()` belongs to the later economy pipeline
  and finance pass.

Suggested drop or replace with clearer non-TODO comments:

* `data/resourceData.zig`: commented-out `STRUC` should probably remain an idea
  parking comment rather than an active implementation TODO, because mandatory
  Phase 1 manufactured resources are governed by `feature_ideas/resources.md`.

## 7. Out Of Scope For This Slice

Do not do these as part of Phase 1B unless the user changes the scope:

* full `Facility` enum/data migration;
* removing the old infrastructure/industry implementation split;
* dependant/worker population split;
* `econPipeline` replacement for `econSolver`;
* removing `debugAutoBuild()`;
* automatic trade routes or `TRADER` agents;
* taxes, subsidies, or government behavior;
* Lagrange, mobile, asteroid-belt, or star-hosted economies.
