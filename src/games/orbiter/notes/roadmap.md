# Orbiter Roadmap

This file is the implementation guide from the current
[reference.md](reference.md) baseline toward the target state in
[goals.md](goals.md). Broad game design belongs in [design_doc.md](design_doc.md)
and [design_philo.md](design_philo.md). Deferred ideas belong in
[feature_ideas/ideas.md](feature_ideas/ideas.md).

Detailed active tasks belong in [todo.md](todo.md). Keep this roadmap focused
on remaining implementation order, dependencies, and unresolved implementation
choices.

## 1. Current Progress

The first rework scaffolds are in place:

* economies are game-owned through `G_DATA.economies` / `EconomyStore` and are
  referenced by `EconomyId`;
* body economy ownership has moved to economy-id references, with
  `BodyComp.getEcon()` kept as a compatibility helper;
* `SettlementType` and `BodyLocation` exist beside the temporary combined
  `EconLoc`;
* Terra, Luna, and Venus have MVP settlement metadata, but only Terra is a
  normal active economy at startup;
* `LABOUR` replaced the old worker-capacity resource role, and resource flags
  moved into `resBooleanData`;
* ordinary stockpiled resources use one shared `DEPOT` storage pool;
* static `FacilityType` data exists as the merged facility vocabulary, including
  facility categories, capacities, resource rows, mapping helpers, and
  `IS_SOLAR_SCALED`;
* static facility names have moved away from several old implementation names
  such as `GROUND_MINE` and `FOUNDRY`;
* current live runtime behavior still uses `InfType`, `IndType`, `infState`,
  `indState`, `IndType.getPowerSrc()`, `EconSolver`, `BuildQueue`, and
  `debugAutoBuild()`;
* no live route trade, trader agents, route taxes/subsidies, or meaningful
  government behavior exists yet.

The MVP target is still a reworked economic sandbox, not a broad gameplay loop:
first restore Terra as an autonomous single economy, then prove automatic trade
between Terra, Luna, and Venus.

## 2. Roadmap Rules

Follow these constraints while sequencing work:

* keep `G_DATA` as the game-owned global runtime state surface;
* keep current implementation facts in [reference.md](reference.md);
* keep target-state design in [goals.md](goals.md);
* preserve deferred ideas in `feature_ideas/` rather than deleting them;
* keep taxes and subsidies out of Phase 1;
* do not let Phase 2 trade work distract from restoring Terra first;
* run behavior validation after each meaningful economy rewrite slice.

Archive rule: before a file receives its first major Phase 1 rewrite, copy its
pre-rewrite version into `src/.oldFiles/` with the same relative path. Do not
edit archived files. Keep only one archived version unless the user explicitly
asks for another. Files already archived for this rework do not need a second
archive for normal follow-up edits.

## 3. Phase 1 - Terra Baseline

Goal: restore Terra as a stable autonomous single economy on the new model.
Phase 1 ends when Terra can run without `debugAutoBuild()` as the central
growth driver.

### 3.1 Facility Runtime Migration

Status: next active loop, tracked in [todo.md](todo.md).

Move live economy behavior from the old infrastructure/industry split onto the
facility model before building the new pipeline around it. This should be a
behavior-invariance pass first: switch the live-facing enum/state/helper surface
to `FacilityType` while preserving current Terra behavior as much as possible.

Required work:

* rename `PART` to `STRUCTURE` before deeper facility behavior depends on the
  old name;
* remove `FUEL`, `REFINERY`, and `PROBE_MINE` before the live `FacilityType`
  move unless implementation reveals a non-trivial dependency;
* keep `PowerSrc` as a temporary legacy hook only while live production still
  reads `IndType`;
* introduce `facState`, using `fac` as the short form for facilities in contexts
  alongside names such as `inf`, `ind`, `pop`, and `res`;
* migrate facility counts, activity/use, capacities, build costs, maintenance,
  ecology inputs, finance, and debug growth callers to facility-facing helpers;
