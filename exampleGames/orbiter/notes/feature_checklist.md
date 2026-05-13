# Feature Checklist

Comprehensive snapshot of Orbiter's feature surface, derived from a sweep of the current `.zig` sources (not from prior intent). Whenever this drifts from code, trust the code and refresh this file.

For implementation strategy and ordering, see [roadmaps/economy_upgrade.md](roadmaps/economy_upgrade.md) and [roadmaps/MVP_implementation.md](roadmaps/MVP_implementation.md). For the actionable short-term checklist, see [immediate_todo.md](immediate_todo.md). For player-facing design, see [design_document.md](design_document.md); for engineering conventions, see [design_philosophy.md](design_philosophy.md).

## Legend

| Mark  | Meaning           |
| ----- | ----------------- |
| `[?]` | being considered  |
| `[ ]` | validated         |
| `[.]` | scaffolded        |
| `[~]` | being implemented |
| `[o]` | being polished    |
| `[x]` | done              |

> *"Scaffolded"* = enum / struct / data grid exists in code with no solver / gameplay coupling yet. *"Done"* = wired end-to-end through the solver and observable in logs / metrics.

---

# Engine Integration

* `[x]` Engine hooks wired (`engineInterface.zig` exposes OnStart / OnOpen / OnTickWorld / OnRenderWorld / OnRenderOverlay / etc.)
* `[x]` Pluggable component stores (`TransStore`, `ShapeStore`, `SpriteStore`, `OrbitStore`, `BodyStore`)
* `[x]` Component registry registration for all stores
* `[x]` Variable-speed time stepping with `SpeedFactor` (PAUSED → YEAR), `times.stepTime()`, separate `shouldBodyTick` / `shouldEconTick` cadences
* `[x]` Pause toggle (`P`), single-step (`O`), target cycling (`J` / `K`), camera follow (`F`), speed change (`U` / `I`)
* `[x]` Debug spawn hotkeys (Shift+digit injects POP / res into TERRA)
* `[x]` Camera: WASD + arrow-key panning, mouse-wheel zoom, reset (`R`), follow-mode aware zoom-on-mouse
* `[x]` Debug target HUD (entity id, pos, scale, mass, radius, density, sunshine, periap / apoap, tracking flag)
* `[x]` Static data matrix loading on `OnStart` (`loadStaticDataMatrices` covers stellar / power / vessel / resource / pop / inf / ind)

---

# Stellar System

## Bodies (`data/stellarData.zig`)

* `[x]` `StellarBodyName` enum with SOL + DEBUGY + MERCURY + VENUS + TERRA + LUNA + MARS + PHOBOS + DEIMOS + 7 main-belt bodies (CERES, VESTA, PALLAS, HYGIEA, EUROPEA, DAVIDA, SYLVIA) + JUPITER / SATURN / URANUS / NEPTUNE
* `[x]` `StellarBodyType` enum (STAR, PLANET, PLANETOID, MOON, MOONLET, ASTEROID, COMET) with per-type display size / colour / LP count
* `[x]` Stellar data grid populated with real mass / radius / periapsis / apoapsis / longitude / type for all live entries
* `[.]` Trans-Neptunian / Kuiper / Oort entries commented out, ready to enable
* `[.]` ZOOZVE quasi-satellite, Mars trojans, Eros, Saturn moons commented out

## Orbit & Body Components

