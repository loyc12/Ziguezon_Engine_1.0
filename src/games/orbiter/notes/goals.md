# Orbiter Goals

This file records the target state for the current Orbiter rework. Broad game
design belongs in [design_doc.md](design_doc.md), broad design philosophy
belongs in [design_philo.md](design_philo.md), current implementation facts
belong in [reference.md](reference.md), and deferred ideas belong in
[feature_ideas/ideas.md](feature_ideas/ideas.md).

Implementation sequencing belongs in [roadmap.md](roadmap.md). Short active
tasks belong in [todo.md](todo.md).

## 1. MVP Purpose

The MVP is an economic-simulation recovery target, not a full gameplay target.
Its purpose is to bring Orbiter's economy back to a stable, active,
autonomous state using the reworked underlying systems.

Exact stability criteria should be chosen by the user during tuning rather than
locked in this file.

The MVP should prove that economies can remain active and stable through
automatic trade. Phase 2 should start with Terra and Luna, then add Venus as the
final third-economy test:

* Terra;
* Luna;
* Venus.

Colonization, explicit win/loss goals, politics, migration, vessel logistics,
and heavy player-facing gameplay can wait. Player controls are incidental for
this MVP and should exist mainly where they help sandbox, stabilize, or inspect
the economic simulation.

## 2. MVP Phases

### Phase 1 - Terra Baseline

Phase 1 restores Terra to a stable autonomous single-economy baseline on the
new model.

Success means Terra can run without `debugAutoBuild()` as the central growth
driver and without depending on knowingly obsolete economy structures.

Phase 1 should establish:

* the resource and capacity-resource model;
* the `Facility` model replacing the old industry/infrastructure split;
* population split into dependants and workers;
* the `econPipeline` system that succeeds the current `econSolver`;
* construction, finance, and capacity enforcement inside that pipeline;
* enough logging and inspection to diagnose one economy from a tick trace.

### Phase 2 - Trade, Luna, And Venus

Phase 2 adds the inter-economy trade sandbox. It should prove Terra and Luna
first, then add Venus as a final stability test.

Success means Terra and Luna can trade automatically and remain stable under
preset or simple player-adjustable taxes and subsidies, then Venus can be added
without breaking the sandbox.

Phase 2 should establish:

* automatic route-based trade;
* route-local `TRADER` agents;
* mass-based trade costs;
* extractable-resource accessibility;
* Luna as a high-accessibility mineral source;
* Venus as a food producer enabled by its high solar access;
* enough route taxation and subsidy behavior to stabilize or destabilize the
  sandbox deliberately.

Non-critical systems that are needed by Phase 2 can be scaffolded in Phase 1,
but they should not distract from restoring Terra first.

## 3. Player Controls

The MVP player surface can stay narrow.

Expected controls:

* Phase 2 taxes and subsidies for trade routes;
* Phase 2 taxes and subsidies for `EconAgent` groups;
* Phase 2 preset starting subsidies where needed to produce a stable
  demonstration economy.

Taxes and subsidies are defined by, paid to, and paid from the `GOVERNMENT`
agent. For the MVP, `GOVERNMENT` is the government agent currently controlled by
the player; later governance work may separate it from direct player control.
Taxes apply relative to how much money the target made. Subsidies apply relative
to how much money the target spent. This should apply uniformly to route traders
and other `EconAgent` groups.

Phase 1 should not rely on taxes or subsidies for Terra stability.

Do not add colonization controls, settlement expansion workflows, direct
facility placement, manual shipment routing, per-ship command, or explicit
game goals for this MVP unless the user revises the target.

## 4. Economy Ownership And Locations

Economies should become game-owned data rather than body-owned arrays. The
game should hold a global economy array addressed by simple `u32` economy
indices. If the array ever needs to exceed 1000 economies, the code should
throw or otherwise force an explicit design review rather than silently scaling
past the intended model.

Bodies, settlements, routes, and future mobile entities should reference
economies by index or pointer rather than owning the economy data directly.

`G_DATA` should remain the game-owned holder for broadly accessed Orbiter
runtime state, similar in spirit to `D_CONST` for mostly-constant data. The
goal is clear ownership and reset behavior, not eliminating game-global state.

`EconLoc` needs heavy rework. It should split into `SettlementType` for economy
logic and placement plus `BodyLocation` for body-relevant travel-cost locations.

Near-term settlement types:

* surface;
* subsurface;
* aerial;
* orbital.

For the MVP, keep one orbital economy per body. Later, bodies should be able to
host multiple orbital economies, such as one per Lagrange point and one per
orbit height, and the star should be able to host an arbitrary number of
solar-orbit economies such as an asteroid-belt aggregate that excludes directly
defined bodies. Lagrange-point economy locations need a future design pass and
can wait until after the MVP.

## 5. Resources And Capacity Resources

Resources need a revamp.

Some current economy values should become capacity resources. Capacity
resources are special resources that represent local availability rather than
transportable stock. Current `WORK` is the model to generalize.

Capacity resources:

* are not transported by trade;
* are priced by availability rather than by ordinary stock flow;
* are produced or exposed by facilities, population, settlements, or local
  conditions;
* are calculated through the unified economy update pipeline for now;
* may be cached later only if profiling or area-use complexity justifies it.

Likely capacity resources include labour, area, housing, storage, construction
effort, power capacity, compute, and research.

