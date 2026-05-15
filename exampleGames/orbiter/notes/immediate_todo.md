# Immediate Todo

## Legend

| Mark  | Meaning     |
| ----- | ----------- |
| `[ ]` | untouched   |
| `[.]` | scaffolded  |
| `[~]` | in progress |
| `[x]` | finished    |

This file is a narrowed-down, actionable view of [economy_upgrade.md](roadmaps/economy_upgrade.md) — focused on the easy / quick changes, the core `econSolver` + `econBuilder` rework (roadmap Tier 1.1 Stage A + Stage B), and the precursors needed before that rework can start. Tier 1.2+ (financial integration, agent self-build, government, trade, etc.) live in the roadmap only. This file is the implementation checklist: tickable boxes, no higher-level design discussion — consult `economy_upgrade.md` for the why.

## Section dependencies

* Housekeeping and above is parallel-friendly with everything below
* Stage A must complete and validate against current behaviour before Stage B starts
* Items within a section are roughly small-to-large unless a dependency forces order

**Validation rule** : after each item where applicable, run `testEconLogs` and confirm long-run tick parity (hundreds of ticks at default debug state); `logSpecialMetrics` output should track baseline within rounding tolerance. `testResFlowInvariant` exists in `econSolver.zig` for per-phase Σ-agent / grp / gen sanity checks ; uncomment its phase calls when running validation passes.

---

# Nitpicks (non-logic stylistic changes)

* `[~]` 1. Standardise name of common econ-related variables where it is not confusing
  * `xxxType  / xxx`   → `xxxT`
  * `xxxCount / count` → `xxxC`
  * `xxxPrice / Price` → `xxxP`
  * `(xxx)[ [C/c]ap(acity) / [L/l]im(it) / [S/s]tor(ag)e ]` → `xxxL`

* `[~]` 2. Align arguments and symbols into neat columns for successive lines, when cleaner looking
  * Example :
    ```
    var1 = func1( arg1, arg2 );    =>  var1      = func1( arg1, arg2 );
    var2 += function2( arg2 );     =>  var2     += function2(   arg2 );
    variable3 = f3( arg1, arg3 );  =>  variable3 = f3(    arg1, arg3 );
    ```

* `[~]` 3. Standardise argument ordering, especially in dataMatrices
  * Example rules : always put `resT` last, always put non-`resT` `xxxT` first, etc.

* `[~]` 4. Replace tabs by formatting size arguments `{d>N.D}`

---

# Housekeeping (quick wins, parallel-friendly)

* `[~]` 1. Standardise `DataMatrix` vs `Array` usage where it has drifted

* `[~]` 2. "function-as-lookup" → data array migration
  * `resourceData.getInfStore`, `populationData.getInfStore`, `industryData.getPowerSrc` (each carries `// TODO : move to data array` comment)

* `[ ]` 3. `logBuildQueue` helper on `BuildQueue`
  * Mirror `logResMetrics` / `logIndMetrics` / `logInfMetrics` shape
  * `BuildQueue` itself has a `// TODO : add a "log build queue" function` placeholder

* `[ ]` 4. Persist `avgPopDeathRate` / `avgPopBirthRate` / `avgPopStarveRate` on econ
  * Math runs in `updatePopCount` and is then dropped (marked `// TODO : Store these averages in econ`)
  * Pick a target field — likely a new `PopAvgStateEnum` or an addition to `agtState`

* `[ ]` 5. Republish `clampResStocks` waste counts to `econ.resState`
  * Per-resource destroyed amount is stored in `solver.resStockData[.DESTR]` but never flows back to econ state

* `[ ]` 6. Validate `econSolver`'s CONSUMPTION PHASE `xxxResFlowData.set/add` accounting
  * Find a way to standardise logic to avoid confusion like this moving forward
  * `testResFlowInvariant` is the audit tool — re-enable its per-phase calls when running this

---

# Tier 1.1 Stage A : Structural Rework

Must land and validate against current behaviour before Stage B begins. Each item should leave the simulator green.

## Solver-side

* `[ ]` 1. Split per-purpose cons passes
  * `AgentFlowEnum` already carries OPR / MNT / BLD / TOT lanes ; today `calcInfResCons` / `calcIndResCons` write all four lanes inside a single per-agent loop
  * Final step is to split into `calcOprResCons` / `calcMntResCons` / `calcBldResCons` that each iterate all relevant agents
  * MAX FLOW phase stays unified

* `[ ]` 2. Generalise MNT and BLD cost handling to all `ResType`
  * `calcMntMaxFlow` / `calcMntResAccess` / `calcBldMaxFlow` / `calcBldResAccess` hardcode `.PART`
  * Loop over `ResType` ; per-inf and per-ind metric cubes already have the slots ready
  * Broadcast per-resource access back to grp / gen flow data

* `[ ]` 3. Tune in non-PART MNT / BLD costs
  * ASSEMBLY's WORK + POWER `OP_CONS`
  * Multi-res maintenance recipes for selected constructs
  * Optional: multi-res BUILD recipes
  * All non-PART slots in `infResMetricTable` / `indResMetricTable` MAINT and BUILD columns are currently zero

* `[ ]` 4. ASSEMBLY pre-resolve sub-pass
  * CAPACITY denotes effort per tick (not PART/tick)
  * Resolve ASSEMBLY's own `OP_CONS` (WORK + POWER) before BLD access
  * Scale realised capacity by ASSEMBLY's input access; book `OP_CONS` against realised, not nominal, capacity
  * Today `calcBldMaxFlow` only applies a global `scale = assemblyCap / rawTotal` clamp and consumes none of ASSEMBLY's own inputs