* `[x]` `OrbitComp` with semi-major / minor / eccentricity / period / orientation / retrograde-aware angular velocity
* `[x]` Kepler-2 true-anomaly angular velocity scaling
* `[x]` Period-from-mass calculation (`setPeriodFromMass`, Kepler's 3rd)
* `[x]` Per-tick orbit propagation in `updateOrbit` with stepCount and per-step recomputation
* `[x]` `BodyComp` holds `econArray[EconLoc.count]` and mass / radius / bodyType / name
* `[x]` `bodyType.canHostEconLoc(loc)` gates economy creation per body class
* `[x]` Surface area / volume / density helpers and reverse setters (`setRadiusViaArea`, `setMassViaDensity`, etc.)

## Lagrange / Hill / Roche

* `[x]` `EconLoc` enum: GROUND, ORBIT, L1, L2, L3, L4, L5
* `[x]` L1-L3 collinear point relative positions (Hill factor, L3 first-order μ correction)
* `[x]` L4 / L5 triangular points with first-order libration correction
* `[x]` Hill sphere & Roche-limit math (`getHillRadius`, `getRocheLimit`, fluid ↔ rigid lerp)
* `[x]` `getMaxMoonOrbitRadius` / `getMinMoonOrbitRadius` derived
* `[x]` Lagrange render overlay (`renderLPs`) on currently-targeted body

## Rendering

* `[x]` Adaptive-step orbital path rendering, eccentricity-aware step scaling, alpha fade
* `[x]` Configurable path length factor and fade strength (`G_CONSTS.orbitPathLenFactor`, `orbitFadeStrenght`)
* `[x]` Velocity-vector overlay (absolute + relative), periapsis / apoapsis markers, Hill / Roche disks
* `[x]` Body rendering with min display size per body type, planet-above-moon ordering

## Inter-Econ Transfer Table

* `[x]` `BodyEconPair` paired enum (BodyName × EconLoc)
* `[x]` `OrbitalData` per (body, loc): `orbitLvl = 1/√r`, `angPos`, `angVel`, `radVel`
* `[x]` `TravelData`: `deltaV`, `duration`
* `[x]` Per-tick `econOrbitalData` snapshot via `updateOrbitalDataEntry` (also updates per-econ sunshine)
* `[x]` `econTravelTable` full pair-to-pair Hohmann radial + drift-phase combined transfer estimate
* `[x]` `updateTravelTable()` called every econ tick
* `[ ]` Trade matching pass / cargo objects on top of the table (Tier 3 roadmap — table is ready and waiting)

## Star Shine

* `[x]` `StarShine` with inverse-square shine, seeded from TERRA's mean radius
* `[x]` Per-econ `sunshine` + clamped `sunAccess` (with GROUND loss factor, ORBIT factor, ground undeveloped fallback, GROUND sun-shortage exponent)

---

# Economy Core

## Per-Econ State (`Economy` in `econ/economy.zig`)

* `[x]` `isValid` / `isActive` / `hasAtmo`, `location`, `stepCount`, `sunshine`, `sunAccess`
* `[x]` Soft / hard init (`softInit`, `hardInit`) and dead / live constructors
* `[x]` `debugSetEconState(value, sunshine)` for stress-test seeding (calls debugSetInfCounts / IndCounts / ResCounts / PopCounts and then updateAreas / updateInfUsage / updateSunshine, seeds ecology, runs `testEconLogs`)
* `[x]` `STRESS_TEST` flag spawns every legal econ on every body at 100k pop (`stateInjects.zig`)
* `[x]` Default 1B-pop TERRA seed via `debugSetEconState(10_000, sunshine)`

## Resource Layer (`data/resourceData.zig`)

* `[x]` `ResType` enum: WORK, FUEL, FOOD, WATER, POWER, ORE, INGOT, PART
* `[x]` `ResType.getInfStore()` mapping (WORK → HOUSING, all else → STORAGE — flagged TODO to migrate once multiple storage types exist)
* `[x]` Per-res metrics: MASS, DECAY_RATE, STORE_RATE, PRICE_BASE, PRICE_ELAS, PRICE_DAMP (all loaded with tuned values)
* `[.]` `GROWTH_RATE` metric (kept but flagged deprecated)
* `[.]` STRUC res type commented out (deferred)
* `[.]` FLOP res type commented out (deferred — for tech tree)
* `[x]` `ResStateData` per-econ grid: COUNT, COUNT_D, LIMIT, LIMIT_D, PRICE, PRICE_D, ACCESS, ACCESS_D
* `[x]` Per-tick LIMIT_D delta tracking in `updateResCaps`

## Population Layer (`data/populationData.zig`)

* `[x]` `PopType` enum: HUMAN (only entry)
* `[x]` Per-pop metrics: MASS, HSNG_COST, POLLUTION, NATALITY, FATALITY (tuned)
* `[x]` Per-pop × per-res cube: CONS, PROD, MORT (HUMAN values populated: 0.35 WORK PROD, FOOD / WATER / POWER / PART CONS, MORT for WATER / FOOD / POWER)
* `[x]` `PopStateData`: COUNT, LIMIT, STARVE, DEATH, BIRTH, EXPENSE, REVENUE, SAVINGS, FLM_LVL
* `[ ]` Multiple PopType variants (SCIENTIST / ENGINEER / COLONIST etc — listed in roadmap suggestions)
* `[ ]` Pop subtype gating of industry activity

## Infrastructure Layer (`data/infrastructureData.zig`)

* `[x]` `InfType` enum: HABITAT, STORAGE, HOUSING, ASSEMBLY
* `[x]` Per-inf metrics: MASS, AREA_COST, CSTR_COST, POLLUTION, CAPACITY (all loaded)
* `[x]` Per-inf × per-res cube: CONS (declared, currently zero-loaded), BUILD (PART), MAINT (PART)
* `[x]` Per-inf `canBeBuiltIn(loc, hasAtmo)` rules
* `[x]` `InfStateData`: COUNT, DESTR, BUILT, EXPENSE, REVENUE, SAVINGS, USE_LVL
* `[.]` BATTERY / TANKS infrastructure (commented; STORAGE currently covers all res with `STORE_RATE` proxy)
* `[.]` AMENITIES / EDUCATION / COMMERCE infrastructure (commented, deferred)
* `[.]` POWER_GRID / PIPE_NETWORK / ROAD_NETWORK / POWER_BEAM / ELEVATOR / LAUNCHPAD / DATA_CENTER (commented, deferred)

## Industry Layer (`data/industryData.zig`)

* `[x]` `IndType` enum: AGRONOMIC, HYDROPONIC, WATER_PLANT, SOLAR_PLANT, POWER_PLANT, REFINERY, GROUND_MINE, FOUNDRY, FACTORY, PROBE_MINE (10 types)
* `[x]` Per-ind metrics: MASS, AREA_COST, CSTR_COST, POLLUTION (loaded)
* `[x]` Per-ind × per-res cube: CONS, PROD, BUILD (PART), MAINT (PART) — all populated with calibrated weekly rates
* `[x]` Per-ind `canBeBuiltIn(loc, hasAtmo)` rules (AGRONOMIC needs atmo; PROBE_MINE needs no atmo; etc.)
* `[x]` `IndType.getPowerSrc()` (SOLAR for AGRONOMIC / SOLAR_PLANT / PROBE_MINE, GRID otherwise)
* `[x]` `IndStateData`: COUNT, DESTR, BUILT, EXPENSE, REVENUE, SAVINGS, ACT_TRGT, ACT_LVL
* `[x]` Industry resource chain: ORE → INGOT → PART (GROUND_MINE / FOUNDRY / FACTORY)
* `[x]` Refinery → FUEL chain
* `[x]` SOLAR_PLANT / AGRONOMIC sunlight-coupled max flow

## Vessel Layer (`data/vesselData.zig`)

* `[.]` `VesType` enum: PROBE, SHUTTLE, STARSHIP (freighter), STATION
* `[.]` Per-vessel metrics: MASS, PART_COST, BLD_COST (no data yet), CAPACITY, CREW_COUNT (all loaded with placeholder geometric scaling)
* `[ ]` Vessel construction / state / lifecycle
* `[ ]` Vessel-mediated trade (cross-ref Tier 3.5)

## Power Source Layer (`data/powerData.zig`)

* `[.]` `PowerSrc` enum: GRID, SOLAR (scaffolded — FUELED / BEAMED commented)
* `[.]` `PowerMetricEnum` only contains DUMMY; data grid initialised to zero
* `[x]` `IndType.getPowerSrc()` consumes the enum to gate sunAccess scaling

## Area Layer

* `[x]` `EconAreaEnum`: BODY, INHAB, LAND, CAP, AVAIL, USED
* `[x]` `updateAreas` computes LAND / CAP / USED / AVAIL respecting GROUND+atmo vs other locations
* `[x]` `updateInfUsage` computes USE_LVL for HOUSING (pop / cap), HABITAT (areaUsed / habitatArea or fallback), STORAGE (max resC / resL ratio)
* `[.]` ASSEMBLY USE_LVL set by `BuildQueue.update` (post-build cycle) — works but is computed outside the solver phase order

## Ecology (`econ/ecology.zig`)

* `[x]` `EcoState` with development, pollution, ecoTarget, ecoFactor
* `[x]` Three pollution sources (pop COUNT × POLLUTION; inf COUNT × USE_LVL × POLLUTION; ind COUNT × ACT_LVL × POLLUTION)
* `[x]` Natural-capacity offset + saturating midpoint pollution curve
* `[x]` Dev / pollution multiplicative penalty with normalised eco floor
* `[x]` Exponential dampening toward `ecoTarget` (`ECO_DAMPENING` = 0.01)
* `[x]` `seed()` helper to jump straight to the target on init
* `[x]` Only ground+atmo bodies have ecology (`hasEcology`)
* `[~]` AGRONOMIC ecoFactor coupling in `calcIndMaxFlow` — code present but commented out ("potentially too penalising, review this section")
* `[ ]` Pollution-reducing infrastructure (cross-ref Tier 5.2)

---

# Solver Pipeline (`econ/econSolver.zig`)

Per-tick phase order is the spine. Phases marked `[x]` are wired and ticking; `[.]` are stubbed `_ = self;` placeholders.

## MAX RES FLOW PHASE

* `[x]` `calcPopMaxFlow` (per-pop × per-res CONS / PROD, populating `popResFlowData[OPR_CONS/OPR_PROD]`)
* `[.]` `calcInfMaxFlow` (stubbed)
* `[x]` `calcIndMaxFlow` (per-ind × per-res CONS / PROD, with SOLAR sunAccess scaling)
* `[~]` `calcMntMaxFlow` (works, but hardcoded to `.PART` only — generalisation to all `ResType` is Tier 1.1 Stage A)
* `[~]` `calcBldMaxFlow` (works, but hardcoded to `.PART` only — same generalisation pending)
* `[x]` `updateFlowAllSums` (aggregates per-agent rows into grp + gen)

## RES ACCESS PHASE

* `[x]` `calcGenResAccess` (intentionally-unclamped supply-vs-demand ratio for logging)
* `[x]` `calcPopResAccess` (clamps to remaining buffer, subs from BUFF)
* `[.]` `calcInfResAccess` (stubbed)
* `[x]` `calcIndResAccess`
* `[~]` `calcMntResAccess` (PART-only)
* `[~]` `calcBldResAccess` (PART-only)

## ACTION RATES PHASE

* `[x]` `updatePopFulfilment` (min of per-res grp access, gated by popCount > 0)
* `[.]` `updateInfUsage` (stubbed in solver — actual USE_LVL is computed in `Economy.updateInfUsage` pre-step + `BuildQueue.update` post-step)
* `[x]` `updateIndActivity` (min of ACT_TRGT and per-res grp access)

## CONSUMPTION PHASE

* `[x]` `calcPopResCons` (popResFlowData scaled by per-res grp OPR_ACS)
* `[x]` `calcInfResCons` (per-inf USE_LVL × OPR_CONS, plus MNT_ACS × MNT_CONS, plus BLD_ACS × BLD_CONS)
* `[x]` `calcIndResCons` (per-ind ACT_LVL × OPR_CONS, plus MNT_ACS × MNT_CONS, plus BLD_ACS × BLD_CONS)
* `[x]` `updateFlowConsSums` (per-action grp + gen aggregation)
* `[x]` `applyGenResCons` (subtracts TOT_CONS from FINAL stock)
* `[x]` `applyResDecay` (per-res DECAY_RATE applied to leftover stock after consumption; WORK fully decays each tick)

## PRODUCTION PHASE

* `[x]` `calcPopResProd` (popFlm-scaled, with `POP_PROD_FLOOR = 0.1` so starving pops still work a bit)
* `[x]` `calcIndResProd` (ACT_LVL-scaled)
* `[x]` `updateFlowProdSums`
* `[x]` `applyGenResProd`
* *No InfResProd: infrastructure is non-productive by design*

## FINANCES PHASE

* `[x]` `clampResStocks` (clamps to LIMIT, stores wasted amount in `resStockData[DESTR]` per resource)
* `[x]` `updateResPrices` (basePrice × ratio^ELAS with MIN_PRICE_FACTOR floor and DAMP lerp, full per-res price delta logged)
* `[x]` `updatePopFinances` (revenue / expense / profit / margin / SAVINGS update; isPresent vs theoretical fallback)
* `[.]` `updateInfFinances` (stubbed — `INF_REVENUE`, `INF_EXPENSE`, `INF_SAVINGS` exist in state)
* `[x]` `updateIndFinances` (revenue / expense / profit / margin → sigmoid → ACT_TRGT with `ACT_TRGT_FACTOR = 8.0` smoothing and `IND_MIN_ACT_TRGT = 0.05` floor)
* `[ ]` `updateComFinances` (planned)
* `[ ]` `updateGovFinances` (planned)

## GROWTH & DECAY PHASE

* `[x]` `updatePopCount` with base FATALITY, per-res shortage-driven starvation (`pow(1-access, PHI)` exponent), MAX_RES_MODIFIER / MAX_JOB_MODIFIER caps, birthRate × birtherRate × popC, popCap clamp
* `[~]` `avgPopStarveRate` / `avgPopDeathRate` / `avgPopBirthRate` computed but dropped (TODO: store on econ)
* `[.]` `updateInfCount` (stubbed — growth / decay currently lives in `debugAutoBuild`)
* `[.]` `updateIndCount` (stubbed — growth / decay currently lives in `debugAutoBuild`)

## ECON UPDATE PHASE

* `[x]` `pushResMetrics` (publishes COUNT / COUNT_D / ACCESS / ACCESS_D, sets `econ.buildBudget` from `BLD_CONS × BLD_ACS`)
* `[x]` `pushAgentMetrics` (per-group avg ACTION and ACCESS into `agtState`)

## Validation Harness

* `[.]` `testEconLogs` (parallel solver instance, logs profitability snapshot — called by `debugSetEconState`)
* `[.]` `testResFlowInvariant` (per-phase invariant check: Σ agent == grp == gen; defined but currently not called in the live phase order)
* `[~]` Standard logger suite: `logResMetrics`, `logIndMetrics`, `logInfMetrics`, `logPopMetrics`, `logSpecialMetrics`, `logTravelMetrics_TERRA`

---

# Build Queue (`econ/econBuilder.zig`)

* `[x]` `BuildEntry` with `construct`, `buildCount`, `partProgress` (single-counter model)
* `[x]` `Construct` union of `InfType` / `IndType` (`VesType` lane commented out)
* `[x]` `BuildQueue` with fixed 255-entry array
* `[x]` `addEntry` (APPEND / REPLACE), `hasEntryForConstruct`, `removeEntryAmount`, `getEntryCount`, `getTotalBuildCount`, `getTotalPartCost`
* `[x]` Per-tick `update`: pulls `min(assemblyCap, buildBudget)` PART, walks entries FIFO, calls `econ.tryBuild`, stashes fractional `partProgress`, sets ASSEMBLY `USE_LVL`
* `[~]` Single requester model (file already documents the planned refactor to per-AgentEnum sub-queues, BuildEntry five-counter data model, money-first API, etc — Tier 1.1 Stage A)
* `[ ]` `cancelEntry` (`addEntry(count=0, .REPLACE)` is the current hack)
* `[ ]` Mirrored BUILD / DEMOLISH / ABANDON entries (Tier 1.1 Stage B)
* `[ ]` Per-construct `.MNT_BUFFER` state field, `.REFUND_RATIO`, `.RFND_COST`, `.DEMOLISH_EFFORT`, `.MNT_IDLE_FACTOR`, `.BLD_EFFORT` metrics (Tier 1.1 Stage A / Stage B)

---

# Debug Auto-Build (`Economy.debugAutoBuild`)

* `[x]` Inf growth above `AUTO_BUILD_INF_THRESH` (0.80), decay below `AUTO_DECAY_INF_THRESH` (0.25), with `AUTO_BUILD_MAX_SCALE = 2.0`
* `[x]` ASSEMBLY clamped to `AUTO_BUILD_ASSEMBLY_F * popC` to prevent self-reinforcing build spiral
* `[x]` Ind growth above `AUTO_BUILD_IND_THRESH` (0.80) gated by WORK access ≥ `AUTO_BUILD_WORK_THRESH` (0.90), decay below `AUTO_DECAY_IND_THRESH` (0.60)
* `[x]` Ind growth dampened to zero when any output res `ACCESS > AUTO_BUILD_ACCESS_LIMIT` (32×)
* `[x]` Decay refunds `AUTO_DECAY_RES_FACTOR` (0.75) of PART build cost into both PART stock and owner SAVINGS
* `[x]` `AUTO_BUILD_QUEUE_LIMIT` (128) guard
* `[~]` Vessel branch placeholder (TBA comment)
* `[ ]` Retire `debugAutoBuild` once 1.3 / 1.4 / 1.5 are validated (Tier 1.6)

---

# Government

* `[.]` `GovMonetaryData` line on `Economy.localGov`
* `[.]` `GovMonetaryEnum` exhaustively declared: SAVINGS, NET_DELTA, TOT_DEBT, INT_DEBT, TOT_REVENUE, TAX_POP / TAX_INF / TAX_IND / TAX_RES / TAX_BLD / TAX_LND / TAX_COM / TAX_TOT, TOT_EXPENSE, SUB_POP / SUB_INF / SUB_IND / SUB_RES / SUB_MNT / SUB_BLD / SUB_TOT, GRT_POP / GRT_INF / GRT_IND / GRT_TOT, SPEND_BLD
* `[.]` `TaxGroupEnum` (ALL, POP, IND, INF, COM)
* `[.]` `TaxTypeEnum` (PROFIT, PROD, CONS, MAINT, BUILD)
* `[.]` `GovGeneralPolicyRates`, `GovPerResPolicyRates`, `GovPerPopPolicyRates`, `GovPerInfPolicyRates`, `GovPerIndPolicyRates` data grids declared
* `[.]` `tickLocalGov` stub on `Economy`
* `[ ]` Tax pass / subsidy pass / `SPEND_BLD` flow / `SUB_INF` for PUBLIC infra (Tier 2.1 – 2.3)
* `[ ]` Player-facing policy lever (Tier 2.6)
* `[ ]` `isActive` flip trigger from government-built infra (Tier 2.4 — flag exists, trigger does not)
* `[ ]` Government decay handling (Tier 2.5)

---

# Trade & Commerce

* `[x]` `EconOrbitalData` per (BodyName, EconLoc) updated every tick
* `[x]` `EconTravelTable` full pair-to-pair deltaV / duration table (radial + phase combined)
* `[.]` `AgentGroupEnum.COM` commented out (placeholder)
* `[.]` `AgentFlowEnum.BLD_PROD` declared for inverse refund lane (no consumers yet)
* `[.]` `ResStockEnum.IMPORT` / `.EXPORT` commented out
* `[ ]` Per-econ `EXP_CAP` / `IMP_DEM` / pricePoint signals (Tier 3.1)
* `[ ]` Solar-system trade matching pass (Tier 3.2)
* `[ ]` In-flight cargo objects + arrival timer (Tier 3.3)
* `[ ]` Tariffs via `TAX_COM` (Tier 3.4)
* `[ ]` Vessel-mediated transport (Tier 3.5 — `VesType` data model is already scaffolded)

---

# Dynamics Layer (Tier 4 — mostly unimplemented)

* `[~]` Industry margin → ACT_TRGT smoothing via sigmoid with configurable factor (acts as a coarse business-cycle damper; full EMA is Tier 4.1)
* `[x]` Per-res price dampening via lerp (PRICE_DAMP) — orthogonal to the EMA plan but already smoothing oscillation
* `[ ]` Inflation pass (`applyInflation` is a stub on Economy)
* `[ ]` Welfare / employment migration
* `[ ]` Strategic reserves
* `[ ]` Society simulation layer

---

# World Flavour (Tier 5)

* `[x]` Resource chain depth (ORE → INGOT → PART, FUEL via refinery) — exceeds MVP scope
* `[x]` Ecology system fully ticking (development + pollution + dampening)
* `[x]` `PROBE_MINE` autonomous extraction pattern (precursor to Tier 5.4 pre-settlement automation)
* `[ ]` Per-econ deposit depletion (Tier 5.1)
* `[ ]` Pollution-reducing infrastructure (Tier 5.2)
* `[ ]` Disaster / shock events (Tier 5.3)
* `[ ]` Generalised pre-settlement automation beyond PROBE_MINE (Tier 5.4)
* `[ ]` Megaprojects (Tier 5.5)
* `[ ]` Tech tree + TECH / STRUC res types (Tier 5.6)

---

# UI / Rendering / Inspection

* `[x]` Target HUD with entity #, pos, scale, mass, radius, density, periap / apoap, shine
* `[x]` Pause overlay with red screen border + "Press P to resume"
* `[x]` Speed indicator in bottom-right corner
* `[x]` Camera follow toggle indicator
* `[~]` Logger families: `logResMetrics`, `logIndMetrics`, `logInfMetrics`, `logPopMetrics`, `logSpecialMetrics`, `logTravelMetrics_TERRA` — formatting being polished
* `[ ]` In-game UI for economy state (ResStateData / PopStateData / etc.) — currently log-only