* scale live solar production from `FacilityType.IS_SOLAR_SCALED` and local sun
  access, then remove `PowerSrc` as soon as the live migration is stable;
* remove or quarantine old infrastructure/industry paths after equivalent
  facility behavior exists.

Validation:

* the code compiles and the simulation can run;
* short/medium simulation behavior remains as stable as the current baseline,
  where the economy still crashes after a few simulated years;
* old Terra production and consumption roles still work through facilities;
* former infrastructure capacities such as area, storage, housing, and
  construction effort flow through facility data;
* behavior differences from the old split are intentional, visible, and small
  enough to diagnose before the pipeline rewrite begins;
* no new long-term split between infrastructure and industry survives without a
  clear local reason.

Exit condition:

* live economy code can use the combined facility surface directly enough that
  `econPipeline` does not need to be designed around the old split.

### 3.2 Agent And Pipeline Shape

Define the durable actor and tick-shape boundaries after the facility surface is
live enough to target.

Required work:

* define the durable `EconAgent` surface that will cover facilities,
  population, government, and later route traders;
* decide how facility, population, government, and route agents expose demand,
  supply, finance, construction requests, and policy hooks;
* keep population as one monolithic `POPULATION` agent until the dependant /
  worker split exists;
* keep government as one monolithic `GOVERNMENT` agent until local/stellar
  government split work has a concrete need;
* model trade as two directional `TRADER` agents per bidirectional route, but
  keep them tied to the same route so later financial equalisation or shared
  route accounting can represent back-and-forth freighter use;
* decide the first `econPipeline` owner/file split and tick-order shape;
* audit `BuildQueue`, with replacement allowed if it is cleaner than repair;
* keep storage overflow as current storage-use proportional waste until the new
  pipeline can preserve producer attribution.

Agent design guidance:

* use `EconAgent` as an identity, ownership, policy, and accounting boundary;
* let agents gather or compute their own intents where that keeps rules local,
  such as desired production, maintenance demand, construction requests,
  savings, taxes, subsidies, or trader buy/sell intent;
* allow agents controlled access to their own pipeline scratch state when
  useful, especially savings/finance state used to fund construction or
  maintenance;
* keep the pipeline as the owner of canonical per-tick buffers and final state
  mutation;
* have agents submit flow/finance/construction intents to pipeline-owned
  buffers rather than mutating global resource buffers directly;
* keep hot resource loops table-driven where possible. Avoid making every
  resource/action update pay for heavy agent dispatch or unnecessary
  abstraction;
* prefer thin agent helpers plus explicit pipeline phases over opaque
  agent-owned mini-solvers.

Validation:

* the first pipeline implementation can be written against facility and agent
  concepts rather than legacy infrastructure/industry lanes;
* logs and data names make clear which actor paid, earned, received, requested,
  or lost resources/money;
* the design leaves room for Phase 2 route taxes/subsidies without adding
  politics or trade behavior in Phase 1.

### 3.3 Resource And Capacity Follow-Through

Complete the resource model changes that need live pipeline support.

Required work:

* price capacity resources from availability rather than ordinary stock flow;
* represent or expose capacity concepts needed by Phase 1, including labour,
  area, housing, storage, construction effort, and energy/power capacity;
* keep resource storage routing data-backed enough to replace hardcoded
  `getInfStore()` behavior when the facility migration makes that practical;
* update dependent balancing/data after the `FUEL` removal and `PART` ->
  `STRUCTURE` rename are complete;
* move shared-depot overflow to production-share proportional waste after
  producer attribution exists in the pipeline.

Validation:

* capacity resources cannot enter trade or ordinary stock logic;
* resource totals, capacity availability, prices, and waste remain visible in
  logs;
* Terra no longer relies on old per-resource storage lanes.

### 3.4 Economy Update Pipeline

Replace the current `EconSolver` shape with `econPipeline`.

Required work:

