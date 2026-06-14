# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. Use
[reference.md](reference.md) as the current implementation snapshot,
[goals.md](goals.md) as the target-state authority, and
[roadmap.md](roadmap.md) as the implementation sequence.

Phase 1C static `FacilityType` data baseline is complete. The next slice should
settle facility/resource naming and power-source behavior, then verify the
storage-waste attribution dependency before the facility runtime migration
starts.

## Phase 1D - Power Sources And Waste Attribution

Goal: define the power-source model that facilities will use, and make the
storage-waste accounting dependency explicit for the future `econPipeline`.

This slice should stay focused. Do not migrate live economy state from
`InfType` / `IndType` to `FacilityType`, replace `EconSolver`, replace
`BuildQueue`, split population, or add trade routes yet.

## Validated Direction

Long-term decisions from the Phase 1C intake:

* power-source behavior should be redesigned in this pass, not folded into
  `FacilityType` ad hoc;
* production-share proportional storage waste should wait until the accounting
  path can preserve producer attribution;
* live infrastructure and industry runtime paths remain hooked until a later
  facility-state migration;
* the current `FacilityType` data surface is the static mirror that later
  migration work should target;
* `REFINERY` and `PROBE_MINE` are not desirable long-term `FacilityType` cases;
* facility and resource names should be reviewed before more metadata depends on
  them, including replacing names such as `GROUND_MINE` with names like
  `MINE_ORE` and moving outputs toward resources such as `BASE_METALS`, later
  `RARE_EARTHS`, and a better name for regolith-like bulk material;
* facility and resource data comments must preserve unit context. Unit notes are
  balancing data, not cosmetic comments, especially for data-matrix values.

## 1. Archive Before New Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-rewrite
version into `src/.oldFiles/` with the same relative path. Do not edit archived
files and keep only one archived version unless the user explicitly asks for
another.

Likely archive candidates for this slice:

* `src/games/orbiter/data/powerData.zig`;
* `src/games/orbiter/data/facilityData.zig`, if power metadata is added there;
* `src/games/orbiter/data/industryData.zig`, if `getPowerSrc()` changes;
* `src/games/orbiter/econ/econSolver.zig`, if storage-waste accounting changes.

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
  `MINE_ORE` instead of `GROUND_MINE`;
* check resource-output names before wiring facility rows deeper into future
  logic, especially `ORE` / `INGOT` and likely replacements such as
  `BASE_METALS`, later `RARE_EARTHS`, and a better name for regolith-like bulk
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

## 3. Define Power-Source Semantics

Clarify what `PowerSrc` means before moving it into facilities:

* decide whether `GRID`, `SOLAR`, and later candidates such as fueled or beamed
  power are facility input modes, production scalers, transport modes, or a
  mix of those;
* decide whether solar access should scale only production or both production
  and input consumption as it currently does for solar-powered industries;
* decide how local power production should differ from facilities that merely
  require grid electricity;
* keep the first rule set small enough for current facilities.

Validation:

* the resulting model should explain current `AGRONOMIC`, `SOLAR_PLANT`, and
  `PROBE_MINE` solar behavior without making non-solar facilities ambiguous;
* unresolved future power modes should be documented as TODOs, not implemented.

## 4. Add Static Power Metadata

Once semantics are clear, add the smallest useful static data surface:

* either extend `powerData.zig` or add facility-facing power metadata in
  `facilityData.zig`;
* keep `IndType.getPowerSrc()` as the live compatibility path unless the
  replacement is fully equivalent;
* if facility power metadata is added, mirror current solar/grid assignments for
  current industry-backed facilities;
* do not change live economy behavior unless the compatibility path remains
  visibly equivalent.

Validation:

* `FacilityType` should expose enough power metadata for the future solver
  migration;
* current game behavior should not change unless explicitly documented.

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

* `data/industryData.zig`: `getPowerSrc()` should either become a compatibility
  wrapper around new power metadata or keep a TODO explaining why it cannot move
  yet.
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
