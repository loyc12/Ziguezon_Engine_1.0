# Minimum Viable Product (MVP)

The MVP is a *gameplay-loop* milestone : the scope-construction targets (bodies, resources, locations) have been overshot in code, but the systems that turn scope into gameplay (trade execution, gov levers, autonomy pressure, player-facing policy) are still pending. The MVP is reached when the player can meaningfully steer at least one economy through survival or collapse.

## Objective

Create a small but complete gameplay loop proving:

* logistical planning
* colony interdependence
* political pressure
* strategic infrastructure decisions

---

## MVP Core Systems

### Required

* `[x]` orbital transfer simulation
* `[ ]` automatic trade — Tier 3 in [economy_upgrade.md](economy_upgrade.md)
* `[~]` local economies — per-econ tick is live ; each econ is an island until trade lands
* `[~]` colony growth/decline — pop dynamics implemented ; INF / IND growth currently driven by `debugAutoBuild` placeholder (Tier 1.3 / 1.4)
* `[~]` infrastructure construction — basic `BuildQueue` works ; queue refactor (Tier 1.1 Stage A) is the prerequisite for player-driven construction
* `[ ]` subsidies/taxes — Tier 2.1 / 2.2
* `[ ]` transport constraints — gating mechanic needs trade to exist first
* `[ ]` basic autonomy pressure — Tier 2 / Tier 3

### Optional

* `[ ]` simple random crises (Tier 5.3)
* `[ ]` basic faction drift (Tier 2 governance)
* `[ ]` exploration uncertainty (Tier 5.1)

---

# General Development Roadmap

## Phase 1 — Playable Economic Skeleton

Goal:

* prove basic gameplay loop

Implement: see "MVP Core Systems / Required" above (orbital transfers, automatic trade, local economies, colony growth, infrastructure construction, subsidies/taxes, transport constraints, basic autonomy pressure).

Success condition:

* player can meaningfully influence colony survival and growth

> Currently gated on : Tier 1.1 (queue rework, for player-driven construction), Tier 2.6 (first policy lever, for player input), and at minimum Tier 3.1 (trade signals, for "automatic trade" to mean anything). Per-econ ticking, pop dynamics, prices, finances, and ecology are already running.

---

## Phase 2 — Spatial Logistics

Goal:

* make orbital geography strategically meaningful

Implement:

* route capacity
* depots
* fuel logistics
* transfer timing
* infrastructure bottlenecks

Success condition:

* infrastructure placement becomes strategically important

> Prereq slots are in place : deltaV / duration table is live, FUEL is produced by REFINERY, and `InfType` lanes for depots / fuel stations / transfer relays / cargo hubs are commented in `infrastructureData.zig` waiting to be enabled.

---

## Phase 3 — Political Autonomy

Goal:

* create governance gameplay

Implement:

* local governors
* colony opinion
* autonomy mechanics
* secession pressure
* local policy divergence

Success condition:

* distant colonies become difficult to govern directly

> Data layer is in place (`localGov : GovMonetaryData`, `tickLocalGov` stub, per-target tax/subsidy/grant policy grids). Solver passes are the missing piece.

---

## Phase 4 — Specialisation & Exploration

Goal:

* deepen interdependence

Implement:

* exploration uncertainty
* resource surveying
* advanced industry roles

(Body specialisation is already enforced mechanically via `canHostEconLoc` + per-construct `canBeBuiltIn(loc, hasAtmo)` rules ; it is no longer outstanding scope.)

Success condition:

* colonies become economically unique

---

## Phase 5 — Advanced Systems

Goal:

* expand strategic complexity

Potential additions:

* megaprojects
* advanced politics
* orbital hazards
* deep research systems
* large-scale migration
* late-game infrastructure

Post-ship only (per [design_document.md](../design_document.md) "Out-of-Scope"):

* diplomacy (elaborate diplomacy is deferred)
* warfare (combat is not a gameplay loop until after ship)
