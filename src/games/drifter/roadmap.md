# Drifter Roadmap

This file describes the implementation order from the current `drifter`
scaffold toward the station-scale simulation described in [design.md](design.md)
and the validation target in [goals.md](goals.md).

Keep this roadmap focused on sequencing. Design direction belongs in
`design.md`; active task details can move into a future `todo.md`.

## 1. Preamble - Engine Baseline

Before serious `drifter` implementation, use the engine-world surfaces that are
already live instead of rebuilding them locally.

Available now:

* data-only `Archetype` declarations for reusable spawn/setup bundles;
* entity, component, relation, trait, event, command, rule, and query surfaces;
* `World.tick(...)` metadata setup, deterministic rule execution, and aggregate
  command execution in registration order;
* command execution ownership where rules enqueue requested changes and command
  callbacks apply durable mutation.

Plan around:

* first scheduler cadence is still the active engine-world slice, so timed
  drone travel, repeated processing cadence, upkeep cadence, market drift, and
  asteroid spawning should either wait for that surface or stay as temporary
  game-local tick counters until the engine scheduler lands;
* `RuleSet` can wait until plain rules need grouping or cadence management;
* retained UI polish can wait until simple overlays and controls become painful;
* particles/effects, save/load, replay, and context work can wait until the
  first station loop is stable.

The visual shell can start before all of this is complete. Deeper simulation
phases should use the live engine surfaces above rather than building permanent
game-local substitutes.

## 2. Baseline

Current baseline:

* `drifter` compiles as a game target;
* the adapter exposes the expected engine hooks and configs;
* input supports pause, camera zoom, world reset, manual harvesting, and overlay
  toggle;
* panning is disabled for the station-centered shell;
* rendering shows a central station circle plus world-owned asteroid, chunk,
  and drone markers;
* a single world-owned station entity is created on open/reset and destroyed on
  close/reset;
* station resources, starter reserves, and capacities are registered as
  game-owned component stores;
* manual starter-reserve harvesting is available through `H`, consumes finite
  regolith, ice, and ore reserves, respects storage capacity, and reports the
  latest harvest or blocked state through overlay text and logs;
* deterministic station processing runs on a temporary fixed cadence, converts
  starter stockpiles and stored life-support inputs into water, oxygen, fuel,
  metals, concrete, electronics, and food, consumes power as a non-storage
  buffer, respects storage capacity, and reports latest output or blocked
  rules through overlay text and logs;
* world-owned asteroids spawn on open/reset with chunk-count size state, drift
  visibly, and release harvestable chunks over repeated drone work;
* chunks are world-owned temporary entities with raw cargo, source asteroid
  links by id, reservation state, deterministic depletion, and visible markers;
* drones are world-owned visible entities with idle, outbound, harvesting,
  returning, unloading, and disabled states, moving between station and chunks
  while returning raw cargo into the same station storage loop as manual
  harvesting;
* the autonomous harvest loop reports drone assignments, returns, blocked
  target/storage states, and current asteroid/chunk/drone counts through overlay
  text and logs;
* the current power implementation is transitional: power is visible as a
  resource but still behaves like a finite non-storage buffer until the planned
  solar/reactor balance pass replaces it;
* overlay text shows pause state, zoom, asteroid/chunk/drone counts, station
  resources, starter reserves, storage use, capacities, manual harvest status,
  processing status, drone harvest status, and controls.

The first implementation goal is a small playable/debuggable vertical slice:
one station, starter reserves, basic resources, simple visuals, player controls,
and enough world facts to validate entity lifecycle, components, relations,
traits, events, rules, and queries in combination.

## 3. Current - Life Support, Systems, Storage Pressure, And Visual Clarity

Add failure pressure and let the station expand using direct resources.

Work:

* add oxygen, food, and population upkeep;
* trigger population loss and gameover when life-support failure reaches zero
  population;
* represent built station systems as station-owned child entities where the
  engine world surface supports it cleanly, after the base station facts and
  starter loop are stable;
* add initial systems: hangar, depot, refinery, storage, reactor, shipyard, and
  assembly after the system-child-entity shape is chosen;
* add a minimal manual dumping control before the market slice so full shared
  storage cannot permanently block ice, regolith, or ore intake;
* improve debug visuals so asteroid, depleted asteroid, chunk, drone, station,
  returned-resource, and blocked states are not all gray or outline-only;
* keep power as a special resource, then replace finite-buffer behavior with a
  per-tick balance where solar supplies free baseline power, reactors convert
  only enough fuel to cover unmet demand, and power shortages scale powered
  production down;
* defer building space until construction and events can change it; when added,
  model it as a simple scalar growth limit rather than a stored resource;
* add build costs for station systems;
* let storage, reactor, refinery, hangar, depot, shipyard, and assembly systems
  increase relevant capacities or throughput;
* route drone construction through the shipyard;
* make hangar capacity limit active drones;
* make shipyard capacity or construction throughput limit drone replacement;
* add basic system damage and repair work if the engine world surface is ready.

Validation:

* life-support failure is visible and reduces population;
* manual dumping can free shared storage and unblock raw-resource gathering;
* power balance is visible and scales production during shortages;
* building a system consumes resources and creates a station-owned child
  entity;
* capacity changes are visible immediately after build completion;
* drone construction is limited by shipyard and hangar capacity;
* visual state colors are readable enough to distinguish active, depleted,
  reserved, returning, unloading, and blocked objects;
* damaged systems create readable repair work when enabled.

## 4. Phase 5 - Market And Resource Management

Add the first market loop.

Work:

* give each resource a base price and current price;
* implement instant buy and sell first;
* nudge prices over time and in response to buying or selling;
* make buying less efficient than producing in-house;
* allow dumping resources to free storage;
* later, route import/export throughput through depot or hangar limits.

Validation:

* surplus resources convert to credits;
* missing resources can be bought at a cost;
* repeated buying and selling visibly affects price;
* dumping creates resource loss and a visible event.

## 5. Phase 6 - Rule Management And Player Priorities

Expose the station-management layer.

Work:

* add player-editable production rules such as threshold-based processing,
  selling, buying, or pausing production;
* allow priorities for drone harvesting targets;
* add limited drone override behavior only after the automated loop works;
* add overlay ledgers for active rules, thresholds, blocked rules, warnings,
  and recent events;
* keep rule failures explicit through events and warnings.

Validation:

* changing a threshold changes future production or market behavior;
* disabled or blocked rules are visible;
* drone automation remains the default and does not require micromanagement.

## 6. Later - Controls And Debug Views

Add controls when their target systems exist instead of keeping placeholder
buttons.

Work:

* expand drone, asteroid, chunk, system, and station debug views when the
  underlying behavior needs more than simple markers and overlay lines;
* add controls for spawn asteroid, manual harvest, buy, sell, dump, build
  system, and overlay toggles in the phase that owns each behavior;
* keep pause/resume, reset, zoom, and overlay toggles available throughout.

Validation:

* controls call real game behavior;
* overlay text does not depend on simulation internals that do not exist yet.

## 7. Deferred Work

Defer until the first station loop is stable:

* full tech tree;
* deep drone specialization;
* advanced market logistics;
* complex station visuals or animated module silhouettes;
* real orbital mechanics, collision physics, pathfinding, or grids;
* fully independent job entities;
* save/load, replay, or long-history inspection;
* broad UI polish beyond the controls needed to validate the simulation.

## 8. Roadmap Validation

For code slices, use at least:

* `zig build drifter`;
* `zig build check_games` when shared build surfaces or game lists change.

Docs-only changes to this file do not require a build.
