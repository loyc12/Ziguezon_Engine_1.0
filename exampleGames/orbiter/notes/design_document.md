# Orbiter — High-Level Design Documentation

## Core Vision

A macro-economic simulation set in a solar system (Ours by default). The player guides humanity's first centuries of off-world expansion, from near-Earth orbit out to the outer planets.

The game is centered around:

* infrastructure planning
* logistical bottlenecks
* delayed interplanetary dynamics
* colony specialisation
* political autonomy
* economic interdependence

The fantasy is **"be the planning office of a young space-faring civilisation"**, not "command an empire". The player wins by enabling outcomes, not by clicking units. The unit of play is the economy — not the ship or the colony building — and time is measured in days and years.

The game is **not** intended to be:

* a detailed commodity micromanagement simulator
* a manual trade routing game
* a spreadsheet optimisation sandbox

The economy itself should mostly run automatically, with the player intervening at structural and strategic levels. See the "Player Actions" section below for the full player-role breakdown.

See [design_philosophy.md](design_philosophy.md) for engineering principles, design heuristics, and collaboration guidelines.

---

# Core Design Principles

## 1. The Simulation Exists To Produce Decisions

Every major system must create:

* tradeoffs
* uncertainty
* bottlenecks
* strategic tension

Simulation depth that does not generate meaningful player decisions should be deferred or removed. The engineering test for this is heuristic #1 in [design_philosophy.md](design_philosophy.md).

---

## 2. Policy Over Micromanagement (Automate Repetitive Optimal Actions)

The player acts on rates, weights, priorities, and projects — not on individual buildings. The interface scales with the simulation: when the player owns 20 economies, the same policy levers still work. New mechanics must answer "what knob does the player turn?" before they ship.

If an action:

* must be repeated frequently
* has an obvious correct answer
* creates no strategic tension

then it should be:

* automated
* abstracted
* or policy-driven

Examples of things to automate:

* routine trade shipments
* basic market balancing
* low-level production scheduling

Player interaction should focus on:

* incentives
* infrastructure
* priorities
* strategic intervention

---

## 3. Preserve Meaningful Constraints (Emergence Over Scripting)

Outcomes should primarily arise from the interaction of simple rules, not from scripted events. A famine should be the visible consequence of resource allocation choices and price dynamics. If we can name the cause downstream of player actions, we did it right.

The game should continuously expose:

* logistical bottlenecks
* political instability
* infrastructure limitations
* delayed feedback
* competing priorities

The simulation should never fully stabilise into:

* permanent equilibrium
* fully self-correcting optimisation

---

## 4. Space Is Terrain

Orbital mechanics should create:

* constraints
* timing windows
* transport costs
* route specialisation
* strategic geography

Space should not merely be visual distance.

---

## 5. Game-Feel Dominates Strict Realism

Orbital mechanics, mass budgets, and biosphere rules are realistic where realism creates interesting decisions, and abstracted where it creates bookkeeping. The deltaV table is real; the freighter manifest is not. Choose the version of reality that produces interesting choices.

---

# Player Actions

All player-facing design choices live in this section: who the player is, what they do, and where the boundaries are. Specific economic levers live in the Economic Model section below.

## Player Roles

The player primarily acts as:

* a strategic planner
* a civilisational coordinator
* an infrastructure architect
* a political governor

## Primary Activities

### Expansion

* establish colonies
* exploit new resource sites
* develop infrastructure
* unlock new regions

### Bottleneck Resolution

* solve shortages
* relieve transport congestion
* stabilise fragile colonies
* expand capacity

### Infrastructure Planning

* build depots
* orbital stations
* shipyards
* industrial hubs
* trade corridors

### Political Governance

* manage autonomy
* maintain legitimacy
* prevent fragmentation
* negotiate competing interests

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
* respond to crises
* prioritise competing needs
* design resilient infrastructure
* manage decentralisation

---

# Economic Model

## Structure

Each settled body acts as:

* a semi-independent economy
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
* stockpile targets
* export bans
* infrastructure investment
* industrial construction
* strategic contracts

### Avoid

* repetitive manual trade setup
* per-route shipment micromanagement
* constant production tuning

---

# Interplanetary Trade

## Core Philosophy

