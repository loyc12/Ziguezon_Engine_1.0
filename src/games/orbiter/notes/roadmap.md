# Orbiter Roadmap

This file is the high-level implementation guide from the current
[reference.md](reference.md) baseline toward the rework target state in
[goals.md](goals.md). Broad game design belongs in
[design_doc.md](design_doc.md) and [design_philo.md](design_philo.md).

Detailed active tasks belong in [todo.md](todo.md).

## 1. Current Starting Point

Orbiter already has:

* a live solar-system body/orbit simulation;
* body/location economy slots;
* local economy state for resources, populations, infrastructure, industries,
  ecology, government money, and construction queues;
* a phased economy solver;
* resource prices, population dynamics, industry activity, ecology, and
  debug-driven construction;
* an on-demand orbital transfer estimator.

The missing core loop is player-steered, autonomous economic growth across more
than one economy. That requires coherent construction accounting, agent
autonomy, government policy, trade signals, and trade execution.

## 2. MVP Target

The MVP is reached when the player can meaningfully steer at least two
interdependent economies toward survival and growth.

Required capabilities:

* local economy simulation;
* orbital transfer costs and durations;
* transport constraints;
* automatic inter-economy trade;
* colony growth and decline;
* player-relevant infrastructure construction;
* government subsidies and taxes;
* local mineral resource count and access decay.

Optional before MVP:

* simple crises;
* exploration uncertainty;
* basic faction or autonomy pressure;
* richer local politics.

## 3. Phase 1 - Construction, Maintenance, And Autonomy

Goal: replace `debugAutoBuild()` with decisions made by the owning agents, using
the existing queue and finance state.

Required work:

* fix latent builder correctness issues before relying on long-lived queues;
* finish data cleanup that blocks economy tuning;
* make queue funding, resource buying, cancellation, and effort accounting
  coherent;
* generalize maintenance and build flows beyond `PART`;
* resolve ASSEMBLY as real construction effort;
* add maintenance lifecycle feedback;
* implement infrastructure finances;
* move infrastructure and industry growth/shrink decisions out of
  `debugAutoBuild()`;
* retire `debugAutoBuild()` after real agent order paths can build, recycle, and
  cancel without debug intervention.

The short actionable slice for this phase lives in [todo.md](todo.md).

## 4. Phase 2 - Government And Player Policy

Goal: make `govState` and policy data affect the simulation through taxes,
subsidies, grants, public construction, and one player-facing lever.

Required work:

* decide where runtime policy-rate grids live;
* initialize policy defaults;
* implement tax passes for population, infrastructure, industry, land, build,
  and eventually commerce;
* implement subsidies and grants;
* let government enqueue construction and spend from government savings;
* define the infrastructure threshold that activates an economy;
* wire one narrow player-facing policy lever from input to stored policy to
  solver-visible behavior.

## 5. Phase 3 - Inter-Economy Trade

Goal: connect local economies through price, surplus, deficit, and travel cost.

Required work:

* compute export capacity and import demand per economy;
* store usable price points;
* run top-level trade matching after local economy ticks;
* use `travelSolver.estimateTransfer()` for route cost and duration;
* create trade records containing resource, amount, source, destination, and
  arrival tick;
* remove or lock exported resources at departure;
* apply cargo arrivals to destination economies;
* credit exporters and debit importers;
* apply commerce tax after government taxation exists.

Abstract shipments should work before vessel-mediated transport replaces or
extends them.

## 6. Phase 4 - Spatial Logistics

Goal: make orbital geography strategically meaningful beyond abstract travel
costs.

Required work:

* route capacity;
* depots and storage constraints;
* fuel logistics;
* transfer timing windows;
* infrastructure bottlenecks;
* eventual vessel throughput.

Success condition: infrastructure placement and route investment visibly change
economic outcomes.

## 7. Phase 5 - Political Autonomy

Goal: create governance gameplay around distance, local conditions, and policy
divergence.

Required work:

* local governors;
* colony opinion or welfare signals;
* autonomy mechanics;
* secession or fragmentation pressure;
* local policy divergence;
* player tools that influence but do not directly control every local decision.

## 8. Phase 6 - World Depth

These should wait until the core autonomy, government, and trade loop is
playable.

Deferred work:

* inflation;
* expectations and smoothing beyond current price dampening;
* migration;
* strategic reserves;
* extraction depletion;
* ecology depth and pollution-reducing infrastructure;
* generalized pre-settlement automation;
* megaprojects;
* technology and research.

## 9. Deferred Design Choices

These are not implementation tasks yet:

* whether `CNSTR` / `RECYC` / `DESTR` should be renamed before becoming
  player-facing;
* whether construction allocation stays priority/FIFO or becomes weighted;
* whether resource allocation remains physical-priority based or moves toward
  highest-bidder market clearing;
* whether infrastructure ownership needs more than public/private distinctions;
* whether per-economy ticks need threading.

Surface these before implementation if they become blockers.
