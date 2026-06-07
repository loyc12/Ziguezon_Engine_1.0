# Economy Upgrade — Remaining Roadmap

This roadmap starts from the current implementation, not the original design draft.

Current baseline:

* `Economy` owns `govState : GovMonetaryData` and optional `buildQueue : ?BuildQueue`.
* `BuildQueue` and `BuildEntry` exist in `econBuilder.zig` / `builderData.zig`.
* Queue entries currently use `Construct`, `Requester`, `EntryTypeEnum` (`CNSTR`, `RECYC`, `DESTR`) and `EntryModeEnum` (`ADD_TO`, `SET_TO`, `RAISE_TO`, `LOWER_TO`, `CANCEL`).
* `BuildEntry` currently tracks `stashedFunds`, `stashedRes`, `stashedCnst`, and `unitCount`.
* `InfMetricEnum.CNST_COST` and `IndMetricEnum.CNST_COST` already represent construction effort.
* `InfResMetricEnum.BUILD` / `.MAINT` and `IndResMetricEnum.BUILD` / `.MAINT` already exist, but current data and solver paths are still effectively PART-only.
* `debugAutoBuild()` still drives infrastructure and industry growth / shrink decisions.
* `tickLocalGov()`, `updateInfFinances()`, `applyInflation()`, `calcInfMaxFlow()`, `calcInfResAccess()`, `updateInfUsage()` in the solver, `updateInfCount()`, and `updateIndCount()` are still stubs or inactive.

## Review Flags

These are implementation-plan contradictions or suspicious divergences worth reviewing before deeper work:

* `BuildQueue.tryAddEntry()` checks `self.hasMatchingEntry(c, q)` inside a loop but then mutates the current loop entry `e`. That can update the wrong entry when a matching entry exists at a different index. It should compare against `e` directly.
* `BuildQueue.tryFundEntry()` calls `e.matchesWith(...)`, but `BuildEntry` exposes `matchesWithPart()` and `matchesWithFull()`. This appears latent because the function is not currently compile-checked through an active call path.
* `compactEntries()` assigns `dst = src`, which only reassigns the local pointer rather than copying the entry value. If triggered, compaction likely does not do what the name promises.
* `tickQueue()` increments `idx` before calling `dumpEntryByIdx(econ, idx)`, so a closed entry may dump the following slot.
* `BuildEntry.getTotalCashCost()` calls `getUnitResCost(econ)` instead of `getUnitCashCost(econ)`.
* Several `BuildQueue` total helpers accumulate `f64` values into `u64` locals. If these helpers become active, they should be corrected first.
* `loadIndustryData()` appears to write construction effort values to `.AREA_COST` instead of `.CNST_COST` in the "BUILD COST" section.
* Current `RECYC` semantics partly cover the old DEMOLISH design, but names and behavior do not match: `RECYC` refunds resources by using negative `BUILD` cost, `DESTR` is free removal, and neither currently routes refund value through `.BLD_PROD` or requester savings cleanly.
* `BuildEntry.tryBuyRes()` splits `stashedFunds` equally across resource types and never subtracts spent funds. This conflicts with the intended money-first queue accounting.

---

# Tier 0 — Hygiene Before Expanding Behavior

## 0.1 Fix latent builder correctness issues

Do before relying on `tryFundEntry()`, cancellation, or long-lived queues.

* Fix entry matching in `BuildQueue.tryAddEntry()`.
* Replace the nonexistent `matchesWith()` call with `matchesWithFull()`.
* Fix `compactEntries()` to copy entry values and set `maxEntryCount` to the actual valid count.
* Fix closed-entry dumping in `tickQueue()`.
* Fix `getTotalCashCost()` and the total helper accumulator types.
* Decide whether `BuildEntry.deactivate()` should return `void` or an actual `bool`.

## 0.2 Finish data cleanup that blocks economy tuning

* Move `ResType.getInfStore()`, `PopType.getInfStore()`, and `IndType.getPowerSrc()` from switch lookups into data tables.
* Fix industry `CNST_COST` initialization.
* Add non-PART `BUILD` / `MAINT` data only after solver and builder code actually loops all `ResType`.

---

# Tier 1 — Construction, Maintenance, and Agent Autonomy

Goal: replace `debugAutoBuild()` with decisions made by the owning agents, using the existing queue and finance state.

## 1.1 Make construction accounting coherent

Keep current names unless there is a strong reason to rename:

* `EntryTypeEnum.CNSTR` = queued construction.
* `EntryTypeEnum.RECYC` = queued salvage / demolition with partial refund.
* `EntryTypeEnum.DESTR` = immediate or queue-mediated abandon / destruction with no refund.
* `unitCount` = remaining units.
* `stashedFunds` = committed unspent money.
* `stashedRes` = purchased / reserved resources.
* `stashedCnst` = buffered construction effort.

Required work:

* Make `tryGrantFunds()` debit the `Requester` savings when funds are accepted, not just add to `stashedFunds`.
* Make `tryBuyRes()` spend down `stashedFunds` as resources are bought.
* Replace equal-per-resource buying with proportional purchase against the remaining resource-cost bundle.
* Keep `stashedRes` bounded to useful reserved work, or explicitly allow it to reserve multiple units and document that choice.
* Ensure cancellation via `EntryModeEnum.CANCEL` refunds `stashedFunds` and sells `stashedRes` back to the economy at current `ResStateEnum.PRICE`.
* Route construction resource consumption through one accounting path so solver `BLD_CONS` and queue purchases cannot double-count.
* Keep `CNST_COST` as the effort scalar instead of adding a separate `BLD_EFFORT`.

## 1.2 Generalize maintenance and build flows beyond PART

Current solver functions still hardcode `.PART`:

* `calcMntMaxFlow()`
* `calcMntResAccess()`
* `calcBldMaxFlow()`
* `calcBldResAccess()`

Required work:

* Loop over all `ResType`.
* Use `InfResMetricEnum.MAINT` / `.BUILD` and `IndResMetricEnum.MAINT` / `.BUILD` directly.
* Broadcast access values into `grpResFlowData`, `genResFlowData`, and per-agent flow data consistently.
* Recompute `TOT_CONS` after all access values are known.
* Add test or debug invariant coverage for multi-resource build and maintenance costs before tuning non-PART values.

## 1.3 Resolve ASSEMBLY as real construction effort

Current `BuildQueue.tickQueue()` uses `ASSEMBLY.CAPACITY * COUNT` directly.

Required work:

* Decide whether ASSEMBLY effort is constrained by ASSEMBLY operational inputs (`CONS` for WORK / POWER) before queue effort is granted.
* If yes, activate solver-side infrastructure operation for ASSEMBLY before `tickQueue()`.
* Keep `InfStateEnum.USE_LVL` for ASSEMBLY as the realized effort usage rate.
* Ensure zero ASSEMBLY capacity does not divide by zero when setting `USE_LVL`.

## 1.4 Add maintenance lifecycle feedback

Required work:

* Add per-construct maintenance idle factors instead of solver constants `INF_MAINT_IDLE_FACTOR` and `IND_MAINT_IDLE_FACTOR`.
* Add maintenance buffer state for `InfStateEnum` and `IndStateEnum`.
* Underpaid maintenance drains the buffer; sufficient maintenance restores it.
* Low buffer throttles next-tick `USE_LVL` / `ACT_LVL`.
* Zero or exhausted buffer causes attrition through the same destruction path used by `DESTR`.
* Decide whether `RECYC` remains the refunding demolition path and `DESTR` remains abandon, or whether the enum names should be changed before this becomes player-facing.

## 1.5 Implement infrastructure finances

Required work:

* Implement `updateInfFinances()` alongside `updateIndFinances()`.
* Store `InfStateEnum.EXPENSE`, `.REVENUE`, and `.SAVINGS` from real operations and maintenance.
* Add housing rent at the existing `// TODO : add housing costs` slot in `updatePopFinances()`.
* Route rent to `InfStateEnum.SAVINGS` or `GovMonetaryEnum.TAX_LND`, depending on ownership policy once implemented.
* Add settlement helpers for POP, INF, IND, and GOV savings transfers instead of hand-editing each state grid.

## 1.6 Replace `debugAutoBuild()` with agent order passes

Required work:

* Move industry growth / shrink logic into `updateIndCount()` or a dedicated order function called from the growth phase.
* Move infrastructure growth / shrink logic into `updateInfCount()` or a dedicated order function.
* Base industry decisions on `SAVINGS`, `REVENUE`, `EXPENSE`, `ACT_TRGT`, work access, and projected maintenance headroom.
* Base infrastructure decisions on `SAVINGS`, `REVENUE`, `EXPENSE`, `USE_LVL`, and projected maintenance headroom.
* Convert the `AUTO_BUILD_*` constants into per-agent tuning constants or data metrics.
* Retire `debugAutoBuild()` only after INF and IND can enqueue `CNSTR`, `RECYC`, and cancellation paths without debug intervention.

---

# Tier 2 — Government and Player Policy

Goal: make `govState` affect the simulation through taxes, subsidies, public construction, and one player-facing lever.

## 2.1 Wire government policy data into `Economy`

Current `governmentData.zig` defines policy rate grids, but `Economy` only stores `govState`.

Required work:

* Decide where `GovGeneralPolicyRates`, `GovPerResPolicyRates`, `GovPerPopPolicyRates`, `GovPerInfPolicyRates`, and `GovPerIndPolicyRates` live at runtime.
* Add initialization defaults for policy rates.
* Implement `tickLocalGov()` or solver finance passes that read those rates.

## 2.2 Tax pass

Required work:

* Apply `GovMonetaryEnum.TAX_POP`, `.TAX_INF`, and `.TAX_IND` to positive agent profit.
* Apply `.TAX_LND` from `areaData.USED` or per-agent area use.
* Apply `.TAX_BLD` to `CNSTR` and `RECYC` transactions once construction accounting is coherent.
* Apply `.TAX_COM` after inter-economy trade exists.
* Subtract taxes from agent savings and credit `GovMonetaryEnum.SAVINGS`.
* Populate `TAX_TOT`, `TOT_REVENUE`, and `NET_DELTA`.

