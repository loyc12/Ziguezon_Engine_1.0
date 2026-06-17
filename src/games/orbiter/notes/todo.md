# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. Use
[reference.md](reference.md) as the current implementation snapshot,
[goals.md](goals.md) as the target-state authority, and
[roadmap.md](roadmap.md) as the implementation sequence.

The static resource and `FacilityType` baseline is in place. The next slice
should move live economy behavior from the old `InfType` / `IndType` split onto
the combined facility surface and prove behavior invariance before the full
`econPipeline` rewrite starts.

## Phase 1E - Facility Runtime Migration

Goal: make `FacilityType` the live-facing economy facility surface while
preserving current Terra behavior closely enough to validate the migration
before building new pipeline behavior on top of it.

This slice should stay focused. Do not replace `EconSolver` with
`econPipeline`, split population, tune Terra stability, add trade routes, add
taxes/subsidies, or remove `debugAutoBuild()` yet.

## Validated Direction

Current direction from [goals.md](goals.md) and [roadmap.md](roadmap.md):

* Phase 1 restores Terra as an autonomous single economy before Phase 2 trade;
* `Facility` is the merged industry/infrastructure concept, but live runtime
  paths can remain bridged through `InfType` / `IndType` while the migration is
  staged;
* `facState` is the preferred short name for live facility state, matching the
  existing short forms `inf`, `ind`, `pop`, and `res`;
* `FUEL`, `REFINERY`, and `PROBE_MINE` should be removed before the live
  `FacilityType` move;
* `PART` should be renamed to `STRUCTURE` before deeper facility behavior
  depends on it;
* `PowerSrc` stays only as temporary compatibility until live production scales
  through facility `IS_SOLAR_SCALED` metadata;
* `EconAgent` becomes the shared actor surface for facilities, population,
  government, and later route traders;
* `econPipeline` succeeds the current `EconSolver`, but the exact internal split
  should be chosen after the combined facility surface is live enough to target;
* construction and maintenance must eventually route through owning agents;
* `BuildQueue` can be replaced if the audit shows replacement is cleaner than
  repair;
* storage overflow remains current storage-use proportional waste until the new
  pipeline can preserve producer attribution for production-share waste.

## 1. Archive Before New Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-rewrite
version into `src/.oldFiles/` with the same relative path. Do not edit archived
files and keep only one archived version unless the user explicitly asks for
another.

Files already archived during Phase 1A-1D can be edited without creating
another copy unless the user asks for a second archive.

Likely archive candidates only if this slice makes a major first rewrite there:

* `src/games/orbiter/econ/economy.zig`;
* `src/games/orbiter/econ/econSolver.zig`, if solver lanes move to
  `FacilityType` directly;
* `src/games/orbiter/econ/econAutoBuild.zig`, if debug growth callers move to
  facility helpers;
* `src/games/orbiter/econ/econBuilder.zig`, if construction callers move to
  facility helpers.

## 2. Remove Obsolete Resource And Industry Cases

Remove the trivial obsolete pieces before live code moves onto `FacilityType`.

Next implementation work:

* rename `PART` to `STRUCTURE`;
* remove `FUEL` from the MVP resource set and update dependent rows/callers;
* remove `REFINERY` and `PROBE_MINE` from live industry data and any remaining
  direct callers;
* keep the old archived files untouched.

Validation:

* the code should compile after each small removal/rename step;
* Terra should still run and remain roughly as stable as the current baseline,
  even if the economy still crashes after a few simulated years.

## 3. Keep `PowerSrc` As Compatibility

Do not add new facility power-source metadata.

Confirm the current `IndType.getPowerSrc()` path is still only a bridge for live
production/accessibility behavior. `FacilityType.IS_SOLAR_SCALED` is the target
surface; `PowerSrc` can be stripped only after live production reads facility
metadata instead of `IndType`.

Validation:

* `data/industryData.zig` should keep a source TODO or nearby comment explaining
  why `PowerSrc` still exists;
* no new `FacilityType` power-source table should be added;
* current live production behavior should not change in this slice.

## 4. Migrate Live Facility Access

Move the current live `InfType` / `IndType` usage toward `FacilityType` before
using the combined enum in new implementation.

Next implementation work:

* add `facState` as the live facility-state direction, or start with thin
  facility-facing wrappers over `infState` / `indState` only if that makes the
  behavior-invariance pass smaller;
* route counts, capacity queries, area usage, build costs, maintenance costs,
  and ecology inputs through facility-facing helpers;
* keep `FacilityType.toLegacy()` / `fromInfType()` / `fromIndType()` available
  only as compatibility bridges while old state remains underneath;
* update debug growth and construction request callers to prefer `FacilityType`
  where the behavior mapping is direct;
