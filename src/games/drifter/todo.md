# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Implement the first deterministic processing rules.

Manual starter-reserve harvesting now moves finite regolith, ice, and ore into
station storage through public World component APIs. This slice should convert
those raw stockpiles into the first produced resources through visible,
deterministic rule passes before drones or external asteroids exist.

## 2. Scope

In scope:

* add simple processing rules for starter raw stockpiles;
* convert ice into water and oxygen;
* convert water and power into fuel;
* convert ore into metals;
* convert regolith into concrete;
* convert metals plus power into electronics;
* convert water, oxygen, and power into food;
* respect storage capacity before accepting produced resources;
* show rule output, blocked storage, and relevant shortages through overlay text
  and/or logs;
* keep all durable mutation routed through public World component APIs.

Out of scope:

* drones, asteroids, chunks, and jobs as world entities;
* upkeep rules, market rules, command callbacks, and scheduler behavior;
* station system child entities;
* archetype declarations;
* retained UI widgets;
* construction, damage, repair, save/load, replay, particles, or effects;
* event output unless the slice deliberately adds the needed event type and
  overlay inspection.

## 3. Tasks

1. Define local processing recipes.
   * Pick compact fixed input/output amounts for each first-loop recipe.
   * Keep recipe numbers local to the Drifter station/resource slice.
   * Add comments for abstract units, power treatment, and incomplete future
     hooks.

2. Add rule-pass accounting.
   * Consume only resources that are available.
   * Add only produced resources that fit in station storage.
   * Keep power as the capacity-like energy buffer documented by the manual
     harvest slice.
   * Leave no partial mutation when a required component row is missing.

3. Mutate station facts through World APIs.
   * Fetch mutable station resource and capacity components from `ng.world`.
   * Reject processing when station facts are unavailable or incomplete.
   * Clamp each rule pass to available inputs and available storage.
   * Avoid hidden correction of invalid or over-capacity state.

4. Expose processing behavior.
   * Show current storage use and latest processing/block status.
   * Keep logs readable enough to validate successful processing and
     full-storage cases.
   * Add an event type only if the slice deliberately chooses event inspection.

5. Validate.
   * Run `zig build drifter`.
   * Manually run `drifter` if a graphics session is available.
   * Confirm processing decreases raw/input stockpiles, increases produced
     stockpiles, respects storage capacity, and reports blocked processing.

## 4. Next Slice Candidate

After the first processing loop is stable, the next roadmap slice should add
asteroids, chunks, and drones as world-owned facts so autonomous harvesting can
feed the same storage and processing loop.