Other resources should be implemented or reserved according to the categories
in [feature_ideas/resources.md](feature_ideas/resources.md). Non-MVP resources
can remain as commented-out enum values until the system stabilizes.
Starred entries in that file are mandatory Phase 1 resources. Unstarred entries
may be implemented in Phase 2 if directly relevant, but otherwise defer to
post-MVP.

`FUEL` should be removed from the MVP resource model after Phase 0 renaming and
audit work. A replacement propellant/fuel model is post-MVP.

`DEPOT` should stay as the singular storage facility for now. Resources should
still declare which facility stores them, but `DEPOT` storage capacity should
aggregate into one shared capacity pool rather than one lane per resource. If
produced resources exceed usable storage, unstoreable resources should be
wasted proportionally to production this tick.

Extractable resources should gain a static accessibility rate for MVP. Luna
should have higher mineral accessibility than Terra and Venus.

## 6. Facilities

`Facility` is the stable name for the merged industry/infrastructure concept.
Do not keep a separate implementation split for the MVP unless the code proves
it is still useful internally.

Facilities can be categorized for readability and data layout:

* growth;
* extraction;
* manufacturing;
* service;
* transportation;
* capacity.

Facility categories and subtypes should follow
[feature_ideas/facilities.md](feature_ideas/facilities.md). Non-MVP facilities
can remain as commented-out enum values until the facility model stabilizes.
Starred entries in that file are mandatory Phase 1 facilities. Unstarred
entries may be implemented in Phase 2 if directly relevant, but otherwise defer
to post-MVP.

Facilities may produce ordinary resources or capacity resources. Former
infrastructure such as housing, depots, habitats, networks, and construction
capacity should become facilities that expose or produce the relevant
capacities.

## 7. EconAgents

`EconAgent` should be the common enum group for economy actors.

Near-term agent groups:

* one agent entry for each facility enum value present in an economy, not one
  per facility instance;
* `POPULATION` as a whole-economy population agent for MVP;
* `TRADER` per trade route;
* one `GOVERNMENT` instance for the economy.

Agents are the interface between resource access, finance, construction
requests, and trade. Phase 2 adds taxes and subsidies through the same agent
surface. Broader agent-owned inventories are deferred unless route-local
`TRADER` inventory proves the pattern is needed elsewhere.

## 8. Population

Population should split into subtypes for the MVP:

* dependants;
* workers.

Births create dependants. Dependants convert into workers at a fixed rate.

Dependants and workers can have the same MVP consumption values, but each type
should declare its consumption separately so later education, wealth, law,
class, or role rules can diverge cleanly.

Worker output should feed the labour/capacity-resource model. Education,
wealth, laws, migration, owners, managers, engineers, and other population
subtypes are deferred.

## 9. Economy Update Pipeline

The economy update system is the largest MVP rework.

The current economy state, `econSolver`, `econBuilder`, build queue, capacity
calculation, prices, finance, and construction behavior need to be reviewed as
one system. The successor is `econPipeline`; it should be better organized and
split into smaller files where separation of concern is overdue.

The MVP update pipeline should:

* calculate ordinary resource flows;
* calculate capacity-resource availability and prices;
* update population consumption, production, births, deaths, and type
  conversion;
* update facility production, consumption, access, and activity;
* process maintenance before construction;
* enforce storage, area, housing, construction, labour, and energy constraints;
* process construction and deconstruction through coherent funding, materials,
  effort, cancellation, and refund rules;
* process agent finances, savings, and losses, with taxes and subsidies added
  in Phase 2;
* publish inspectable economy state without relying on debug-only automation.

The current `debugAutoBuild()` path is temporary scaffolding. It should be
retired once real agent, government, or player-order paths can maintain the
economy.

## 10. Trade

MVP trade should be automatic and abstract.

Each trade route should have its own `TRADER` agent. The trader buys resources
from the source economy and sells them wholesale in the destination economy on
the next tick. The trader internalizes profits and losses.

Bidirectional routes should use two directional `TRADER` agents so each
direction can keep its own revenues, costs, profitability, and inventory.

Trade should:

* move ordinary resources only;
* exclude capacity resources;
* exclude migration;
* base transport cost on transported resource mass;
* use route taxes and subsidies;
* use transfer-cost gating rather than vessel movement.

For the MVP, use a simple `deltaV` transfer-cost gate so route costs do not
explode when the current transfer window is bad. Dynamic `deltaT`, transfer
windows, travel delay, and vessel-mediated cargo are post-MVP concerns.

`TRADER` agents should have a simple inventory with add/remove accessors. This
can later become in-transit packets if route timing or vessel logistics need it.

## 11. Deferred But Important

The MVP should not discard future design space. Preserve these as constraints
or idea parking rather than direct work:

* colonization and settlement founding;
* politics, autonomy, unrest, welfare, laws, and local governors;
* ship modules, vessel logistics, arcships, and cyclers;
* dynamic transfer windows and realistic route timing;
* agent-owned inventories beyond route-local trade needs;
* proper debt and fiscal-management behavior beyond temporary negative savings;
* migration;
* education, wealth, law, and class-based population conversion;
* lightweight economy variants for automated mines, ship-bound economies, and
  regional aggregates;
* broader game goals, crises, victory/failure framing, and fun-focused player
  loops.

Do not silently delete older ideas. Move them into `feature_ideas/`, mark them
post-MVP, or ask the user before discarding them.