* fold solver, construction, maintenance, finance, capacity enforcement, and
  state publication into one coherent tick pipeline;
* keep the early version deterministic and single-threaded unless profiling
  proves otherwise;
* split large files by concern only as the new ownership becomes clear;
* process maintenance before construction;
* route construction and maintenance funding through owning `EconAgent`s;
* publish enough per-tick state and logs to explain resource access, capacity
  access, prices, construction, finance, and population movement.

Suggested pass order:

1. gather economy state and static data;
2. resolve prices from the previous tick's state and current availability;
3. update production/activity targets;
4. query agents for maximum resource consumption and other demand intents;
5. compute potential shortages and capacity bottlenecks;
6. resolve resource and capacity access rates;
7. query agents for real production and consumption at resolved access/activity;
8. update stocks and agent finances;
9. update population deaths, births, and dependant-to-worker conversion after
   this tick's resource consumption;
10. process maintenance funding, materials, access, and consequences;
11. process construction/deconstruction funding, materials, effort,
   cancellation, and refunds;
12. process remaining agent finance changes, savings, and losses;
13. enforce storage and proportional waste;
14. publish state and logs.

This order is provisional. Change it if implementation reveals a cleaner or
more correct order, but document the reason in this file or [todo.md](todo.md).

Validation:

* `debugTestEcon()` or its successor can run Terra for long spans;
* `testResFlowInvariant()` or its successor can check flow accounting;
* one tick's logs can explain the major economic outcomes without reading code.

### 3.5 Construction And Facility Lifecycle

Make construction, maintenance, and facility changes coherent enough to replace
debug growth.

Required work:

* apply the `BuildQueue` audit result: repair it if small, replace it if repair
  is messier than rebuilding;
* fix or replace queue matching, compaction, closed-entry handling, total-cost
  helpers, and simplified money handling before relying on long-lived orders;
* keep construction effort as a capacity resource or capacity-like pipeline
  value by default, exposed by `ASSEMBLY` / future construction facilities and
  likely fed by `LABOUR`;
* keep construction effort separate from direct `LABOUR` allocation unless a
  later simplification proves cleaner. A distinct construction-capacity lane
  keeps build spikes from consuming all available labour and preserves the
  visible role of construction facilities;
* support construction, deconstruction, cancellation, and refunds through
  documented resource and money rules;
* allow negative savings for MVP if needed; proper debt and fiscal management
  are post-MVP;
* let maintenance failure initially be a no-op or simple penalty, but keep the
  hook explicit;
* retire `debugAutoBuild()` after real maintenance and growth paths can keep
  Terra active.

Validation:

* Terra can maintain and grow facilities without debug-only funding injection;
* construction cannot create or destroy resources or money except through
  documented temporary rules.

### 3.6 Population Split

Replace the single live `WORKER` population model with the MVP dependant/worker
split.

Required work:

* add dependant and worker population state/data;
* make births create dependants;
* convert dependants into workers at a fixed rate;
* keep MVP consumption values allowed to match, but declare them separately;
* route worker output into the labour/capacity-resource model;
* keep education, wealth, law, migration, owners, managers, engineers, and
  other population subtypes deferred.

Validation:

* worker capacity changes when population composition changes;
* birth, death, and conversion rates are inspectable from logs;
* population can stabilize without hidden debug injections.

### 3.7 Terra Balancing

Tune the completed Phase 1 model into a stable single-economy sandbox.

Required work:

* use the Phase 1 resource and facility set from `feature_ideas/` as the target
  data set, adjusted for implementation reality;
* tune starting quantities, facility counts, capacity outputs, prices,
  maintenance, construction, and population rates;
* avoid preset taxes/subsidies in Phase 1;
* keep logs focused enough to explain whether instability is caused by
  resource access, capacity access, finance, construction, or population.

Exit condition:

* Terra runs as a stable or deliberately inspectable autonomous economy under
  the new model;
* `debugAutoBuild()` is no longer required for normal Terra stability.

