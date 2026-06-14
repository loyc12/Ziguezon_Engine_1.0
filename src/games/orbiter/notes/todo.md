# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. Use
[reference.md](reference.md) as the current implementation snapshot,
[goals.md](goals.md) as the target-state authority, and
[roadmap.md](roadmap.md) as the implementation sequence.

Phase 1C static `FacilityType` data baseline is complete. The next slice should
settle facility/resource naming, separate boolean data from numeric metrics,
mark solar-scaled facilities, and verify the storage-waste attribution
dependency before the facility runtime migration starts.

## Phase 1D - Facility Naming And Waste Attribution

Goal: stabilize the static facility/resource vocabulary, use boolean data grids
for flags, leave `PowerSrc` as a temporary legacy hook, and make the
storage-waste accounting dependency explicit for the future `econPipeline`.

This slice should stay focused. Do not migrate live economy state from
`InfType` / `IndType` to `FacilityType`, replace `EconSolver`, replace
`BuildQueue`, split population, or add trade routes yet.

## Validated Direction

Long-term decisions from the Phase 1C intake:

* power-source behavior should not be folded into `FacilityType` ad hoc;
* `PowerSrc` should stay only as a temporary legacy accessibility fix until
  facility solar scaling replaces it;
* production-share proportional storage waste should wait until the accounting
  path can preserve producer attribution;
* live infrastructure and industry runtime paths remain hooked until a later
  facility-state migration;
* the current `FacilityType` data surface is the static mirror that later
  migration work should target;
* `REFINERY` and `PROBE_MINE` are not desirable long-term `FacilityType` cases;
* facility and resource names should be reviewed before more metadata depends on
  them, including replacing names such as `GROUND_MINE` with names like
  `ORE_MINE` and moving outputs toward resources such as `BASE_METALS`, later
  `RARE_EARTHS`, and a better name for regolith-like bulk material;
* facility and resource data comments must preserve unit context. Unit notes are
  balancing data, not cosmetic comments, especially for data-matrix values.

## 1. Archive Before New Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-rewrite
version into `src/.oldFiles/` with the same relative path. Do not edit archived
files and keep only one archived version unless the user explicitly asks for
another.

Likely archive candidates for this slice:

* `src/games/orbiter/data/facilityData.zig`;
* `src/games/orbiter/data/industryData.zig`, if `getPowerSrc()` changes;
* `src/games/orbiter/econ/econSolver.zig`, if storage-waste accounting changes.

If the later power-source decision edits or deletes `PowerSrc`, archive
`src/games/orbiter/data/powerData.zig` before that pass.

Files already archived during Phase 1A, 1B, or 1C can be edited without creating
another copy unless the user asks for a second archive.

## 2. Review Facility And Resource Names

Clean up static `FacilityType` naming before attaching power-source or pipeline
metadata to unstable enum cases:

* remove undesirable static facility enum cases such as `REFINERY` and
  `PROBE_MINE`;
* review current industry-derived names and rename unclear cases into the new
  facility naming scheme;
* prefer output- or role-oriented names where that is clearer, such as
  `ORE_MINE` instead of `GROUND_MINE`;
* check resource-output names before wiring facility rows deeper into future
  logic. `ORE` has become `BASE_METALS`; later passes still need to decide
  whether to add `RARE_EARTHS` and a better name for regolith-like bulk
  material;
* keep or port unit comments when renaming resources/facilities, especially
  resource and facility data-matrix rows;
* keep live `IndType` compatibility names untouched unless this slice explicitly
  grows into a runtime migration.

Validation:

* facility names should read as stable data vocabulary, not old implementation
  leftovers;
* touched data rows should still state units directly or point to the relevant
  unit comment block;
* removed static facility cases must not break live infrastructure/industry
  runtime behavior.

## 3. Add Boolean Data Grids

Move static flags out of numeric metric grids and into boolean data grids:

* add `resBooleanData` for resource flags such as capacity-like, stockpiled,
  transportable, and access-priced;
* add `facilityBooleanData` for facility flags that should not live in numeric
  metrics;
* add `IS_SOLAR_SCALED` for facilities whose production should scale by local
  sunlight after the live solver migrates to facilities;
* keep boolean grids generic enough for later resource, facility, and data-enum
  flags.

Validation:

* resource boolean helper methods should no longer interpret `f64` `0.0` /
  `1.0` flags;
* `AGRONOMIC` and `SOLAR_PLANT` should be marked solar-scaled in
  `FacilityType`;
* current live behavior should not change.

## 4. PowerSrc Compatibility

Do not add a new facility power-source metadata table.

Leave `PowerSrc` as a temporary legacy accessibility fix while live production
still reads `IndType`. Once production scales through `FacilityType` and
`IS_SOLAR_SCALED`, strip the old `PowerSrc` concept unless a later design pass
finds a concrete reason to keep it.

Validation:

* no new `FacilityType` power-source metadata should be added in Phase 1D;
* `IndType.getPowerSrc()` should remain only as a compatibility hook.

## 5. Storage Waste Attribution Prep

Prepare production-share waste without forcing the full pipeline rewrite:

* inspect the current shared-depot overflow path in `econSolver.clampResStocks()`;
* confirm the current storage-use proportional waste remains the compatibility
  rule until `econPipeline` can preserve producer attribution;
* identify what producer attribution is missing from current flow buffers;
* document the exact producer-attribution data the future pipeline pass must
  carry;
* leave new attribution buffers for `econPipeline` unless the user explicitly
  promotes this slice into a pipeline-prep implementation.

Validation:

* current overflow logging must remain clear;
* resource accounting must not silently lose stock;
* the reason production-share waste waits for `econPipeline` should stay visible
  in `roadmap.md` or this file.

## 6. TODO Comment Review

Review these source TODOs during the pass:

* `data/industryData.zig`: `getPowerSrc()` should keep a TODO explaining that
  it is a temporary compatibility hook until facility solar scaling replaces it.
* `econ/econSolver.zig`: the shared-depot overflow comment should keep explaining
  why production-share proportional waste waits for `econPipeline` producer
  attribution.

Suggested defer:

* full facility-state migration;
* replacing `EconSolver` with `econPipeline`;
* construction-effort as a live resource;
* capacity-resource price modeling;
* removing `FUEL` or replacing the MVP resource set wholesale;
* extractable-accessibility tuning beyond naming/data dependency notes;
* route-facing power transfer behavior.

## 7. Out Of Scope For This Slice

Do not do these as part of Phase 1D unless the user changes the scope:

* removing old `InfType`, `IndType`, `infState`, or `indState`;
* migrating all solver phases onto `FacilityType`;
* replacing `BuildQueue`;
* modeling capacity-resource prices;
* removing `FUEL` from the resource model;
* dependant/worker population split;
* route trade or `TRADER` agents;
* taxes, subsidies, or government behavior;
* tuning Luna mineral access or Venus food production.
