# Orbiter Design Document

This file holds broad game-design direction for Orbiter as a whole. It is not
economy-specific implementation guidance. Current implementation facts belong
in [reference.md](reference.md), active rework targets belong in
[goals.md](goals.md), and engineering/design heuristics belong in
[design_philo.md](design_philo.md).

## Core Vision

Orbiter is a macro-economic simulation set in a solar system. The default frame
is humanity's first centuries of off-world expansion, from near-Earth space out
to the outer planets.

The player is closer to the planning office of a young space-faring
civilization than an empire commander. The player wins by enabling outcomes,
not by clicking individual units.

The unit of play is the economy, not the individual ship, facility, or colony
building. Time is measured in weeks and years. The economy should mostly run
automatically, with the player intervening at structural and strategic levels.

The game centers on:

* infrastructure planning and growth;
* logistical bottleneck resolution;
* realistic-enough interplanetary dynamics;
* local industrial specialization;
* local political autonomy;
* global economic interdependence.

## Player Role

The player primarily acts as:

* a large-scale strategic planner;
* a civilization-growth coordinator;
* an infrastructure planner;
* an economic policy decider.

Primary player activities:

* expand into new regions;
* develop infrastructure;
* exploit resource sites;
* establish off-world settlements;
* solve shortages and transport congestion;
* stabilize fragile colonies;
* plan shared infrastructure and trade routes;
* manage autonomy, stability, and political pressure;
* steer economies through policies and investment.

The player should not:

* route every shipment manually;
* continuously micromanage factories;
* optimize every market transaction;
* directly control every colony indefinitely.

Any mechanic should answer: what decision does this create for the player?

## Core Design Principles

Simulation exists to produce decisions. Every simulated system should create at
least one of:

* decision tradeoffs;
* outcome uncertainty;
* flow bottlenecks;
* strategic choices.

Simulation depth that does not generate meaningful player decisions should be
deferred or removed.

Policy should replace micromanagement. If an action must be repeated
frequently, has an obvious correct answer, and creates no strategic tension, it
should become automatic, abstracted, or policy-driven.

Meaningful constraints should emerge from interacting rules rather than
scripted outcomes. A famine, shortage, boom, or collapse should be technically
explainable from visible state and player choices.

Space is terrain. Orbital mechanics should create logistical constraints,
route-timing windows, route supply costs, and route specialization.

Game feel wins over strict realism when realism becomes bookkeeping. Realism is
valuable when it creates interesting decisions.

The game should convey early-to-late space colonization with enough realism to
feel faithful to plausible future space settlement. Isaac Arthur-style
colonization scale and Aurora 4X-style systemic readability are important
inspirations. When realism, compute cost, and gameplay feel conflict, choose the
abstraction that preserves the space-colonization feel while keeping the
simulation stable and playable.

## Economic Model

Each settled body or location should become an increasingly independent local
economy with supply, demand, facilities, population, resources, capacities, and
eventual government state.

The near-term MVP is primarily an economic-simulation sandbox. Player controls
are useful when they help test or steer the economy, but the first priority is
bringing the economy back to a stable, autonomous, inspectable state on the
reworked systems.

Trade should emerge from:

* local prices;
* surplus and shortage;
* fuel and supply costs;
* travel time;
* route capacity;
* orbital timing;
* political policy.

Player economic interaction should happen through high-level levers such as:

* subsidies;
* tariffs;
* taxation;
* export restrictions;
* infrastructure investment;
* trade fleet investment;
* industrial construction policy.

The target economy remains physical first and monetary second. Resource flows,
work, energy, food, materials, and capacity are the base invariants. Money and
prices are signals that affect agent decisions and transactions; they should
not replace physical accounting.

Capacity resources are special resources. They represent local availability
rather than transportable stock: labor, area, storage, power capacity, housing,
construction effort, compute, and similar constraints. They should be priced by
availability and produced by facilities or population.

## Interplanetary Trade

Trade should be largely automatic, market-driven, and constrained by
infrastructure and orbital mechanics. The player shapes trade structurally
rather than operationally.

For the MVP, trade can be abstract: route-specific trader agents buy from a
source economy, sell wholesale to a destination economy on the next tick, and
internalize profits or losses. Transport costs should be mass-based and
cost-gated. Capacity resources cannot be transported, and migration is deferred.

Strategic trade elements include:

* depots and stockpiles;
* localized trade hubs;
* orbital shipyards;
* mass drivers and elevators;
* trade subsidies and tariffs;
* import and export embargoes;
* strategic resource reserves;
* individual route subsidies.

Trade risks include supply shocks, route disruption, political fragmentation,
infrastructure failure, and isolation.

## Colony Shape

Colony specialization should come from local constraints and opportunities:

* resource deposits;
* terrain and body type;
* atmosphere;
* sunlight;
* orbit and transfer costs;
* existing industry;
* infrastructure capacity;
* government policy.

Settlement archetypes may include:

* surface settlements on hospitable worlds;
* buried settlements on inhospitable worlds and asteroids;
* airborne settlements on Venus-like or gas-giant environments;
* orbital habitats;
* mobile world ships;
* automated quarries and mines.

Bodies should become economically distinct through gravity well strength,
solar-energy access, orbital development options, industrial comparative
advantages, population density, welfare pressures, and orbital distances.

## Resources And Population

Resource families may grow toward capacity, material, manufactured, and
consumable groups. Candidate future resources include housing, labor, compute,
energy, research, organics, water ice, volatiles, silicates, metals, deuterium,
ingots, plating, fabrics, structures, electronics, machinery, food, appliances,
clean water, clean air, and waste streams.

Mineral resources should eventually support estimated quantities, uncertainty,
exploration progression, extraction difficulty, and diminishing returns.
Information precision should improve through exploration, research, settlement,
and continuous exploitation.

Population should not merely represent labor. Population systems exist to
create labor supply, service demands, instability, political dynamics,
settlement planning, and success metrics.

Candidate population behavior includes:

* growth, migration, and decay;
* basic and higher needs fulfilment;
* political autonomy;
* infrastructure access;
* factional alignment;
* unrest and radicalization.

Avoid demographic detail unless it produces gameplay decisions.

## Governance

Politics should make distant and mature colonies harder to govern directly.
Governance should eventually include:

* local governors;
* taxes;
* subsidies;
* grants;
* welfare;
* legislation;
* embargoes;
* unrest;
* autonomy pressure;
* policy divergence.

The player should guide and negotiate with local systems more than directly
command every outcome.

Control should form a gradient:

* homeworld economies have direct player control, strong administrative reach,
  and high stability;
* minor colonies have partial autonomy, governor systems, and policy ranges;
* major colonies become semi-autonomous, locally independent, and politically
  capable of divergence.

Political pressure sources include underinvestment, supply instability, unfair
exploitation, and economic isolation.

Politics is not part of the immediate MVP. Taxes and subsidies may exist as
economic controls, but autonomy, laws, unrest, welfare, and local-governor
behavior should wait until the core economy and trade loop is stable.

## Facilities And Vessels

Facilities are the stable combined concept for current infrastructure and
industry. They should support the economic loop rather than become a manual
building game.

Candidate facility families include:

* habitation and housing;
* worksites, shipyards, colleges, and laboratories;
* solar, fusion, water, waste, mining, agronomic, and hydroponic facilities;
* ore and gas refineries;
* manufacturing chains;
* service structures such as data centers and marketplaces;
* power, water, transit, launch, mass-driver, and elevator networks.

Important facility roles include resource logistics, construction
ability, habitable area, population amenities, trade amenities, and ecological
modification.

Vessels should eventually be capacity and logistics tools rather than tactical
units. Candidate modules include cargo holds, fluid tanks, quarters, reactors,
engines, shielding, hangars, and mass drivers.

## Failure And Crisis

The player should consistently have to worry about mismanagement leading to:

* famine;
* transport collapse;
* political unrest;
* infrastructure failure;
* economic shocks;
* resource shortages;
* mineral depletion.

The simulation should not fully stabilize into permanent hands-off
equilibrium, fully self-correcting optimization, or truly unrecoverable failure
short of human extinction.

## Scope Boundaries

In scope:

* solar-system expansion;
* local economies;
* autonomous industry and infrastructure growth;
* inter-economy trade;
* political pressure;
* policy-driven player control;
* strategic infrastructure and logistics;
* long-game technology, megaprojects, and societal simulation once the core
  loop is proven.

Out of scope for the core loop:

* direct combat;
* player-vs-bot diplomacy;
* multiplayer-like polity warfare;
* per-ship tactical command;
* factory-by-factory production micromanagement;
* real-time gameplay outside orbital visualization.

Avoid early implementation of:

* huge commodity chains;
* elaborate diplomacy;
* complex demographic modeling;
* fine-grained ship simulation;
* detailed ideological systems;
* excessive procedural generation.

No deepening of simulation systems unless they already generate meaningful
gameplay, already create player decisions, the existing version is already fun,
or no critical systems are missing elsewhere.

The economic simulation is the core of the game, but the project should not
lose sight of becoming playable. Once the economy is stable, future design work
should establish a clearer gameplay core beyond vague policy-lever ideas.

## North Star

The player experience should feel like governing a growing interplanetary
civilization whose economy mostly operates autonomously, while the player
shapes infrastructure, resolves crises, and manages the economic, political,
and logistical consequences of expansion.
