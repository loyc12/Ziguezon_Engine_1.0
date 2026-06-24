# Drifter Design

This file defines the simulation used by `drifter` to validate engine `World`
features. The purpose and validation target belong in [goals.md](goals.md).
Implementation order belongs in [roadmap.md](roadmap.md).

## 1. Design Role

`drifter` needs a small coherent simulation, not a collection of unrelated
feature samples.

The design should exist to exercise engine-world systems in combination:
entities, components, relations, traits, events, archetypes, rules, scheduling,
queries, debug views, and effects.

The game should stay station-scaled. It should not become a solar-system,
colony-map, or tile-grid simulation. The station is the center of play and the
main anchor for engine-world validation.

## 2. Premise

`drifter` is a compact asteroid-station growth simulation.

A large asteroid has been hollowed into an autonomous station. The station must
sustain itself and grow by building drones, harvesting smaller drifting
asteroids or chunks from medium asteroids, processing incoming mass, and
allocating resources into upkeep, exports, expansion, and simple research.

The main asteroid can hold a finite reserve of manually harvestable starter
resources. This gives the player a fallback during the initial low-drone phase
and provides a simple bootstrap loop before asteroid interception is stable.

The station is a singular primary entity rather than a grid. Its internal
systems should be represented as child entities owned by the station. This
keeps the station concept singular while giving the world layer meaningful
entity ownership, lifecycle, relation, query, and inspection coverage.

Its visual shape can evolve later as more systems are built, but early versions
can use simple debug shapes and overlays.

## 3. Core Entities

The simulation should start with a small set of meaningful entity kinds.

* Station: the central persistent entity. Owns capacity, storage, systems,
  starter reserves, upkeep needs, growth state, and visual/debug
  representation.
* Station system: a module or fact representing a built station capability,
  such as hangar, depot, refinery, storage, reactor, shipyard, or assembly.
* Drone: a persistent worker entity built and maintained by the station.
  Drones harvest, haul, repair, construct, and eventually specialize.
* Asteroid: a drifting harvest target. Asteroid size is equivalent to its
  available chunk count.
* Chunk: a temporary harvestable unit created from an asteroid. Small asteroids
  become one chunk; larger asteroids can be harvested repeatedly.
* Job: a component attached to the drone, system, asteroid, chunk, or station
  entity currently carrying work. Full job entities can wait until the job
  system needs independent lifecycle, relations, or query behavior.
* Effect: a temporary visual or debug entity, such as dust, sparks, warning
  markers, construction indicators, or resource-flow markers.

These entities should stay few enough to inspect directly, but rich enough to
exercise lifecycle, relations, rules, events, archetypes, and queries together.

## 4. State Model

The first model should be abstract and deterministic. Avoid real orbital
mechanics, collision physics, pathfinding, or a spatial grid until the world
features need them.

First-loop resources:

* raw resources: regolith, ice, ore;
* produced resources: oxygen, fuel, water, food, power, concrete, metals,
  electronics;
* market support: credits and per-resource fluctuating base prices.

Power is a resource with special rules. It should stay visible in station
resource facts, but it is not ordinary cargo: it does not consume storage, and
the first balanced model should treat it as a per-tick production buffer rather
than a durable stockpile. Solar panels provide the base consumptionless supply.
Reactors convert fuel into stronger power output only when demand exceeds the
free solar supply, and should scale down when less reactor power is needed.
When available power is below demand, powered production should scale down
deterministically instead of silently creating or correcting stored power.

Building space is deferred for now. Later it should be a simple scalar capacity
that construction and events can gain or lose; it should not be harvested or
stored like a normal resource.

First-loop station systems:

* hangar: drone capacity, launch/return throughput, and market access limiter;
* depot: buying, selling, dumping, and basic import/export handling;
* refinery: converts raw resources into basic produced resources;
* storage: resource capacity;
* solar panels: baseline consumptionless power supply;
* reactor: fuel-to-power conversion for higher output when solar is not enough;
* shipyard: drone construction and drone replacement;
* assembly: advanced resource production, including electronics.

Likely game-owned state:

* resources and prices;
* capacities: storage, drone slots, processing throughput, power output,
  hangar throughput, market throughput, construction capacity;
* drone state: idle, outbound, harvesting, returning, unloading, repairing,
  building, disabled;
* station system state: inactive, active, upgrading, damaged, overloaded;
* asteroid state: incoming, in range, chunkable, being harvested, depleted,
  escaping;
* starter reserve state: remaining manually harvestable regolith, ice, and ore
  in the main asteroid;
* job state: open, assigned, active, complete, failed;
* population state: population can be represented as a resource for now, with
  gameover when it reaches zero.

The station should own resource stockpiles directly. Built station systems
should be individual child entities, not just enum counters, because that gives
the world implementation better coverage for ownership relations, per-system
state, damage, queries, and lifecycle cleanup.

Useful relations:

* station owns system;
* station owns drone;
* drone assigned to target;
* job-bearing entity targets asteroid, chunk, system, or station;
* chunk sourced from asteroid;
* system belongs to a capacity category;
* resource stored in station.

Useful traits:

* persistent;
* temporary;
* harvestable;
* processable;
* powered;
* damaged;
* overloaded;
* exportable;
* selectable;
* debug-visible.

Useful events:

* asteroid detected;
* chunk created;
* drone launched;
* harvest completed;
* drone returned;
* resource processed;
* resource bought;
* resource sold;
* resource dumped;
* starter reserve harvested;
* shortage detected;
* storage full;
* logistics blocked;
* system built;
* system upgraded;
* drone damaged;
* repair completed;
* population lost;
* gameover triggered.

## 5. Simulation Loop

The core loop should be simple:

1. Asteroids or chunks drift into station range.
2. The player can manually harvest limited starter reserves from the station's
   main asteroid when drones or external targets are insufficient.
3. Rules create harvest work for useful targets.
4. Idle drones are assigned to work based on capacity, availability, and player
   priorities.
5. Drones spend scheduled time outbound, harvesting, returning, and unloading.
6. Raw resources are processed into produced resources.
7. Resources are consumed by life support, upkeep, maintenance, construction,
   production, sale, purchase, or dumping.
8. Station systems increase capacity or throughput.
9. Full storage, drone shortage, oxygen shortage, food shortage, overload, or
   damage create events and recovery work.

The simulation should be player-controlled at the station-management level.
Drones should be automated by default, with optional overrides later. Production
should be manageable through rules, such as "if X is less than N, process A
into B" or "if Y is more than N, sell or stop producing it".

## 6. Growth And Tech

Growth should be station-scaled and capacity-driven.

The station expands by spending resources directly on systems that improve
capacity or throughput:

* hangar systems increase drone count;
* refinery systems increase processing throughput;
* storage systems increase stock capacity;
* solar systems increase free baseline power;
* reactor systems increase fuel-backed power conversion;
* shipyard systems build and replace drones;
* depot systems increase import/export throughput;
* assembly systems produce advanced resources and construction inputs.

Building space should wait until construction and event systems can change it
meaningfully. When added, it should behave as a scalar limit on station growth,
not as cargo in shared storage.

Credits exist to convert surplus resources into missing resources through
market buy/sell behavior. This should be less efficient than producing
in-house. Each resource has a base price that fluctuates over time and is
nudged by player buying or selling. The player can also dump resources when
storage is full and space is needed for more important stock.

Buying and selling should exist in the first loop, but can start as instant
transactions. Hangar or depot throughput can become the limiter once the core
loop is stable.

The tech system is deferred until harvesting, processing, storage, growth,
market exchange, and failure behavior are stable. When added, it should stay
small and focus on rule modifiers such as drone speed, harvest yield,
processing efficiency, upkeep reduction, or repair speed.

## 7. Inspection And Controls

The first interface should be player-facing enough to manage the simple station
loop, with debug visibility kept close at hand.

Initial visuals:

* overlay with buttons and ledgers;
* central grey station circle;
* darker grey asteroid circles drifting in the background at various sizes;
* visible drones with world positions;
* zoom in/out support;
* no panning in the first version.

Expected inspection:

* station resource totals;
* station capacity totals;
* drone counts by state;
* active jobs or job components;
* visible event log;
* selected entity facts;
* active rules or scheduled work;
* current asteroid/chunk list;
* market prices;
* warnings for full storage, drone shortage, oxygen shortage, food shortage,
  overload, damage, or failed jobs.

Expected controls:

* pause and resume;
* single-step tick or fixed tick burst;
* reset simulation;
* spawn asteroid by size or chunk count;
* manually harvest starter reserves;
* buy resource;
* sell resource;
* dump resource;
* build one station system;
* edit production rules;
* override drone assignment when needed;
* force full storage;
* force drone shortage;
* force oxygen or food shortage;
* force drone damage;
* toggle debug overlays.

## 8. Validation Scenarios

Initial validation scenarios:

* Harvest loop: a passing asteroid creates a harvest job, a drone completes it,
  resources enter storage, and events record each phase.
* Bootstrap loop: manual harvesting consumes finite starter reserves and keeps
  the station alive while drone capacity is low.
* Processing loop: regolith, ice, and ore convert into produced resources
  according to active station systems.
* Capacity loop: storage, drone slots, processing throughput, and power limits
  constrain the simulation without hidden correction.
* Power loop: solar power covers baseline demand, reactors burn only the fuel
  needed for unmet demand, and shortages scale powered production down.
* Growth loop: accumulated resources build a new station system, changing
  capacity and visible/debug state.
* Market loop: surplus resources sell for credits, missing resources can be
  bought less efficiently than in-house production, and prices move over time.
* Dump loop: full storage can be relieved by dumping resources, with a visible
  event and resource loss.
* Failure loop: a damaged drone or station system creates a repair job and
  recovers through scheduled work.
* Logistics-collapse loop: drone shortage or full storage blocks useful work and
  emits readable events instead of silently correcting itself.
* Life-support loop: oxygen or food shortage reduces population, and population
  reaching zero triggers gameover.
* Rule-management loop: player production rules change future processing and
  market behavior.
* Tech loop: deferred until the first loops are stable; a later simple upgrade
  changes a rule multiplier and future simulation results show the difference.

## 9. Roadmap Readiness

The first-slice design is now specific enough to start a roadmap.

Roadmap work should still decide implementation order carefully:

* whether resource stockpiles are one station component, typed fact rows, or a
  small game-owned resource table attached to the station;
* whether station systems start as full child entities immediately or whether a
  minimal first pass creates only the systems needed for the initial loop;
* how much of the overlay uses retained UI immediately versus simple debug
  rendering;
* which production rules are hardcoded first and which are player-editable in
  the first slice;
* how much drone override behavior is included before the automated loop works.