## 4. Phase 2 - Trade, Luna, And Venus

Goal: add automatic inter-economy trade, prove Terra/Luna first, then add Venus
as the third-economy stability test.

### 4.1 Trade Route Data And Trader Agents

Required work:

* define route data that references source and destination economy ids;
* create one `TRADER` agent per directional route;
* represent bidirectional routes as two directional traders;
* store route cost settings, tax/subsidy settings, activity state, and simple
  trader inventory;
* keep route-local inventory simple unless timing or vessel logistics later
  require in-transit packets.

### 4.2 MVP Trade Execution

Required work:

* compute source export availability and destination demand;
* buy ordinary resources from the source economy;
* sell them wholesale in the destination economy on the next tick;
* exclude capacity resources and migration;
* let the `TRADER` agent internalize profit and loss;
* apply route taxes/subsidies through `GOVERNMENT`;
* expose enough logs to explain route activity and money/resource accounting.

Validation:

* trade cannot move capacity resources;
* a route can lose money, receive subsidies, or profit without special cases;
* route trades preserve resource and money accounting under documented rules.

### 4.3 Route Cost Gate

Required work:

* use the current approximate `travelSolver` `deltaV` output as the MVP
  transfer-cost source;
* convert `deltaV` and transported mass into a route transport cost;
* keep dynamic `deltaT`, transfer windows, route delay, and vessel-mediated
  cargo out of the MVP.

Validation:

* route costs do not explode because of one bad temporary transfer geometry;
* Terra/Luna trade can remain stable under preset subsidies.

### 4.4 Luna And Venus Economy Tuning

Required work:

* replace the current equal extractable-accessibility placeholders with tuned
  body/resource values;
* expose accessibility in extraction facility output or access;
* make Luna a higher-accessibility mineral source than Terra and Venus;
* initialize Luna with the minimum settlement, facility, population, and
  resource state needed for stable trade;
* define and tune Terra/Luna routes first;
* add Venus afterward as a food producer enabled by high solar access;
* define Terra/Venus and Luna/Venus routes only after Venus is a live,
  understandable economy.

Exit condition:

* Terra and Luna can trade automatically and remain stable;
* Terra, Luna, and Venus can remain active and stable through automatic trade
  after Venus is added.

## 5. Deferred Post-MVP Work

Keep these out of the MVP unless the user explicitly promotes them:

* colonization and settlement founding;
* politics, autonomy, unrest, welfare, laws, and local governors;
* migration;
* ship modules and vessel-mediated logistics;
* dynamic transfer windows and realistic route timing;
* route or agent-owned inventories beyond what MVP trade requires;
* proper debt and fiscal-management behavior beyond negative savings;
* Lagrange settlement economies, multiple orbital layers, star-hosted arbitrary
  economies, asteroid-belt aggregates, mobile economies, and cyclers;
* richer player goals, crises, victory/failure conditions, and fun-first
  gameplay loops.

## 6. Open Implementation Decisions

Prompt the user when one of these becomes a blocker:

* exact file split for `EconAgent`, `econPipeline`, construction, finance, and
  `facState`;
* exact replacement shape for `BuildQueue`;
* exact maintenance-failure behavior after the initial MVP hook;
* whether construction effort remains a distinct capacity resource or becomes a
  direct `LABOUR` allocation in a later simplification pass;
* exact facility/resource data values needed to satisfy the user's stability
  expectations;
* whether taxes use current-tick or previous-tick income in Phase 2.

## 7. Validation

Docs-only changes need no build.

Implementation slices should usually validate with:

* `zig build`;
* `zig build check_games`;
* `zig build test`;
* flow-invariant tests whenever resource or money accounting changes;
* long-run Terra economy logs after Phase 1 slices;
* long-run Terra/Luna and Terra/Luna/Venus trade logs after Phase 2 slices;
* manual simulation runs as the final stability check.

Do not run formatting passes such as `zig fmt`.