* remove `PowerSrc` as soon as live production scales from facility solar
  metadata.

Validation:

* the code compiles and the simulation can be run;
* current Terra logs should remain close enough to compare before/after
  behavior;
* old production and consumption roles should be explainable through
  `FacilityType`;
* the migration should not introduce new pipeline behavior yet.

## 5. Define The `EconAgent` / Pipeline Boundary

Define the agent boundary after the facility surface exists, without turning
agents into opaque mini-solvers.

Define:

* the durable `EconAgent` identity/accounting surface for facilities,
  population, government, and later route traders;
* population as one monolithic agent until dependant/worker split work happens;
* government as one monolithic agent until local/stellar government split work
  has a concrete need;
* two directional `TRADER` agents per bidirectional route, tied together by
  route-level accounting or a later savings-equalisation pass;
* which agent helpers gather demand, supply, maintenance, finance, construction,
  and policy intent;
* which pipeline-owned buffers receive those intents;
* which mutations must remain centralized in the pipeline rather than happening
  directly inside agents;
* how producer attribution should be carried later so storage overflow can move
  from storage-use proportional waste to production-share proportional waste.

Design bias:

* agents should own identity, policy/accounting rules, and intent generation;
* agents may access their own pipeline scratch state when that is the cleanest
  way to fund maintenance or construction from savings;
* the pipeline should own canonical tick buffers, conflict resolution, access
  rates, final resource/money mutations, and publication;
* hot resource/action loops should stay table-driven where that is clearer and
  cheaper than dispatching through agent methods for every cell.

Validation:

* pipeline design should target `FacilityType` and `EconAgent`, not legacy
  infrastructure/industry lanes;
* logs and data names should make clear which actor paid, earned, received, or
  lost money;
* the design should leave room for Phase 2 route taxes/subsidies without adding
  politics or trade behavior in Phase 1.

## 6. Replace Or Audit `BuildQueue`

Replacement is acceptable. Audit only enough to avoid preserving bugs or losing
useful behavior during replacement.

Check these known risks:

* matching or conflict handling can mutate the wrong entry;
* compaction may not copy entry values correctly;
* closed-entry dumping can use the wrong index;
* total-cost helpers mix integer accumulation with `f64` return values;
* construction money is simplified and not fully routed through accounts;
* assembly construction effort is not paid through the eventual agent model;
* `debugAutoBuild()` can still inject construction funding as a stopgap.

Output of this step should be one of:

* a replacement plan if repair is messier than rebuilding;
* a small repair plan only if the queue is clearly close to the target shape;
* a short blocker list if `EconAgent` or `econPipeline` decisions must come
  first.

Validation:

* no queue behavior should be changed until the audit result is clear;
* construction should not create or destroy resources/money except through
  documented temporary rules.

## 7. Source TODO Handling

Validated handling for current TODO comments in implicated files:

* address now: `data/industryData.zig` `getPowerSrc()` should keep its temporary
  compatibility TODO/comment;
* address now: `data/builderData.zig` `EconAgent` TODO belongs to this agent
  boundary-design slice;
* address now: `econ/econBuilder.zig` and `data/builderData.zig` construction
  queue TODOs should be classified during the `BuildQueue` audit;
* defer: broad `econSolver.zig` generalization and `IMPLEMENT ME` TODOs belong
  to the later `econPipeline` migration, not isolated cleanup;
* defer: `econAutoBuild.zig` funding injection stays until real construction and
  maintenance funding paths exist;
* defer: `data/populationData.zig` dependant/worker TODOs belong after the
  facility and agent/pipeline foundations are stable;
* defer: `data/resourceData.zig` storage-routing TODOs belong to later
  data-backed storage routing work;
* defer: `data/economyData.zig` `EconLoc` compatibility cleanup can continue
  opportunistically, but it is not part of this slice;
* drop from this file: the previous `econSolver.clampResStocks()` source-TODO
  review item. The source has an explanatory comment, not a TODO. Keep the
  producer-attribution dependency as roadmap/todo context only.

Do not add, remove, or rewrite source TODO comments without a matching
implementation pass or another user approval.

## 8. Out Of Scope For This Slice

Do not do these as part of Phase 1E unless the user changes the scope:

* deleting all `InfType` / `IndType` compatibility surfaces before behavior
  invariance is validated;
* replacing the full `EconSolver` with `econPipeline`;
* implementing capacity-resource pricing;
* splitting population into dependants and workers;
* removing `debugAutoBuild()`;
* route trade, `TRADER` agents, taxes, subsidies, or government behavior;
* Luna/Venus tuning or extractable-accessibility balancing;
* colonization, politics, migration, vessel logistics, or explicit game goals.