* `[ ]` 5. Remove dead `consumeParts` block from `tryBuild` ; absorb area / location accounting into `BuildQueue.update` once the queue drives per-construct accounting

## BuildQueue-side

* `[ ]` 8. `BuildQueue` : per-requester sub-queues
  * Replace single fixed array with one queue per `AgentEnum` requester (GOV, IND, INF, COM, POP)
  * `AgentGroupEnum` has POP / INF / IND ; GOV / COM / NAT are commented and need to be enabled

* `[ ]` 9. `BuildQueue` : true queue structure
  * Replace fixed-array swap-remove dance in `removeEntryAmount`

* `[ ]` 10. `BuildEntry` : five-counter data model
  * `unitsRemaining : u64` (decrements on completion)
  * `unitsReserved  : u64` (can grow large at scale)
  * `fundingPool    : f64` (accumulated money)
  * `reservedRes    : ResStockData` (fractional remainder, < 1 unit)
  * `effortBuffered : f64` (in `[ 0, BLD_EFFORT-per-unit ]`)

* `[ ]` 11. Money-first requester API
  * Agents only contribute SAVINGS; queue procures materials internally
  * Explicit `addEntry` / `cancelEntry` operations
  * Replace the current `addEntry(count=N, .REPLACE)` cancellation hack (current modes are `APPEND` / `REPLACE`)

* `[ ]` 12. Queue per-tick processing : four passes
  1. **Funding** : requester SAVINGS → `fundingPool` (debited immediately)
  2. **Procurement (eager)** : spend `fundingPool` at current prices; proportional per-resource buy via "cash access" rate; validate immediately (`unitsReserved += N`, `reservedRes` carries fractional remainder)
  3. **Effort allocation** : ASSEMBLY budget across entries; skip entries with `unitsReserved == 0`
  4. **Effort consumption** : `effortBuffered` crosses `BLD_EFFORT` → one unit completes; `unitsReserved -= 1`, `unitsRemaining -= 1`

* `[ ]` 13. Per-agent SAVINGS budget per tick
  * Caps total commitment per agent across all their entries this tick
  * Replaces the per-econ `buildBudget` (which is in PART, not money — today set by solver as `BLD_CONS × BLD_ACS`)

* `[ ]` 14. GOV-priority allocation
  * GOV entries first, others FIFO from remaining budget
  * Threshold-allocator generalisation deferred (see roadmap suggestions)

* `[ ]` 15. Within-requester ordering : DEMOLISH before BUILD by default
  * Demolitions refund materials that pending BUILDs can consume
  * Override per-entry available

* `[ ]` 16. Order completion refund
  * On `unitsRemaining` hits 0: refund any remaining `fundingPool` back to owner SAVINGS (handles cost underruns from price drops)

---

# Tier 1.1 Stage B : Lifecycle & Feedback

Adds capital lifecycle on top of Stage A. Don't start until Stage A is validated. Items mostly independent within the section.

## Metric tables

* `[ ]` 1. Per-construct `.MNT_IDLE_FACTOR` → inf/indResMetric
  * Retire `INF_MAINT_IDLE_FACTOR` (0.25) / `IND_MAINT_IDLE_FACTOR` (0.10) solver constants (both flagged `// TODO : Move IDLE_FACTOR to peing per-IndType/InfType`)

* `[ ]` 2. Per-construct refund metrics
  * `.REFUND_RATIO`    : fraction of build cost returned on DEMOLISH (currently a single global `AUTO_DECAY_RES_FACTOR = 0.75` in `debugAutoBuild`)
  * `.RFND_COST`       : resource / effort cost of dismantling
  * `.DEMOLISH_EFFORT` : separate from `BLD_EFFORT` for ASSEMBLY accounting

## State fields

* `[ ]` 3. `.MNT_BUFFER` state field on Inf / Ind
  * Single field drives delay, throttle, and decay:
    * full MNT pay → buffer recovers toward MAX
    * underpayment → buffer drains by `(1 - mntAccess) * mntDemand`
    * `buffer >= THRESHOLD` : no penalty
    * `buffer <  THRESHOLD` : next-tick activity capped, attrition rate scales with deficit
  * Per-construct : `BUFFER_MAX`, `THRESHOLD`, `RECOVERY_RATE`, `DECAY_SCALE`

## Solver-side

* `[ ]` 4. Wire the `BLD_PROD` flow lane
  * Enum slot is already declared in `AgentFlowEnum` ; no producers / consumers yet
  * Route refunds from DEMOLISH and degradation through it, then into owner SAVINGS via finances phase

## BuildQueue-side

* `[ ]` 5. Mirrored construction / destruction queue
  * `BuildEntry` gains a `kind` field : BUILD | DEMOLISH | ABANDON
  * **BUILD** (queued) : as Stage A
  * **DEMOLISH** (queued) : consumes effort + `.RFND_COST`; refunds via `.BLD_PROD` at per-unit completion
  * **ABANDON** (immediate) : no effort, no refund, bypasses queue

* `[ ]` 6. ABANDON triggers
  * Player / owner-triggered (explicit decision)
  * Forced : insolvency, disaster, `.MNT_BUFFER` stuck at zero
  * Same mechanical outcome regardless of trigger source

* `[ ]` 7. `cancelEntry` semantics
  * **Cancel BUILD**    : refund unspent `fundingPool`; sell `reservedRes` back at current price into owner SAVINGS; sub-unit effort progress is lost
  * **Cancel DEMOLISH** : finish current in-flight unit (round up to next integer), refund its proceeds, then stop

* `[ ]` 8. `debugAutoBuild`'s selloff branch → DEMOLISH enqueue
  * Until Tier 1.6 fully retires `debugAutoBuild`, its decay path should use the new queue rather than the current immediate scrap
