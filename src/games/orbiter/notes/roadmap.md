# Orbiter Roadmap

This file is the implementation guide from the current
[reference.md](reference.md) baseline toward the target state in
[goals.md](goals.md). Broad game design belongs in [design_doc.md](design_doc.md)
and [design_philo.md](design_philo.md). Deferred ideas belong in
[feature_ideas/ideas.md](feature_ideas/ideas.md).

Detailed active tasks belong in [todo.md](todo.md). Keep this roadmap focused
on sequencing, dependencies, and unresolved implementation choices.

## 1. Current Starting Point

Orbiter currently has:

* a live solar-system body/orbit simulation;
* body-owned economy arrays keyed by `EconLoc`;
* local economy state for resources, population, infrastructure, industries,
  ecology, government money, and construction queues;
* a single reused global `EconSolver`;
* debug-driven construction and growth through `debugAutoBuild()`;
* a transitional `BuildQueue`;
* an approximate transfer estimator;
* no live trade execution;
* no real government behavior beyond state/data stubs.

The MVP target is not a broad gameplay loop. It is a reworked, stable economic
sandbox that first restores Terra as an autonomous single economy, then proves
automatic trade between Terra, Luna, and Venus.

## 2. Roadmap Rules

Follow these constraints while sequencing work:

* keep `G_DATA` as the game-owned global runtime state surface;
* keep current implementation facts in `reference.md`, not here;
* keep target-state changes in `goals.md`, not here;
* preserve deferred ideas in `feature_ideas/` rather than deleting them;
* do not build politics, colonization, migration, vessel logistics, or explicit
  game goals into the MVP;
* keep taxes and subsidies out of Phase 1; they start in Phase 2;
* do not let Phase 2 trade work distract from restoring Terra first;
* run behavior validation after each meaningful economy rewrite slice.

## 3. Phase 0 - Alignment And Safety Rails

Goal: make the rework vocabulary explicit before changing live behavior.

Required work:

* audit names that will be replaced or split:
  * `Industry` / `Infrastructure` -> `Facility`;
  * `EconLoc` -> `SettlementType` plus `BodyLocation`;
  * current population `HUMAN` -> `dependants` / `workers`;
  * agent/requester names -> `EconAgent` groups;
  * `WORK` -> `LABOUR`;
* perform code-wide compile-clean renames for resources, facilities,
  population, and old infrastructure/industry instance names where they are
  simple and mechanically safe;
* update comments and references during the rename pass;
* identify all code paths that assume economies are stored inside `BodyComp`;
* identify all code paths that assume current `EconLoc` values imply economy
  rules;
* identify all code paths that hardcode `WORK`, `PART`, `DEPOT`, `ASSEMBLY`,
  or current infrastructure/industry tables;
* treat starred entries in `feature_ideas/resources.md` and
  `feature_ideas/facilities.md` as mandatory Phase 1 entries;
* keep non-MVP resources/facilities as commented-out enum candidates rather
  than implementing them early.

Exit condition: the first implementation slice can be described without
guessing which old concept maps to which new concept.

Archive rule: before a file receives its first major Phase 1 rewrite, copy its
pre-Phase 1 version into `src/.oldFiles/` with the same relative path. Do not
edit archived files. Keep only one archived version unless the user explicitly
asks for another.

## 4. Phase 1 - Terra Baseline

Goal: restore Terra as a stable autonomous single economy on the new model.

Phase 1 is the core economic rewrite. It should end with Terra running without
`debugAutoBuild()` as the central growth driver.

### 4.1 Economy Ownership And Location Split

Required work:

* move economies toward a game-owned global array addressed by `u32` indices;
* add an explicit review/error path if the array would exceed 1000 economies;
* replace direct body-owned economy ownership with references from bodies,
  settlements, or routes;
* split location concepts:
  * `SettlementType` describes economy rules and physical settlement form;
  * `BodyLocation` describes body-relevant travel-cost locations;
