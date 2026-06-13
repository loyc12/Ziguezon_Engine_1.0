# Orbiter Goals

This file records rework-specific target state for Orbiter. The broad game
design belongs in [../design_doc.md](../design_doc.md). Broad design and
engineering philosophy belongs in [../design_philo.md](../design_philo.md).

Current implementation facts belong in [reference.md](reference.md).
Implementation sequencing belongs in [roadmap.md](roadmap.md). Short active
tasks belong in [todo.md](todo.md).

## 1. Status

These goals are intentionally under review. The older Orbiter design direction
was broad and partly stale relative to the current implementation and the
expected engine stabilization work.

Until this file is rebuilt, treat it as a rework intake document rather than a
complete authority for final gameplay design.

## 2. Current Rework Intent

The next Orbiter rework should preserve the macro-scale premise while replacing
debug scaffolding with deliberate game systems.

The likely rework endpoint should define:

* a playable economy loop across at least two interdependent economies;
* a replacement for `debugAutoBuild()` using real agent, government, or player
  order paths;
* coherent construction funding, materials, effort, cancellation, and refunds;
* a narrow but real player lever for investment or policy;
* the first automatic inter-economy trade path;
* the boundary between abstract logistics and future vessel-mediated logistics;
* how much local political autonomy belongs in the MVP loop;
* which current economy data tables should survive, shrink, or be rebuilt.

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

## 4. Known Goal Rework Inputs

The next rewrite should explicitly decide these tensions instead of inheriting
them silently:

* the current game is a simulation/debug sandbox, not a playable loop;
* broad design docs still assume automatic economic growth, trade, and policy
  that are not implemented;
* government types and monetary state exist, but government behavior is a stub;
* transfer estimation exists, but trade signals, cargo records, tariffs, and
  arrival accounting do not;
* vessel metrics exist, but vessels have no state, lifecycle, movement, or
  cargo integration;
* construction currently depends on a transitional queue and debug automation;
* the global `G_DATA` state and reused economy solver conflict with the clean
  state-explicit ideal in the philosophy doc;
* the resource, infrastructure, industry, settlement, and population target
  surfaces may be too broad for the next playable slice.
