# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Baseline

The broad read-only query/view slice is complete.

Live foundation:

* entity creation, liveness checks, destruction, and fact cleanup;
* packed and sparse component stores;
* component views with generation invalidation;
* read-only component lookup and view helpers;
* relation stores, source/target indexes, and cardinality policies;
* dataless relation facts queried by presence;
* read-only relation source/target traversal;
* typed transient event queues;
* read-only event peek and queue traversal without popping records;
* generic entity/component/relation/trait events;
* trait registration, application, removal, presence querying, traversal, and
  cleanup;
* `Persistent` as the first generic trait example;
* `WorldQuery` as the transient read-only inspection facade.

The next roadmap slice is the first executable simulation-logic surface:
commands, systems, and minimal rule/reaction boundaries.

## 2. Slice Goal

Add a small path for game/world logic to observe facts and request changes
without making systems mutate arbitrary stores during traversal.

Primary users are:

* future game systems that need ordered execution;
* rules/reactions that respond to emitted events;
* game code that needs a clearer boundary between observed facts and requested
  changes.

This slice should establish the contract, but it should stop before archetypes,
templates, scheduler cadence work, particles/effects, save/load, replay, or UI
state integration.

## 3. Guardrails

* Keep `WorldQuery` read-only and transient.
* Keep `CompView` as the narrow component fast path.
* Commands represent requested future changes; events record completed changes.
* Do not let systems mutate relation/component/trait/event stores directly while
  iterating query results.
* Do not add a scheduler loop inside `World` yet.
* Do not add archetype/template spawning in this slice.
* Do not add marker components for classification.
* Keep game-specific command, system, and rule payloads under `src/games`.
* Do not run formatting passes such as `zig fmt`.

## 4. Implementation Tasks

1. Define command, system, and rule boundaries in code comments.
   * `commands/command.zig` should describe command payload facts and execution
     ownership.
   * `commands/commandQueue.zig` should describe ordered, transient requested
     changes.
   * `systems/system.zig` should describe observation plus command emission,
     not direct broad mutation.
   * `rules/rule.zig` should describe event-driven reactions after event/query
     semantics are stable.

2. Implement the minimal command queue foundation.
   * Store typed command records with ordering metadata.
   * Support register, push, pop, peek/count, clear, and deinit lifecycle.
   * Keep command queues transient; do not retain command history.
   * Reject uninitialized and unregistered operations cleanly.

3. Add a compact system execution surface.
   * Systems should receive read-only query access and a command-emission path.
   * Keep the first surface small and generic.
   * Avoid a scheduler or cadence abstraction in this slice.
   * Leave direct game-specific system lists under `src/games` until a generic
     manager has a concrete use case.

4. Add a minimal rule/reaction boundary.
   * Rules may observe events and enqueue commands.
   * Do not implement broad rule graph ownership or temporary rules yet.
   * Keep event consumption semantics explicit: peeking should not pop.

5. Add meaningful tests.
   * Command queues should reject uninitialized/unregistered operations.
   * Command peek/iteration must not pop records.
   * System execution must not receive mutable query/storage handles.
   * Rule/event tests should preserve event queue semantics.
   * Lifecycle tests should cover init/deinit and repeated registration.

6. Refresh docs after implementation.
   * Update `reference.md` with the live command/system/rule shape.
   * Trim `roadmap.md` so completed command/system/rule work moves into the
     baseline.
   * Replace this `todo.md` with the next active slice after validation.

## 5. TODO Comment Audit For Validation

Handled in the completed query slice:

* `src/engine/world/queries/query.zig:1` broad query placeholder was replaced
  by the live `WorldQuery` implementation.

Defer to this slice:

* `src/engine/world/commands/command.zig:1`;
* `src/engine/world/commands/commandQueue.zig:1`;
* `src/engine/world/systems/system.zig:1`;
* `src/engine/world/rules/rule.zig:1`.

Defer until later roadmap slices:

* `src/engine/world/scheduler/scheduler.zig:1`;
* `src/engine/world/archetypes/archetype.zig:1`;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.

Defer as unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* tilemap flood, shape, tile type, and bounding-box TODOs;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note.

Validated but left for later tilemap/render cleanup:

* `src/engine/world/tilemap/tilemapManager.zig:277` still has stale
  `Body.renderHitbox()` wording even though the current code renders hitboxes
  with `eng.wDraw`;
* `src/engine/world/tilemap/tilemapManager.zig:296` still has stale
  renderer-construct wording even though the current code calls
  `Tilemap.drawTilemap()`.

## 6. Explicit Non-Goals

* no archetype/template spawning;
* no scheduler implementation;
* no particle/effect pools;
* no save/load, replay, or retained command/event history;
* no retained UI state inside simulation `World`.