* keep MVP settlement types to `surface`, `subsurface`, `aerial`, and
  `orbital`;
* define MVP body settlement-type metadata without requiring every body to
  become a live economy in Phase 1:
  * Terra as `surface`;
  * Luna as `subsurface`;
  * Venus as `aerial`;
* keep one orbital economy per body for MVP;
* defer Lagrange economy locations, multiple orbital layers, star-hosted
  arbitrary locations, asteroid-belt aggregate economies, and mobile economies.

Validation:

* Terra initializes through the new ownership path;
* body/orbit rendering and target selection still work;
* old body-local economy assumptions are either removed or explicitly isolated.

### 4.2 Resource And Capacity Model

Required work:

* add the resource metadata needed to distinguish ordinary resources from
  capacity resources;
* mark capacity resources as non-transportable;
* model capacity-resource prices from availability rather than ordinary stock
  flow;
* keep capacity calculation inside the unified economy update pipeline for
  now;
* reserve caching for later profiling or area-use complexity;
* keep current `WORK` behavior as the transition model for labour-like
  capacity, but rename it to `LABOUR` using Canadian spelling;
* remove `FUEL` after Phase 0 once dependent code can be updated safely;
* keep `DEPOT` as the singular storage facility;
* let resources still declare their storage facility;
* aggregate `DEPOT` into one shared storage capacity pool;
* calculate excess-storage waste proportionally near the end of the economy
  update, before state publication;
* add static accessibility for extractable resources where Phase 1 data needs
  it, but defer route-facing Luna tuning to Phase 2.

Validation:

* resource totals, capacity availability, prices, and waste are visible in logs;
* non-transportable capacity resources cannot enter trade or route logic;
* Terra does not rely on old per-resource storage lanes.

### 4.3 Facility Model

Required work:

* introduce `Facility` as the implementation name for the merged
  industry/infrastructure concept;
* use the starred facility entries in `feature_ideas/facilities.md` as the
  mandatory Phase 1 set;
* keep facility categories for data readability:
  * growth;
  * extraction;
  * manufacturing;
  * service;
  * transportation;
  * capacity;
* migrate current infrastructure data into facility data where it produces or
  exposes capacities;
* migrate current industry data into facility data where it consumes or
  produces ordinary resources;
* preserve non-MVP facility entries as commented-out enum candidates;
* remove or isolate old infrastructure/industry code paths once equivalent
  facility behavior exists.

Validation:

* old Terra production/consumption roles can be expressed through facilities;
* former infrastructure capacities such as housing, storage, area support, and
  construction effort flow through the new model;
* code no longer needs separate implementation paths unless a clear local
  reason remains.

### 4.4 EconAgent Model

Required work:

* introduce `EconAgent` as the common enum group for economy actors;
* create one agent entry for each facility enum value present in an economy;
* add `POPULATION` as the whole-economy population agent for MVP;
* add one `GOVERNMENT` instance per economy;
* reserve `TRADER` for Phase 2 route agents;
* route finance, savings, taxes, subsidies, and construction requests through
  agents;
* avoid per-facility-instance agents by default.

Validation:

* existing population/facility money behavior can be expressed through agents;
* agent finance is structured so `GOVERNMENT` can pay subsidies and receive
  taxes in Phase 2 without adding politics;
* logs identify which agent group paid, earned, received, or lost money.

### 4.5 Population Split

Required work:

* replace single `HUMAN` population behavior with `dependants` and `workers`;
* make births create dependants;
* convert dependants to workers at a fixed rate;
* keep MVP consumption values allowed to match, but declared separately;
* route worker output into the labour/capacity-resource model;
* defer education, wealth, laws, migration, owners, managers, engineers, and
  other population subtypes.

Validation:

* population can stabilize without hidden debug injections;
* worker capacity changes when population composition changes;
* birth/death/conversion rates are inspectable from logs.

### 4.6 Economy Update Pipeline

