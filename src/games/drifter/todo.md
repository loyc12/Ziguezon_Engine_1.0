# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Start the first world-owned station facts.

The visual shell now exists: the station is drawn at center, deterministic
visual-only asteroids drift in the background, zoom/reset/overlay controls work,
and panning is disabled. This slice should attach the first persistent station
state to the engine `World` without adding processing, market, drones,
archetypes, or scheduler behavior yet.

## 2. Scope

In scope:

* register game-owned station component types through public World APIs;
* create one persistent station entity during game open/reset;
* add starter reserve state for finite manually harvestable regolith, ice, and
  ore;
* add initial resource stockpile state for regolith, ice, ore, oxygen, fuel,
  water, food, power, concrete, metals, electronics, credits, and population;
* add basic capacity state for storage, drone slots, processing throughput,
  power output, hangar throughput, market throughput, and construction capacity;
* expose station resource, reserve, and capacity facts through the existing
  overlay;
* keep the current visual shell intact unless it must read the new station
  facts;
* reset the station facts cleanly without stale entities or component rows.

Out of scope:

* station system child entities;
* drones, asteroids, chunks, and jobs as world entities;
* manual harvest behavior;
* processing rules, upkeep rules, market rules, command callbacks, and events;
* archetype declarations;
* scheduler cadence or timed jobs;
* retained UI widgets;
* construction, damage, repair, save/load, replay, particles, or effects.

## 3. Tasks

1. Define station fact types.
   * Add compact game-owned component declarations for station resources,
     starter reserves, and capacities.
   * Use explicit names that match `design.md`.
   * Add comments for fields whose units or ownership would be unclear.

2. Register station fact stores.
   * Register the station component stores during `OnGameOpen` or the nearest
     reset/setup helper.
   * Keep registration failures visible through logs.
   * Do not register unrelated world feature families yet.

3. Create and reset the station entity.
   * Create one station entity.
   * Attach the station resource, reserve, and capacity components.
   * Track the station id in game-owned state only as far as this slice needs.
   * Ensure reset removes the old station facts before creating a replacement.

4. Expose facts in the overlay.
   * Read station resources, reserves, and capacities through public World APIs.
   * Keep the overlay compact and debug-oriented.
   * Show an explicit unavailable/missing state if setup failed.

5. Validate.
   * Run `zig build drifter`.
   * Manually run `drifter` if a graphics session is available.
   * Confirm reset recreates station facts, overlay values return to defaults,
     and no stale station entity remains visible through debug output.

## 4. Next Slice Candidate

After station facts are stable, the next roadmap slice should implement manual
starter-reserve harvesting: consume finite reserve amounts, move harvested raw
resources into station storage, respect storage capacity, and emit visible
debug output or events only if the required event surface is deliberately added
in that slice.
