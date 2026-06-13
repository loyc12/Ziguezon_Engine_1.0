# Orbiter Reference

This file is the descriptive snapshot for the current Orbiter implementation.
When this file disagrees with code, inspect code first and refresh this file.
Broad game design belongs in [../design_doc.md](../design_doc.md) and
[../design_philo.md](../design_philo.md). Rework target state belongs in
[goals.md](goals.md). Implementation order belongs in [roadmap.md](roadmap.md).
Active task slices belong in [todo.md](todo.md).

This reference was audited against the current Zig sources, not only against
the older planning notes.

## 1. Purpose

Orbiter is a solar-system economy sandbox under `src/games/orbiter`. It
currently combines:

* engine `World` component stores for bodies, transforms, shapes, sprites, and
  orbits;
* an engine `World` relation for orbit parentage;
* static data grids for bodies, resources, population, infrastructure,
  industry, vessels, power, government, and transfer data;
* body-local economy slots for ground, orbit, and Lagrange-point locations;
* a weekly economy solver;
* a transitional build queue;
* debug automation and log-heavy validation surfaces.

The current game is a simulation/debug sandbox, not a complete playable loop.
Trade execution, player policy, local government behavior, autonomous
non-debug construction, and economy UI are not live.

## 2. Runtime Ownership

`gameDef.zig` exports the Orbiter-facing type surface. `gameGlobals.zig` owns
global runtime state through `G_DATA`.

`G_DATA` contains:

* `GameTimes` for simulation speed and accumulated body/economy step offsets;
* `TargetInfo` for target selection and camera-follow state;
* cached `CompView` values in `OrbiterViews`;
* `BodyRegistry`, which maps `BodyName` values to live engine `EntityId`s;
* `orbitParentIds`, a cache derived from the `Orbits` relation store.

`OnGameStart` loads static data matrices. `OnGameOpen` registers World stores
and initializes the stellar system. `OnGameClose` destroys registered body
entities and unregisters Orbiter's World stores.

Orbiter registers:

* `eng.TransComp`;
* `eng.ShapeComp`;
* `eng.SpriteComp`;
* `OrbitComp`;
* `BodyComp`;
* `Orbits`, a dataless many-to-one relation from orbiting body to parent body.

The `Orbits` relation is the authoritative live parent relationship. The
`orbitParentIds` array is a rebuilt cache for hot lookup.

## 3. Time And Controls

The engine still owns base ticking and rendering. Orbiter layers its own
simulation time over engine ticks through `GameTimes`.

Speed settings are:

* paused;
* second;
* minute;
* hour;
* day;
* week;
* month;
* year.

`bodyStepLen` is one minute. `econStepLen` is one week. Each engine tick adds
the current speed's seconds-per-step to body and economy offsets. Body and
economy ticks consume their own offsets independently.

Current controls include:

* `Space` pause toggle;
* `O` force world tick while paused;
* `J` / `K` or keypad subtract/add target cycling;
* `F` camera follow toggle;
* `U` / `I` or keypad divide/multiply speed changes;
* WASD/arrow camera pan when not following;
* mouse-wheel zoom;
* `R` camera reset;
* Shift + number debug injections into Terra ground economy.

## 4. Stellar System

`StellarBodyName` currently includes Sol, inner planets, Luna, Mars moons,
several main-belt bodies, the giant planets, and `DEBUGY`. Many additional
objects are commented out in the enum and data file.

`StellarMetricEnum` stores:

* mass;
* radius;
* periapsis;
* apoapsis;
* longitude of periapsis;
* body type;
* atmosphere density.

`StellarBodyType` controls display size, display colour, Lagrange-point count,
and valid economy-location count. Stars have no economy locations in practice.
Planets can host ground, orbit, and L1-L5. Planetoids and moons can host ground,
orbit, L1, and L2. Moonlets, asteroids, and comets only host ground and orbit.

`initStellarSystem()` creates one entity per body in `bodyOrder`, registers body
ids in `BodyRegistry`, adds `Orbits` relation rows for non-star bodies, adds
components, then refreshes transfer nodes.

Sol has no `OrbitComp`. Other bodies receive:

* `OrbitComp`;
* `TransComp`;
* `BodyComp`;
* `ShapeComp`.

Body rendering uses `ShapeComp.minSize` from `StellarBodyType`.

## 5. Orbital Simulation And Transfer Estimation

`OrbitComp` stores orbital radius range, eccentricity, period, orientation,
angular state, colour, and cached derived values. Body positions are updated in
`tickOrbiters()` when the body-step offset crosses the body tick length.

Orbiter renders:

* orbital paths;
* velocity/debug overlays for the selected body;
* Lagrange-point overlays for the selected body;
* body shapes in reverse body order so planets draw above moons.

Transfer estimation is live but approximate. `travelSolver.zig` maintains a
`TransferNode` cache keyed by body order. It is refreshed after stellar setup
and after orbital movement. `estimateTransfer()` estimates local, nested, and
common-frame transfers using body ids and economy locations.