Trade should emerge naturally from:

* prices
* demand
* transport cost
* route capacity
* travel time
* risk
* infrastructure

The player shapes trade structurally rather than operationally.

---

## Strategic Trade Elements

### Infrastructure

* depots
* transfer hubs
* orbital stations
* cyclers
* shipyards
* relay points

### Policy

* trade subsidies
* protected corridors
* tariffs
* embargoes
* strategic reserves

### Risks

* supply shocks
* route disruption
* piracy
* political fragmentation
* infrastructure failure

---

# Colony Specialisation

## Goal

Bodies should become economically distinct through:

* geography
* resource availability
* gravity
* energy access
* infrastructure history
* population composition
* technological development

---

## Examples

| Body Type        | Likely Role                |
| ---------------- | -------------------------- |
| Mercury          | Energy production          |
| Luna             | Heavy industry             |
| Mars             | Population centre          |
| Asteroid Belt    | Mining economy             |
| Titan            | Hydrocarbon extraction     |
| Orbital Habitats | Trade / manufacturing hubs |

---

## Resource Model

### Resources Should Have:

* estimated quantities
* uncertainty
* exploration progression
* extraction difficulty
* diminishing returns

### Information Improves Through:

* exploration
* research
* settlement
* industrial exploitation

---

# Governance & Political Structure

## Control Gradient

### Homeworld

* direct control
* strongest administrative reach
* highest legitimacy

### Core Colonies

* partial autonomy
* governor systems
* policy ranges

### Frontier Colonies

* broad directives only
* high local independence

### Distant / Isolated Colonies

* effectively semi-autonomous
* possible faction divergence
* secession risk

---

## Political Pressure Sources

* underinvestment
* supply instability
* cultural divergence
* economic exploitation
* isolation
* communication delay
* military weakness

---

# Population Simulation

## Desired Features

Populations should not merely represent labour.

Track:

* growth
* migration
* morale
* stability
* faction alignment
* dependency
* radicalization
* isolation pressure

---

## Purpose

Population systems exist to create:

* political dynamics
* labour shortages
* migration flows
* instability
* social divergence

Avoid excessive demographic detail unless it produces gameplay decisions.

---

# Infrastructure Philosophy

Infrastructure is one of the main player expression systems.

## Important Infrastructure Types

### Logistics

* depots
* cargo hubs
* fuel stations
* transfer relays

### Industrial

* shipyards
* refineries
* orbital factories

### Civil

* habitats
* life support
* research facilities

### Strategic

* defence systems
* surveillance
* communication arrays

---

# Failure & Crisis Systems

The game should continuously generate instability.

## Potential Crisis Sources

* famine
* transport collapse
* political unrest
* infrastructure failure
* orbital debris
* economic shocks
* energy shortages
* resource depletion
* secession movements

---

# Scope Boundaries

## In-Scope

* Macro-economic dynamics across solar-system scales
* Resource flows: energy, work, parts, food, water, etc
* Population dynamics: welfare, births / deaths, migration
* Government: taxation, subsidies, public works, policy
* Trade: surplus / deficit matching by price and travel cost
* Money: capital accumulation / decay / depreciation / transactions
* Long-game: technology, megaprojects, societal simulation
* Player leverage: policies, rates, discretionary investments, state actions

## Out-of-Scope (explicitly)

* Direct unit control (no fleet command, no individual ship orders)
* Combat as a primary loop (shocks and disasters yes; war as gameplay no, or at least not until the game ships out first)
* Real-time gameplay (only orbital mechanics can be near real-time)

---

# Scope Management Rules

## Critical Rule

No deepening of simulation systems unless:

* they already generate meaningful gameplay
* they already create player decisions
* the existing version is already fun

---

## Anti-Scope-Creep Policy

Avoid early implementation of:

* huge commodity chains
* deep combat systems
* elaborate diplomacy
* complex demographic modelling
* fine-grained ship simulation
* detailed ideological systems
* excessive procedural generation

until the core gameplay loop is proven.

---

# Design North Star

The player experience should feel like:

> governing a growing interplanetary civilisation whose economy mostly operates autonomously, while the player shapes infrastructure, resolves crises, and manages the political and logistical consequences of expansion.
