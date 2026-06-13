# Orbiter Goals

This file records rework-specific target state for Orbiter. The broad game
design belongs in [design_doc.md](design_doc.md). Broad design and
engineering philosophy belongs in [design_philo.md](design_philo.md).

Current implementation facts belong in [reference.md](reference.md).
Implementation sequencing belongs in [roadmap.md](roadmap.md). Short active
tasks belong in [todo.md](todo.md).

## 1. Status

These goals are intentionally under review. The older Orbiter design direction
was broad and partly stale relative to the current implementation and the
expected engine stabilization work.

Until this file is rebuilt in detail, treat it as the stable high-level intake
for the next Orbiter rework rather than a complete subsystem specification.

## 2. Current Rework Intent

The next Orbiter rework should preserve the macro-scale premise while replacing
debug scaffolding with deliberate game systems. The high-level direction is
still close to the desired game, but many established subsystem details should
be considered provisional and open to teardown or rebuild.

The likely rework endpoint should define:

* a playable economy loop across three interdependent economies, initially
  Terra, Luna, and Venus;
* a replacement for `debugAutoBuild()` using real agent, government, or player
  order paths;
* coherent construction funding, materials, effort, cancellation, and refunds;
* a narrow but real player lever for investment or policy;
* the first automatic inter-economy trade path;
* the boundary between abstract logistics and future vessel-mediated logistics;
* which politics and autonomy concepts are explicitly deferred until after the
  MVP loop works;
* which current economy data tables should survive, shrink, or be rebuilt.

The MVP should avoid politics as an active gameplay layer. Government,
autonomy, unrest, legislation, and policy divergence can remain represented as
future-facing data or design hooks, but they should not drive the first playable
loop unless a later design pass explicitly promotes them.

## 3. Non-Negotiable Direction

Orbiter should remain a macro-scale game. The core loop should not become:

* per-ship tactical command;
* factory-by-factory production micromanagement;
* repetitive manual shipment routing;
* combat-first strategy;
* simulation depth that creates no player decision.

The simulation should stay physically grounded. Money, prices, and policy
should influence agent behavior and transactions without replacing resource,
capacity, time, and logistics accounting.

`G_DATA` may remain as the game-owned global state holder for broadly accessed
Orbiter runtime data, similar in spirit to how `D_CONST` holds mostly-constant
data. The rework target is not to eliminate all global access. The target is to
keep ownership clear, avoid accidental hidden simulation state, and keep
mutable data explicit enough to reason about, reset, and eventually serialize.

## 4. Known Goal Rework Inputs

The next rewrite should explicitly decide these tensions instead of inheriting
them silently:

* the current game is a simulation/debug sandbox, not a playable loop;
* broad design docs still assume automatic economic growth, trade, and policy
  that are not implemented;
* government types and monetary state exist, but government behavior is a stub
  and should not be part of the first MVP gameplay loop;
* transfer estimation exists, but trade signals, cargo records, tariffs, and
  arrival accounting do not;
* vessel metrics exist, but vessels have no state, lifecycle, movement, or
  cargo integration;
* construction currently depends on a transitional queue and debug automation;
* `G_DATA` should be kept, but its contents and boundaries need review so it
  remains an intentional game-owned state surface rather than miscellaneous
  hidden state;
* the reused economy solver may still conflict with future scaling,
  serialization, or inspectability goals;
* the resource, infrastructure, industry, settlement, and population target
  surfaces may be too broad for the next playable slice;
* many currently established subsystem designs may need significant rework
  before they are suitable foundations for the three-economy MVP.
