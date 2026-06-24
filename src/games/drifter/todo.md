# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Implement manual starter-reserve harvesting.

The station now exists as one persistent world entity with game-owned component
facts for resources, starter reserves, and capacities. This slice should add a
small player/debug action that consumes finite manual reserves and moves raw
resources into the station stockpiles while respecting storage capacity.

## 2. Scope

In scope:

* add a simple manual harvest input or debug control;
* consume finite starter reserve amounts for regolith, ice, and ore;
* add harvested raw resources to station stockpiles;
* respect station storage capacity before accepting harvested resources;
* expose the result through the existing overlay and/or logs;
* keep reset behavior restoring default reserves and stockpiles;
* keep all mutation routed through public World component APIs.

Out of scope:

* drones, asteroids, chunks, and jobs as world entities;
* processing rules, upkeep rules, market rules, command callbacks, and
  scheduler behavior;
* station system child entities;
* archetype declarations;
* retained UI widgets;
* construction, damage, repair, save/load, replay, particles, or effects;
* event output unless the slice deliberately adds the needed event type and
  overlay inspection.

## 3. Tasks

1. Define the manual harvest operation.
   * Pick a compact fixed harvest amount for regolith, ice, and ore.
   * Keep the numbers local to the Drifter station/resource slice.
   * Add comments for units, capacity assumptions, and incomplete future hooks.

2. Add storage-capacity accounting.
   * Count the tangible stored resources covered by current station storage.
   * Do not count credits or population as storage cargo.
   * Decide whether power is stored capacity cargo or a capacity-like stockpile,
     and document that choice in code.

3. Mutate station facts through World APIs.
   * Fetch mutable station resource and reserve components from `ng.world`.
   * Reject harvest when station facts are unavailable or incomplete.
   * Clamp harvest to remaining reserves and available storage.
   * Leave no partial mutation when a required component row is missing.

4. Expose harvest behavior.
   * Add a visible input hint to the overlay.
   * Show current storage use and the latest harvest/block status.
   * Keep logs readable enough to validate harvest and full-storage cases.

5. Validate.
   * Run `zig build drifter`.
   * Manually run `drifter` if a graphics session is available.
   * Confirm harvesting decreases reserves, increases raw stockpiles, respects
     storage capacity, reports blocked harvests, and reset restores defaults.

## 4. Next Slice Candidate

After manual harvesting is stable, the next roadmap slice should implement the
first processing rules: convert starter raw stockpiles into water, oxygen, fuel,
metals, concrete, electronics, and food through visible deterministic rule
passes.