Public transfer data:

* `BodyEconPair` / split helpers for body-location composite keys;
* `OrbitalData` for current economy location orbit snapshots;
* `TravelData` with `deltaE`, `deltaV`, and `deltaT`;
* `estimateTransferPair()` as a pair-wrapper over `estimateTransfer()`.

`updateOrbitalDataEntry()` updates per-economy orbital snapshots and the
economy's current raw sunshine. Lagrange-point positions are still approximated
from the parent body position/velocity in this snapshot path.

## 6. Economy Locations And Activation

Each `BodyComp` owns an `[EconLoc.count]Economy` array.

`EconLoc` values are:

* `GROUND`;
* `ORBIT`;
* `L1`;
* `L2`;
* `L3`;
* `L4`;
* `L5`.

`softInitAllEcons()` initializes all locations as valid but inactive shells.
`quickInitEcon()` hard-initializes a location only if the body type can host it.

At startup:

* Terra ground is activated and debug-seeded with `debugSetEconState(10_000,
  sunshine)`;
* stress-test mode can activate every legal non-Terra/non-ground duplicate
  location with a smaller debug seed;
* there is no player or government path that activates new locations yet.

Terra is hardcoded as atmospheric. Other ground bodies currently hard-init with
no atmosphere. Non-ground economies get a large abstract area and no atmosphere.

## 7. Economy State

`Economy` owns:

* location, validity, activity, atmosphere, step count, sunshine, and sun access;
* optional `EcoState`;
* optional `BuildQueue`;
* resource state;
* population state;
* infrastructure state;
* industry state;
* agent average state;
* area state;
* government monetary state.

`hardInit()` clears all state grids, initializes resource limits and base
prices, sets industry activity targets to `1.0`, initializes the build queue,
updates area data, and creates ecology only for ground economies with
atmosphere.

`tryTick()` exits unless the economy is valid and active. A live tick:

1. updates sunshine;
2. runs pre-step metrics: resource caps, population caps, area, infrastructure
   usage, ecology, and inflation stub;
3. runs `EconSolver.stepEcon()`;
4. ticks the build queue;
5. runs the local-government stub;
6. runs debug auto-build;
7. logs metrics.

## 8. Data Model

Current resources:

* `WORK`;
* `FUEL`;
* `FOOD`;
* `WATER`;
* `POWER`;
* `ORE`;
* `INGOT`;
* `PART`.

Resource metrics include mass, decay rate, deprecated growth rate, storage rate,
base price, price elasticity, and price dampening. `WORK` stores through
`HOUSING`; all other resources currently store through `DEPOT`.

Current population types:

* `HUMAN`.

Human population produces `WORK`, consumes `FOOD`, `WATER`, `POWER`, and
`PART`, and has mortality pressure from water, food, and power shortages.

Current infrastructure:

* `HABITAT`;
* `DEPOT`;
* `HOUSING`;
* `ASSEMBLY`.

Infrastructure metrics include mass, area cost, construction effort cost,
pollution, and capacity. Infrastructure resource costs currently use `PART` for
build and maintenance.

Current industries:

* `AGRONOMIC`;
* `HYDROPONIC`;
* `WATER_PLANT`;
* `SOLAR_PLANT`;
* `POWER_PLANT`;
* `REFINERY`;
* `GROUND_MINE`;
* `FOUNDRY`;
* `FACTORY`;
* `PROBE_MINE`.

Industry metrics include mass, area cost, construction effort cost, and
pollution. Industry resource matrices define operational consumption,
operational production, `PART` build cost, and `PART` maintenance cost.

Known data caveat: `IndMetricEnum.CNST_COST` exists, but the industry
`loadIndustryData()` build-cost section currently writes `.AREA_COST` instead
of `.CNST_COST`. Treat industry construction-effort data as suspect until that
loader is fixed.

`PowerSrc` exists with `GRID` and `SOLAR`, but its metric grid only has a dummy
metric. It is currently used mainly by industry to decide whether production is
sun-access scaled.

`VesType` exists with probe, shuttle, starship, and station metrics. Vessels do
not have construction, state, lifecycle, or trade integration.

Government policy and monetary data types exist, but runtime policy storage and
government behavior are not implemented.

## 9. Area, Sunshine, And Ecology

Area state tracks inhabited fraction, body surface area, land, buildable
capacity, available area, and used area.

On atmospheric ground economies, buildable capacity is land plus habitat area.
On non-ground or non-atmospheric economies, buildable capacity comes from
habitats only.

`HABITAT` generates usable area instead of consuming area. Other infrastructure
and industries consume area through their metric tables.

Sun access is derived from raw sunshine and location:

* ground applies a loss factor and can be penalized by overdeveloped surface
  coverage;
* orbit gets a near-full factor;
* Lagrange locations currently use raw sunshine.

