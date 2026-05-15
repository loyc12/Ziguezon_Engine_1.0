# Orbiter — High-Level Design Documentation

## Core Vision

A macro-economic simulation set in a solar system (Ours by default). The player guides humanity's first centuries of off-world expansion, from near-Earth orbit out to the outer planets.

The game is centered around:

* infrastructure planning and growth
* logistical bottleneck resolution
* realistic interplanetary dynamics
* local industrial specialisation
* local political autonomy
* global economic interdependence

The fantasy is to **"be the planning office of a young space-faring civilisation"**, not "command an empire". The player wins by enabling outcomes, not by clicking units. The unit of play is the economy — not the ship or the colony building — and time is measured in weeks and years.

The economy itself should mostly run automatically, with the player intervening at structural and strategic levels ( See "Player Actions" section for a full player-role breakdown )

See [design_philosophy.md](design_philosophy.md) for engineering principles, design heuristics, and collaboration guidelines.

---

# Core Design Principles

## 1. The Simulation Exists To Produce Decisions

Every simulated system must create either:

* decisional tradeoffs
* outcome uncertainty
* flow bottlenecks
* strategic choices

Simulation depth that does not generate meaningful player decisions should be deferred or removed ( The engineering test for this is heuristic #1 in [design_philosophy.md](design_philosophy.md) )

---

## 2. Policy Over Micromanagement (Automate Repetitive Optimal Actions)

The player acts on rates, weights, priorities, and projects — not on individual buildings. The interface scales with the simulation: when the player owns 20 economies, the same policy levers still work. New mechanics must answer "what knob does the player turn?" before they ship.

If an action:

* must be repeated frequently
* has an obvious correct answer
* creates no strategic tension

then it should be either:

* automatable / automated
* abstracted out
* policy-driven

Examples of things to automate:

* routine trade shipments
* basic market balancing
* low-level production scheduling

Player interaction should focus on:

* setting incentives and priorities
* growing infrastructure and wealth
* course-corecting autonomous growth

---

## 3. Preserve Meaningful Constraints (Emergence Over Scripting)

Outcomes should primarily arise from the interaction of simple rules, not from complex scripted events. A famine should be the visible consequence of resource allocation choices and price dynamics. Outcomes should be technically foreseeable based on the current state of the simulation and future player choices, not randomized.

The game should continuously expose:

* logistical bottlenecks
* political instability
* infrastructure limitations
* delayed action feedback
* competing priorities

The simulation should never fully stabilise into:

* permanent, "hands off" equilibrium
* fully self-correcting optimisation
* truly unrecoverable scenario, baring human extinction

---

## 4. Space Is Terrain

Orbital mechanics should create:

* logistical constraints
* route timing windows
* route supply costs
* route specialisation

Space should not merely be visual distance.

---

## 5. Game-Feel Dominates Strict Realism

Orbital mechanics, mass budgets, and biosphere rules are realistic where realism creates interesting decisions, and abstracted where it creates biring or overly detailed bookkeeping. The deltaV table is real; the freighter manifest is not. Choose the version of reality that produces interesting choices, not the one that feels like work.

---

# Player Actions

All player-facing design choices live in this section: who the player is, what they do, and where the boundaries are. Specific economic levers live in the Economic Model section below.

## Player Roles

The player primarily acts as:

* a large scale strategic planner
* a civilisational growth coordinator
* an infrastructure planner
* aneconomic policy decider

## Primary Activities

### Expansion

* develop infrastructure
* unlock new regions
* exploit new resource sites
* establish off-world settlements

### Bottleneck Resolution

* solve complex shortages
* relieve transport congestion
* stabilise fragile colonies
* expand economic capacities

### Infrastructure Planning

* build shared infrastructure
* open new trade routes

### Political Concerns

* expending local autonomy
* governmental stability
* civilisational fragmentation
* competing economic interests

### Economic Steering

Indirect influence through policy levers — see "Player Economic Interaction" in the Economic Model section for the lever list.

## Player Boundaries

### The Player Should NOT:

* manually route every shipment
* micromanage factories continuously
* optimise every market transaction
* directly control every colony indefinitely

### The Player SHOULD:

* shape large-scale systems
* make irreversible strategic decisions
* respond to economic crises
* resolve competing needs
* design resilient infrastructure
* manage inevitable decentralisation

---

# Economic Model

## Structure

Each settled body acts as:

* a increasingly independent economy
* with local supply/demand dynamics
* interacting through interplanetary trade

Trade is:

* largely automatic
* market-driven
* constrained by infrastructure and orbital mechanics

---

## Player Economic Interaction

### Allowed Directives

* subsidies
* tariffs
* taxation
* export bans
* infrastructure investment
* trade fleet investment
* industrial construction

### Avoid

* repetitive manual trade setup
* per-route shipment micromanagement
* constant industrial production tuning
* constant manual industrial (de)growth

---

# Interplanetary Trade

## Core Philosophy

Trade should emerge naturally from:

* local prices from supply and demand
* fuel and other supply costs
* travel time and distance
* cargo fleet capacity
* transport infrastructure

The player primarily shapes trade structurally rather than operationally.

---

## Important Strategic Trade Elements

### Infrastructure

* depots / stockpiles
* localized trade hubs
* orbital shipyards
* mass drivers
* space elevators

### Policy

* trade subsidies and tariffs
* import and export embargoes
* strategic resource reserves
* individual route subsidies

### Risks

* supply shocks
* route disruption and piracy
* political fragmentation
* infrastructural failure

---

# Colony Specialisation

## Goal

Bodies should become economically distinct through:

* local resource availability
* gravity well strenght
* solar energy access
* orbital development
* industrial comparative advantages
* population density and wellfare
* orbital distances

---

## Examples

| Body             | Likely Role                |
| ---------------- | -------------------------- |
| Mercury          | Energy production          |
| Luna             | Heavy industry             |
| Mars             | Population centre          |
| Asteroid Belt    | Mining economy             |
| Titan            | Hydrocarbon extraction     |
| Orbital Habitats | Trade / manufacturing hubs |

---

## Resource Model

### Mineral Resources Should Have:

* estimated quantities
* uncertainty
* exploration progression
* extraction difficulty
* diminishing returns

### Information Precision Improves Through:

* exploration
* research
* settlement
* continuous exploitation

---

# Governance & Political Structure

## Control Gradient

### Homeworld

* direct player control
* strongest administrative reach
* highest stability
* easiest to govern overall

### Minor Colonies

* partial autonomy
* governor systems
* policy ranges

### Major Colonies

* effectively semi-autonomous
* broad directives only
* high local independence
* possible faction divergence
* secession risk

---

## Political Pressure Sources

* underinvestment
* supply instability
* unfair exploitation
* economic isolation

---

# Population Simulation

## Desired Features

Populations should not merely represent labour.

Track:

* growth, migration and decay
* basic needs fulfilment
* higher needs fulfilment
* political autonomy
* infrastructure access
* factional alignment
* unrest and radicalization

---

## Purpose

Population systems exist to create:

* labour supply
* service demands
* gameplay instability
* political dynamics
* settlement planning
* gameplay success metrics

Avoid excessive demographic detail unless it produces gameplay decisions.

---

# Infrastructure Philosophy

Infrastructure is one of the main player expression systems.

## Important Infrastructure Categories

* resource logistics
* construction abilities
* habitatable area
* population ammenities
* trade ammenities
* ecologic modification

---

# Failure & Crisis Systems

The player should consistently have to worry about mismanagement leading to:

* famine
* transport collapse
* political unrest
* infrastructure failure
* economic shocks
* resource shortages
* mineral depletion

---

# Scope Boundaries

## In-Scope ( examples )

* Macro-economic dynamics across solar-system scales
* Resource flows: energy, work, parts, food, water, etc
* Population dynamics: welfare, births, deaths, migration
* Player leverage: taxation, subsidies, tarrifs, policies
* Trade: surplus / deficit matching by price and travel cost
* Money: capital accumulation / decay / depreciation / transactions
* Long-game: technology, megaprojects, societal simulation

## Out-of-Scope ( explicitly )

* Direct unit control (no fleet command, no individual ship orders)
* Combat as a primary loop (shocks and disasters yes; war as core gameplay no)
* Real-time gameplay (only orbital mechanics approach real-time)

---

# Scope Management Rules

## Critical Rule

No deepening of simulation systems unless:

* they already generate meaningful gameplay
* they already create player decisions
* the existing version is already fun
* no critical systems are missing elsewhere

---

## Anti-Scope-Creep Policy

Avoid early implementation of:

* huge commodity chains
* elaborate diplomacy
* complex demographic modelling
* fine-grained ship simulation
* detailed ideological systems
* excessive procedural generation

until the core gameplay loop is proven.

---

# Design North Star

The player experience should feel like governing a growing interplanetary civilisation whose economy mostly operates autonomously, while the player shapes infrastructure, resolves crises, and manages the economic, political and logistical consequences of innevitable expansion.