## 2.3 Subsidies and grants

Required work:

* Apply `SUB_POP`, `SUB_INF`, and `SUB_IND` as expense offsets or direct reimbursements.
* Apply `SUB_MNT` and `SUB_BLD` once maintenance and construction costs have stable accounting.
* Apply `GRT_POP`, `GRT_INF`, and `GRT_IND` as direct savings injections for triggered policy actions.
* Populate `SUB_TOT`, `GRT_TOT`, `TOT_EXPENSE`, and `NET_DELTA`.

## 2.4 Government construction and activation

Required work:

* Let government enqueue `BuildEntry` with `Requester.gov`.
* Spend from `GovMonetaryEnum.SPEND_BLD` / `.SAVINGS`.
* Give government entries priority through the existing `BuildEntry.priority` field or a clear queue ordering rule.
* Define the infrastructure threshold that turns a `softInit()` inactive economy into an active colony.
* Keep `Economy.tryTick()` gated on `isActive`.

## 2.5 First player-facing policy lever

Required work:

* Pick one narrow lever, preferably a tax or subsidy rate already represented by `governmentData.zig`.
* Wire it from player input to policy storage to solver behavior.
* Expose enough debug/UI state to verify that changing the lever changes agent savings and behavior.

---

# Tier 3 — Inter-Economy Trade

Goal: connect local economies through price, surplus, deficit, and travel cost.

## 3.1 Add trade signals

Required work:

* Add per-economy export capacity and import demand storage, likely per `ResType`.
* Compute export capacity from surplus stock / production after local needs.
* Compute import demand from shortage, unmet demand, or refill target.
* Store a usable price point from `ResStateEnum.PRICE`.

## 3.2 Add a top-level trade matching pass

Required work:

* Run matching after local economy ticks and before arrivals are applied for the next tick.
* Use `travelSolver` estimates for route cost / duration.
* Match exporters and importers by price plus travel cost.
* Generate trade records containing resource, amount, source economy, destination economy, and arrival tick.

## 3.3 Add in-flight cargo

Required work:

* Lock or remove exported resources at departure.
* Hold shipments in a global queue.
* On arrival, add resources to the destination economy.
* Credit exporter savings and debit importer savings.
* Apply `TAX_COM` to imports once government taxation is live.

## 3.4 Replace abstract shipments with vessels later

Required work after abstract trade works:

* Re-enable `vesT` in `Construct`.
* Add vessel state analogous to `indState`.
* Give vessels construction cost, cargo capacity, stock capacity, and travel constraints.
* Convert export capacity from abstract surplus to fleet throughput.

---

# Tier 4 — Macro Dynamics

These are optional until the core autonomy / government / trade loop is stable.

## 4.1 Inflation

Required work:

* Implement `Economy.applyInflation()`.
* Base inflation on total money supply or a simpler configured rate.
* Apply it consistently to POP, INF, IND, and GOV savings.

## 4.2 Expectations and smoothing

Current smoothing already exists through `PRICE_DAMP` and sigmoid-based `ACT_TRGT`.

Required work:

* Decide whether to add true EMA state for price / demand / supply.
* If added, use EMA values for autonomous build decisions instead of instantaneous prices.

## 4.3 Migration

Required work:

* Move population between active economies based on welfare, employment, savings, and travel cost.
* Gate migration by trade / vessel capacity once transport exists.

## 4.4 Strategic reserves

Required work:

* Add government resource stockpiles per `ResType`.
* Let policy buy into or release from reserves.
* Use reserves during shortages or fiscal stress.

---

# Tier 5 — World Depth

Do after the economic loop is playable.

## 5.1 Extraction depletion

* Add per-economy deposits.
* Scale mining yields by remaining deposit quality.
* Make exploration and site choice matter.

## 5.2 Ecology depth

The ecology system already exists and ticks.

Remaining work:

* Re-enable the AGRONOMIC `ecoFactor` coupling in `calcIndMaxFlow()` after balance review.
* Add pollution-reducing infrastructure to the ecology path.

## 5.3 Pre-settlement automation

Current `PROBE_MINE` is the first pattern.

Remaining work:

* Add distinct base resources beyond generic ORE.
* Support closed-loop robotic bootstrap economies before population arrives.
* Tie activation into government construction / colony founding.

## 5.4 Megaprojects and tech

* Add multi-economy construction projects only after trade and government funding work.
* Add TECH / R&D only after the resource and policy loop is stable.
* Revisit commented `FLOP`, `DATA_CENTER`, `EDUCATION`, and `STRUC` ideas at that point.

---

# Deferred Design Choices

These are not implementation tasks yet:

* Whether to keep `CNSTR` / `RECYC` / `DESTR` names or rename them to player-facing terms.
* Whether construction allocation should stay priority/FIFO or become a threshold-weighted policy allocator.
* Whether resource allocation should remain physical-priority based or move toward highest-bidder market clearing.
* Whether infrastructure ownership needs more than PUBLIC / PRIVATE.
* Whether per-economy ticks need threading; the current global `EconSolver` instance is not thread-safe.