Ecology exists only for atmospheric ground economies. `EcoState` tracks
development, pollution, target ecological factor, and damped ecological factor.
Pollution is computed from population count, infrastructure count/use, and
industry count/activity. Pollution-reducing infrastructure is not implemented.
The ecological factor is currently not wired into agronomic output because that
logic is commented out in the solver.

## 10. Economy Solver

`EconSolver.stepEcon()` uses a single reused global solver instance. It is not
thread-safe.

Live solver phases:

1. max flow;
2. resource access;
3. action rates;
4. consumption;
5. production;
6. finances;
7. construction placeholder;
8. growth and decay;
9. economy-state publication.

Population operational consumption/production is live.

Industry operational consumption/production is live. Solar-powered industries
scale operational inputs and outputs by sun access.

Infrastructure operational max flow and solver-side usage are stubbed, but
infrastructure maintenance and build consumption still flow through the solver.

Maintenance and build access are still centered on `PART`, even though the
metric tables are shaped for all resources.

The solver updates:

* population fulfilment;
* industry activity from target and resource access;
* resource consumption and decay;
* resource production;
* resource stock clamps;
* resource prices from flow demand/supply;
* population finances and savings;
* industry finances, savings, and next-tick activity targets;
* population count via deaths, starvation, births, and population cap;
* resource counts/deltas/access;
* agent average access/action metrics.

Stubbed or inactive solver surfaces include:

* government flow/finance;
* commerce flow/finance;
* infrastructure max flow;
* infrastructure resource access;
* solver-side infrastructure usage;
* infrastructure finances;
* infrastructure count orders;
* industry count orders;
* inflation.

`debugTestEcon()` and `testResFlowInvariant()` exist as validation helpers.
The invariant helper is not called in the normal phase order.

## 11. Build Queue

`BuildQueue` is live but transitional. It is created per hard-initialized
economy.

Current buildable construct tags:

* infrastructure;
* industry.

Vessels are commented out in `Construct`.

Requester tags include population, infrastructure, industry, government, and
none. Commerce is commented out.

Entry types:

* `CNSTR`;
* `RECYC`;
* `DESTR`.

Entry modes:

* `ADD_TO`;
* `SET_TO`;
* `RAISE_TO`;
* `LOWER_TO`;
* `CANCEL`.

`BuildEntry` tracks stashed resources, stashed funds, stashed construction
effort, remaining unit count, construct, requester, type, and priority.

`BuildQueue.tickQueue()`:

* derives construction effort from `ASSEMBLY.CAPACITY * ASSEMBLY.COUNT`;
* lets entries buy resources from local stocks with stashed funds;
* grants construction effort sequentially;
* calls `Economy.tryBuilding()` or `tryDestroying()`;
* updates ASSEMBLY usage from consumed construction effort;
* logs queue state.

Known queue caveats:

* matching in `tryAddEntry()` checks whether any matching entry exists but then
  mutates the current loop entry, so it can touch the wrong entry;
* `compactEntries()` assigns a local pointer rather than copying entry values;
* `tickQueue()` increments `idx` before dumping a closed entry, so it can dump
  the following slot;
* total-cost helpers accumulate into integer locals despite returning `f64`;
* `BuildEntry.getTotalCashCost()` calls the wrong helper shape;
* `BuildEntry.deactivate()` declares `bool` but does not return a value;
* construction money currently appears/disappears in simplified ways rather
  than routing through full agent accounts.

## 12. Debug Auto-Build

`debugAutoBuild()` is the current infrastructure/industry growth and decay
driver. It runs after each economy solver tick.

It:

* grows infrastructure when usage exceeds a threshold;
* decays infrastructure when usage is low;
* clamps ASSEMBLY growth/decay relative to population;
* grows industries when activity target and work access are high;
* dampens industry growth when output resources are oversupplied;
* recycles industries when activity target is low;
* queues construction/recycling entries through `BuildQueue`.

Infrastructure entries can receive a large fake funding injection when they
have no savings. Industry entries rely on industry savings. This is debug
scaffolding, not a stable economy design.

## 13. Government, Trade, Vessels, And UI

Government:

* policy-rate type aliases and monetary state exist;
* `Economy.govState` exists;
* `tickLocalGov()` is a stub;
* tax, subsidy, grant, government construction, and activation logic are not
  implemented.

Trade:

* transfer estimation exists;
* per-economy orbital snapshots exist;
* trade signals, matching, cargo records, departure/arrival accounting, and
  tariffs are not implemented.

Vessels:

* data metrics exist;
* no vessel state, construction, movement, or cargo integration exists.

UI:

* target HUD, pause overlay, speed indicator, and camera-follow indication
  exist;
* economy inspection is log/debug driven;
* there is no player-facing economy or policy UI.

## 14. Validation Notes

Docs-only changes need no build.

Behavior changes should usually validate with:

* `zig build`;
* `zig build check_games`;
* `zig build test`;
* focused economy logging through `debugTestEcon()` when solver behavior
  changes;
* `testResFlowInvariant()` when changing flow accounting.

Do not run formatting passes such as `zig fmt`.
