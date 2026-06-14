# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. Use
[reference.md](reference.md) as the current implementation snapshot,
[goals.md](goals.md) as the target-state authority, and
[roadmap.md](roadmap.md) as the implementation sequence.

Phase 1B resource/storage scaffold is complete. The next slice starts Phase 1C
from roadmap section 4.3: introduce the first unified `Facility` data surface
without replacing the whole economy solver yet.

## Phase 1C - Facility Data Baseline

Goal: create a compact, inspectable `Facility` model that can express the
current infrastructure and industry roles before the solver, construction, and
agent layers are migrated onto it.

This slice should stay focused. Do not replace `EconSolver`, remove
`Infrastructure`/`Industry` runtime state, split population, add trade routes,
or remove `debugAutoBuild()` yet. Those need later slices once facility data can
represent the old behavior cleanly.

## Validated Direction

The first facility pass is a parallel static data/model surface, not a live
runtime migration.

Validated decisions:

* name the new enum `FacilityType`;
* create `src/games/orbiter/data/facilityData.zig`;
* preserve existing infrastructure and industry names unless a specific name is
  clearly misleading in the new facility vocabulary;
* keep `InfType`, `IndType`, `infState`, `indState`, `EconSolver`,
  `BuildQueue`, and `debugAutoBuild()` hooked into live logic for this slice;
* copy existing infrastructure/industry values into facility-shaped data, but
  do not rebalance consumption, production, maintenance, or build costs yet;
* leave power-source redesign for the next pass after the facility data shape is
  present;
* defer production-share proportional storage waste until the future
  `econPipeline` pass can preserve producer attribution.

## 1. Archive Before New Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-rewrite
version into `src/.oldFiles/` with the same relative path. Do not edit archived
files and keep only one archived version unless the user explicitly asks for
another.

Likely new archive candidates for this slice:

* `src/games/orbiter/data/facilityData.zig`, if replacing an existing draft;
* `src/games/orbiter/gameDef.zig`, if the public type exports change;
* `src/games/orbiter/gameGlobals.zig`, if static data loading changes;
* any current infrastructure/industry file that receives more than pointer or
  compatibility comments.

Files already archived during Phase 1A or Phase 1B can be edited without
creating another copy unless the user asks for a second archive.

## 2. Define The Facility Surface

Add the smallest useful `Facility` data layer:

* introduce `FacilityType` or a clearly better name if implementation makes one
  obvious;
* preserve current infrastructure/industry names as either direct facility enum
  cases or documented compatibility mapping;
* keep facility categories for readability:
  * growth;
  * extraction;
  * manufacturing;
  * service;
  * transportation;
  * capacity;
* keep non-MVP facility ideas as commented-out candidates, not active data;
* expose mass, area cost, construction effort, pollution, capacity output, and
  resource input/output/cost rows where they already exist in old data.

Validation:

* the new data surface compiles;
* current infrastructure and industry roles can be represented without guessing;
* no old runtime state is removed before equivalent behavior is ready.

## 3. Map Current Infrastructure And Industry

Create a migration map from old data to facilities:

* `HABITAT`, `DEPOT`, `HOUSING`, and `ASSEMBLY` should map to capacity/service
  roles;
* `AGRONOMIC`, `HYDROPONIC`, `WATER_PLANT`, `SOLAR_PLANT`, `POWER_PLANT`,
  `REFINERY`, `GROUND_MINE`, `FOUNDRY`, `FACTORY`, and `PROBE_MINE` should map
  to extraction/manufacturing/growth roles;
* preserve existing `canBeBuiltIn()` behavior either directly or through a
  documented compatibility helper;
* document where solar/grid power-source behavior currently maps, but do not
  port it to facility metadata until the next pass defines power-source rules;
* do not merge old state grids yet unless the facility layer can fully replace
  them in one obvious step.

Validation:

* a future migration can identify which old enum case each facility replaces;
* Terra's current seeded setup has a facility equivalent for every live old
  infrastructure and industry count.

## 4. Resource And Capacity Rows

Keep the data rows broad enough for Phase 1 but avoid solving the whole economy:

* represent ordinary resource consumption and production for facilities;
* represent maintenance and build costs without hardcoding `PART` as the only
  possible resource in the new shape;
* represent capacity outputs such as housing, storage, area, and construction
  effort explicitly;
* keep `LABOUR` as the current worker-provided capacity resource;
* avoid adding construction-effort as a live resource until the pipeline slice.

Validation:

* existing values can be copied or mapped without changing live economy numbers;
* data comments distinguish active behavior from future capacity-resource work.

## 5. TODO Comment Review - Pending User Validation

Do not edit, remove, or expand these source TODO comments until the user
validates their disposition.

Suggested address in Phase 1C:

* `data/infrastructureData.zig`: facility-fold TODOs can be replaced once the
  new facility surface is present.
* `data/industryData.zig`: facility-fold TODOs can be replaced once the new
  facility surface is present.

Suggested defer:

* `data/industryData.zig`: `getPowerSrc()` should not be ported yet. Add a note
  that power-source behavior needs a dedicated design pass before it becomes
  facility metadata.
* `data/resourceData.zig`: `getInfStore()` data-backed routing should wait
  until storage facilities survive the facility migration.
* `data/resourceData.zig`: individualized `LIMIT_D` can be stripped once no live
  code depends on it. Keep cached per-resource `LIMIT` only if compatibility
  logs/caps still need it during the facility migration.
* `econ/econSolver.zig`: production-share proportional storage waste should
  wait for the future `econPipeline` pass ordering.

## 6. Out Of Scope For This Slice

Do not do these as part of Phase 1C unless the user changes the scope:

* removing old `InfType`, `IndType`, `infState`, or `indState`;
* migrating `EconSolver` to `econPipeline`;
* replacing `BuildQueue`;
* dependant/worker population split;
* route trade or `TRADER` agents;
* taxes, subsidies, or government behavior;
* Lagrange, mobile, asteroid-belt, or star-hosted economies;
* tuning Luna mineral access or Venus food production;
* redesigning or migrating power-source behavior.
