# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Add life-support upkeep, first station systems, storage-pressure recovery, and
a small visual clarity pass.

Autonomous asteroid harvesting is now stable enough to feed the station's shared
storage and processing loop. The next slice should add the first pressure that
makes those resources matter: oxygen/food/population upkeep, station-owned
system entities, and a minimal way to recover when shared storage fills with
final resources and blocks raw-resource intake.

## 2. Scope

In scope:

* add game-owned station-system facts as station-owned child entities;
* add initial system kinds only where they support this slice: hangar, storage,
  refinery, solar, reactor, shipyard, depot, and assembly can start compact;
* apply simple life-support upkeep to oxygen and food on a deterministic
  temporary cadence;
* make population loss visible when upkeep cannot be paid;
* keep gameover behavior minimal or logged if the exact flow is not ready;
* make system facts affect relevant capacity or throughput where direct and
  low-risk;
* add a manual dumping control for stored resources so full storage cannot
  permanently block ice/regolith/ore gathering;
* add overlay/log status for upkeep, population loss, dumping, and any blocked
  system work;
* adjust early visuals so asteroid, depleted asteroid, chunk, drone, station,
  and blocked states are easier to distinguish than the current mostly-gray
  palette.

Out of scope:

* full retained UI widgets;
* market prices, buying, selling, import/export throughput, and depot logistics
  beyond a local manual dump recovery control;
* player-editable production rules and scheduler-owned cadence;
* construction queues, upgrades, damage, repair, save/load, replay, particles,
  or effects;
* advanced pathfinding, collision physics, real orbital mechanics, grids, or
  detailed travel simulation;
* broad art direction or complex station visuals beyond clear debug-readable
  colors and simple markers.

## 3. Tasks

1. Define station-system facts.
   * Keep the first component shape compact and game-owned.
   * Register and unregister system stores with the Drifter lifecycle.
   * Represent station ownership directly through the world surface that is
     already stable; report if child ownership exposes a broader boundary.

2. Add life-support upkeep.
   * Consume oxygen and food on a deterministic temporary cadence.
   * Reduce population when upkeep cannot be paid.
   * Log and overlay the latest upkeep result, shortage, and population state.

3. Connect first system effects.
   * Let simple system facts affect storage, drone slots, processing throughput,
     power output, or construction/shipyard/depot capacity where direct.
   * Keep power behavior compatible with the current finite-buffer transition
     unless the slice deliberately replaces it.

4. Add manual dumping.
   * Provide a simple input path to dump one or more stored resources.
   * Prefer freeing final products first if a one-button debug dump is chosen.
   * Report dumped amounts and storage recovery through overlay text and logs.
   * Leave broader market/resource-management rules for the market slice.

5. Improve visual readability.
   * Revise asteroid/chunk/drone/status colors so active, reserved, depleted,
     returning, unloading, and blocked states are not visually ambiguous.
   * Avoid relying on gray outlines alone for leftover or depleted asteroids.
   * Keep the pass small and debug-readable rather than building final art.

6. Validate.
   * Run `zig build drifter`.
   * Confirm upkeep consumes resources, shortages reduce population, dumping can
     unblock raw-resource gathering, system effects are visible, and the visual
     status colors are readable in a manual graphics run.

## 4. Next Slice Candidate

After upkeep and station systems are stable, the next roadmap slice should add
the first market and resource-management loop: prices, buying, selling, and
more deliberate dumping rules.