Goal: replace the current `EconSolver` shape with `econPipeline`.

Required work:

* use `econPipeline` as the successor name unless later implementation shows a
  better name;
* define the new economy update owner and file split before moving logic;
* keep the early version single-threaded unless there is a measured reason to
  do otherwise;
* fold solver, builder, finance, maintenance, construction, and capacity
  enforcement into one coherent update pipeline;
* separate large files by concern as the new pipeline takes shape;
* keep the pipeline deterministic and loggable.

Suggested pass order:

1. gather local state and static data;
2. calculate facility and population capacity production;
3. calculate ordinary resource demand and supply;
4. calculate capacity-resource availability and prices;
5. calculate ordinary resource access and prices;
6. update facility activity;
7. apply resource consumption/availability outcomes;
8. update population deaths, births, and dependant-to-worker conversion after
   this tick's resource consumption has happened;
9. process maintenance funding/materials/access;
10. process construction/deconstruction funding, materials, effort,
   cancellation, and refunds;
11. process agent finances, savings, and losses;
12. enforce storage and proportional waste;
13. publish state and logs.

This pass order is provisional. Change it if implementation reveals a cleaner
or more correct shape, but document the reason in the roadmap or todo.

Validation:

* `debugTestEcon()` or its successor can run the Terra economy for long spans;
* `testResFlowInvariant()` or its successor can check flow accounting;
* one tick's logs can explain resource access, capacity access, prices,
  construction, finance, and population movement.

### 4.7 Construction And Facility Lifecycle

Required work:

* audit `BuildQueue` and repair it if it is close enough to the target shape;
* replace `BuildQueue` if repair is larger or messier than rebuilding;
* fix or replace known queue caveats before relying on long-lived orders;
* define construction effort as a capacity resource;
* implement maintenance before construction because it exercises many of the
  same resource/finance paths with less extra machinery;
* route construction and maintenance funding through the owning `EconAgent`;
* allow a temporary stopgap that creates money for construction/maintenance if
  owner-funded paths block Phase 1 progress;
* allow negative savings for MVP; proper debt and fiscal-management behavior is
  post-MVP;
* let maintenance failure do nothing initially, while keeping hooks clear for
  future penalties;
* support construction, deconstruction, cancellation, and refunds coherently;
* remove `debugAutoBuild()` after real maintenance/growth paths are stable.

Known risks to resolve or replace:

* entry matching mutates the wrong queue slot;
* compaction currently does not copy entry values correctly;
* closed-entry dumping can use the wrong index;
* total-cost helpers mix integer accumulation with `f64` return values;
* construction money is simplified and not fully routed through accounts.

Validation:

* Terra can maintain and grow facilities without debug-only funding injection;
* construction cannot create or destroy resources/money except through
  documented rules.

### 4.8 Terra Balancing

Required work:

* use the starred resource and facility entries as the Phase 1 Terra data set;
* tune starting quantities, facility counts, capacity outputs, and prices;
* avoid preset taxes/subsidies in Phase 1;
* ensure the economy can reach a stable or intentionally inspectable dynamic
  state without player micromanagement.

Exit condition:

* Terra runs as a stable autonomous economy under the new model;
* `debugAutoBuild()` is no longer required for normal Terra stability;
* logs show the economy is stable for understandable reasons.

## 5. Phase 2 - Trade, Luna, And Venus

Goal: add automatic inter-economy trade, then prove Terra/Luna before adding
Venus.

### 5.1 Trade Route Data

Required work:

* define route data that references source and destination economy indices;
* create one `TRADER` agent per route;
* store route taxes, subsidies, cost settings, and basic activity state;
* represent each bidirectional route as two directional `TRADER` agents;
* give each `TRADER` a simple inventory with add/remove accessors, which can
  later become in-transit packets if needed.

### 5.2 MVP Trade Execution

Required work:

* compute source export availability and destination demand;
* buy ordinary resources from the source economy;
* sell them wholesale in the destination economy on the next tick;
* let the `TRADER` agent internalize profit and loss;
* exclude capacity resources;
* exclude migration;
* base transport cost on transported mass;
* apply route taxes and subsidies through `GOVERNMENT`;
* calculate taxes proportionally to income this tick, or previous tick if that
  is cleaner for the pipeline;
* calculate subsidies proportionally to expenses this tick;
* allow negative government savings for MVP;
* expose enough logs to explain route activity.

Validation:

* trade cannot move capacity resources;
* a route can lose money, receive subsidies, or profit without special cases;
* route trades preserve resource and money accounting under documented rules.

### 5.3 Transfer Cost Gate

Required work:

* choose a simple MVP route-cost source:
  * current `travelSolver` `deltaV`, which is already static and roughly
    best-case;
* convert `deltaV` and transported mass into a route transport cost;
* keep dynamic `deltaT`, transfer windows, route delay, and vessel-mediated
  cargo out of MVP.

Validation:

* route costs do not explode because of one bad temporary transfer geometry;
* Terra/Luna trade can remain stable under preset subsidies.

### 5.4 Extractable Resource Accessibility

Required work:

* add static accessibility rates for extractable resources;
* make Luna higher-accessibility for mineral extraction than Terra and Venus;
* expose accessibility in extraction facility output or access;
* keep depletion and exploration uncertainty deferred.

Validation:

* Luna has a clear mineral production advantage;
* Terra/Luna trade can form around minerals without scripted shipments.

### 5.5 Terra And Luna Trade Sandbox

Required work:

* initialize Luna with the minimum settlement, facility, population, and
  resource state needed for stable trade;
* define bidirectional Terra/Luna routes;
* tune taxes/subsidies and starting stocks;
* inspect whether Terra supplies something Luna needs and Luna supplies
  minerals back while processing what it can locally.

Exit condition:

* Terra and Luna can trade automatically and remain stable through route and
  agent taxation/subsidy settings.

### 5.6 Venus As Third Economy

Required work:

* use Venus as a food producer because power cannot be transferred in the MVP;
* define Venus as a live economy with its settlement type, facility set,
  population, and resource state;
* add Terra/Venus and Luna/Venus trade routes after Venus is properly defined
  as an economy;
* tune those routes so Venus can participate without destabilizing Terra/Luna;
* avoid adding colonization, politics, or atmospheric simulation depth.

Exit condition:

* Terra, Luna, and Venus remain active and stable through automatic trade.

## 6. Deferred Post-MVP Work

Keep these out of MVP unless the user explicitly promotes them:

* colonization and settlement founding;
* politics, autonomy, unrest, welfare, laws, and local governors;
* migration;
* ship modules and vessel-mediated logistics;
* dynamic transfer windows and realistic route timing;
* route or agent-owned inventories beyond what MVP trade requires;
* proper debt and fiscal-management behavior beyond negative savings;
* economy variants such as automated mines, ship-bound economies, cyclers, and
  regional aggregates;
* richer player goals, crises, victory/failure conditions, and fun-first
  gameplay loops.

## 7. Open Implementation Decisions

These should be prompted to the user when they become blockers:

* exact Phase 1 file split for economy update, facilities, construction, and
  finance;
* exact internal split of `econPipeline`;
* whether specific `BuildQueue` internals are repaired or replaced after audit;
* exact behaviour when maintenance is unfunded after the no-op MVP hook;
* whether taxes use current-tick or previous-tick income;
* exact facility/resource data values needed to satisfy the user's stability
  expectations.

## 8. Validation

Docs-only changes need no build.

Implementation slices should usually validate with:

* `zig build`;
* `zig build check_games`;
* `zig build test`;
* long-run Terra economy logs after Phase 1 slices;
* long-run Terra/Luna and Terra/Luna/Venus trade logs after Phase 2 slices;
* resource/money flow invariant checks whenever accounting changes.

Do not run formatting passes such as `zig fmt`.
