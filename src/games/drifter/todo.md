# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Add asteroids, chunks, and drones as world-owned facts.

Manual starter-reserve harvesting and deterministic station processing now feed
the station's shared storage loop. This slice should replace the visual-only
asteroid shell with the first autonomous harvest path: drifting harvest targets,
harvestable chunks, and drone facts that can return resources into the same
storage and processing loop.

## 2. Scope

In scope:

* add world-owned asteroid facts with simple size or chunk-count state;
* convert small asteroids into one harvestable chunk;
* support larger asteroids becoming multiple chunks over repeated work;
* add world-owned drone facts with simple visible states;
* route drone unloads into existing station storage through public World
  component APIs;
* keep returned raw resources compatible with the current processing loop;
* show asteroid, chunk, drone, job/block, and returned-resource status through
  overlay text and/or logs;
* remove or clearly retire visual-only asteroid state made obsolete by world
  facts.

Out of scope:

* retained UI widgets;
* market rules, command callbacks, scheduler behavior, and player-editable
  production rules;
* construction, station systems, damage, repair, save/load, replay, particles,
  or effects;
* advanced pathfinding, collision physics, real orbital mechanics, grids, or
  detailed travel simulation;
* life-support upkeep, population loss, and gameover behavior;
* event output unless the slice deliberately adds the needed event type and
  overlay inspection.

## 3. Tasks

1. Define asteroid, chunk, and drone facts.
   * Keep the first component shapes compact and game-owned.
   * Include comments for abstract units, temporary state choices, and future
     scheduler hooks.
   * Register and unregister the new stores with the Drifter lifecycle.

2. Replace visual-only asteroid ownership.
   * Spawn asteroids as world entities during open/reset.
   * Preserve simple visible drifting markers where practical.
   * Remove deprecated visual-only storage once world facts render correctly.

3. Add chunk creation and depletion.
   * Let small asteroids create one chunk.
   * Let larger asteroids create multiple chunks through repeated work.
   * Keep chunk depletion deterministic and visible.

4. Add the first drone loop.
   * Represent drone states: idle, outbound, harvesting, returning, unloading,
     and disabled.
   * Assign idle drones to available chunks with simple deterministic priority.
   * Move returned raw resources into station storage through existing station
     APIs or narrowly added public station helpers.
   * Report blocked harvest work when no drones, no targets, or no storage are
     available.

5. Validate.
   * Run `zig build drifter`.
   * Manually run `drifter` if a graphics session is available.
   * Confirm asteroids/chunks/drones are visible, chunks deplete, returned
     resources enter station storage, processing consumes returned raw
     stockpiles, and blocked work is readable.

## 4. Next Slice Candidate

After autonomous harvesting is stable, the next roadmap slice should add
life-support upkeep, population failure pressure, and station systems as
station-owned child entities.
