# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Build the first executable simulation-logic surface:

* commands as requested future changes;
* systems as ordered logic that observes `World` through read-only query access;
* rules as small event/fact reactions that can enqueue commands.

Keep this slice narrow. It should establish the first usable command/system/rule
contracts without adding archetypes, templates, scheduler cadence, particles,
save/load, replay, retained history, or UI state.

## 2. Guardrails

* Keep `WorldQuery` read-only and transient.
* Keep `CompView` as the narrow component fast path.
* Commands request changes; events record things that happened.
* Do not let generic systems mutate arbitrary stores while traversing broad query
  results.
* Do not add a scheduler loop inside `World` yet.
* Do not add archetype/template spawning in this slice.
* Do not add marker components for classification.
* Keep game-specific command, system, and rule payloads under `src/games`.
* Keep engine examples minimal and generic.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Restore the current query/test baseline.
   * Fix relation source/target iterator API mismatches between `World` and
     `RelationStoreFactory`.
   * Fix trait entity iterator API mismatches between `World` and
     `TraitSetFactory`.
   * Confirm the current read-only query surface compiles before layering command
     and system work on top.

2. Define the command boundary.
   * Document command payload expectations in `commands/command.zig`.
   * Commands should be plain requested-change facts, not completed-event records.
   * Reject invalid command payload shapes when the check is simple and useful.
   * Keep command execution ownership explicit and out of payload declarations.

3. Implement a minimal typed command queue.
   * Store typed command records with ordering metadata.
   * Support init/deinit, push, pop, peek/count, clear, and iteration without
     popping.
   * Reject uninitialized and unregistered operations cleanly.
   * Keep queues transient; do not retain command history.

4. Add the smallest useful command ownership surface.
   * Prefer a `CommandManager` only if direct typed queues become awkward.
   * If added to `World`, keep the API symmetrical with events where practical.
   * Do not add command replay, undo, delayed commands, or retained history.

5. Define and implement a compact system surface.
   * Systems should receive read-only `WorldQuery` access.
   * Systems should emit commands through the command surface instead of mutating
     broad stores directly.
   * Keep registration/order support minimal.
   * Leave game-specific system lists under `src/games` unless a generic manager
     has a concrete use case.

6. Define a minimal rule/reaction boundary.
   * Rules may observe events or queried facts and enqueue commands.
   * Do not implement broad rule graph ownership, temporary rules, or scheduler
     integration yet.
   * Preserve event queue semantics: peeking and iteration must not pop records.

7. Add focused tests.
   * Current query traversal tests should compile and pass first.
   * Command queues should cover lifecycle, ordering, peek/iteration, clear, and
     rejection of uninitialized or unregistered operations.
   * System tests should demonstrate read-only query access plus command emission.
   * Rule tests should demonstrate event observation without consuming events.

8. Refresh docs after implementation.
   * Update `reference.md` with the live command/system/rule shape.
   * Trim `roadmap.md` so completed command/system/rule work moves into the
     baseline.
   * Replace this `todo.md` with the next active slice after validation.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Use targeted tests while developing, but the slice is not complete until the
world test surface compiles and the relevant tests pass.

## 5. Deferred Work

Later roadmap slices:

* `src/engine/world/archetypes/archetype.zig`;
* `src/engine/world/archetypes/archetypeManager.zig`;
* `src/engine/world/scheduler/scheduler.zig`;
* `src/engine/world/particles`;
* `src/engine/world/context`;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note.

Post `legacy_tilemap` migration cleanup:

* remove remaining engine-world documentation references to tilemap after the code
  is moved to `src/utils/legacy_tilemap`.

## 6. Explicit Non-Goals

* no archetype/template spawning;
* no scheduler implementation;
* no particle/effect pools;
* no save/load, replay, undo, or retained command/event history;
* no retained UI state inside simulation `World`;
* no tilemap migration work in this `engine/world` slice.
