# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. The
current slice begins Phase 1 of [roadmap.md](roadmap.md): Terra baseline work,
starting with economy ownership and the location split.

Use [reference.md](reference.md) as the current baseline snapshot and
[roadmap.md](roadmap.md) as the implementation sequence. The Phase 0 rename and
audit pass is complete: code now uses `LABOUR`, `WORKER`, and builder
`EconAgent`, while `EconLoc`, `InfType`, and `IndType` remain transitional.

## Phase 1A - Economy Ownership And Location Scaffold

Goal: make Terra initialize through a game-owned economy path while preserving
current body/orbit behavior and keeping the next resource/facility work
unblocked.

This slice should not attempt the whole economy rewrite. Defer capacity-resource
pricing, full `Facility` migration, population dependants, `econPipeline`, and
trade until this ownership/location foundation is stable.

## 1. Archive Before Major Rewrites

Before a file receives its first major Phase 1 rewrite, copy its pre-Phase-1
version into `src/.oldFiles/` with the same relative path.

Likely first-archive candidates:

* `src/games/orbiter/comp/bodyComp.zig`;
* `src/games/orbiter/econ/economy.zig`;
* `src/games/orbiter/gameGlobals.zig`;
* `src/games/orbiter/gameUtils.zig`;
* `src/games/orbiter/data/economyData.zig`;
* `src/games/orbiter/data/stellarData.zig`.

Do not edit archived files. Keep only one archived version unless the user
explicitly asks for another.

## 2. Economy Identity And Storage

Add a game-owned economy storage surface in runtime state:

* define a simple `u32` economy id/index type or wrapper;
* reserve an invalid id value;
* enforce the roadmap's explicit review/error path before exceeding 1000
  economies;
* store economies in `G_DATA` or a clearly owned game-runtime holder;
* keep reset/deinit behavior clear when Orbiter closes or restarts.

Keep the initial storage compact and direct. Avoid allocator-heavy or generic
registry work unless the current code forces it.

## 3. Body Economy References

Move `BodyComp` away from owning economy data directly:

* replace `[ EconLoc.count ]Economy` ownership with economy ids/references or a
  temporary compatibility map;
* keep `BodyComp.getEcon()` only if it remains a thin compatibility helper over
  game-owned storage;
* update `quickInitEcon()`, `softInitAllEcons()`, `tickAllEcons()`,
  `logEcon()`, and `debugSetEconState()` to use the new ownership path;
* preserve Terra ground initialization and current debug startup behavior;
* isolate any remaining body-local economy assumptions with `// TODO:` comments
  if they cannot be removed cleanly in this slice.

Validation for this section:

* Terra initializes through the new ownership path;
* no active economy is silently duplicated between body storage and game-owned
  storage;
* body/orbit rendering and target selection still work.

## 4. Location Metadata Split

Start splitting `EconLoc` responsibilities without breaking travel code:

* add `SettlementType` for economy rules and settlement form;
* add or reserve `BodyLocation` for body-relevant travel/orbital locations;
* keep current `EconLoc` only as a compatibility boundary where travel/orbit
  code still requires it;
* define MVP settlement types:
  * `surface`;
  * `subsurface`;
  * `aerial`;
  * `orbital`;
* define body settlement-type metadata without making every body a live economy:
  * Terra -> surface;
  * Luna -> subsurface;
  * Venus -> aerial;
* keep one orbital economy per body for MVP;
* defer Lagrange settlement economies, multiple orbital layers, star-hosted
  arbitrary locations, asteroid-belt aggregates, and mobile economies.

Validation for this section:

* existing transfer estimation still receives valid body-location inputs;
* old `EconLoc` economy-rule assumptions are removed or clearly isolated;
* Terra still receives the same effective baseline settlement/location behavior
  after the split.

## 5. Keep Phase 0 Findings Visible

These findings remain relevant while implementing Phase 1A:

* `BodyComp`, `gameUtils.zig`, and `stepInjects.zig` currently assume economies
  are reached through body-local slots;
* `travelData.zig`, `travelSolver.zig`, and `orbitComp.zig` use location values
  for physical/orbital placement and should not be forced into settlement
  semantics;
* `data/industryData.zig` and `data/infrastructureData.zig` still represent the
  two pre-Phase-1 facility halves;
* `LABOUR` is still stored through `HOUSING` and behaves like the transition
  model for future capacity resources;
* `PART`, `DEPOT`, and `ASSEMBLY` remain hardcoded in build/storage paths and
  should be left alone unless directly touched by ownership/location changes.

## 6. First Resource-Model Prep

Only after the ownership/location scaffold compiles:

* add resource metadata fields needed to distinguish ordinary resources from
  capacity resources;
* mark `LABOUR` as the first capacity-like resource;
* keep capacity calculation in the existing update path for now;
* do not remove `FUEL` in this slice unless all dependent code is already
  obvious and low-risk;
* do not implement the full starred resource list yet.

This is a preparatory step for roadmap section 4.2, not the whole
capacity-resource model.

## 7. Validation

After each meaningful code slice:

* `zig build`;
* `zig build check_games`;
* `zig build test`;
* run or inspect Terra economy logs if initialization, ticking, solver input, or
  resource state publication changes.

Do not run formatting passes such as `zig fmt`.
