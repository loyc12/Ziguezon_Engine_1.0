# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Baseline

The previous baseline reconciliation and initial trait implementation are
complete.

Live foundation:

* entity creation, liveness checks, destruction, and fact cleanup;
* packed and sparse component stores;
* component views with generation invalidation;
* relation stores, source/target indexes, and cardinality policies;
* dataless relation facts queried by presence;
* typed transient event queues and generic entity/component/relation/trait
  events;
* trait registration, application, removal, presence querying, and cleanup;
* `Persistent` as the first generic trait example.

The next roadmap slice is broad read-only query/view support.

## 2. Slice Goal

Add a practical read-only inspection layer for components, relations, events,
and traits without turning query helpers into owners of simulation facts.

Primary users are:

* future systems that need repeated read access;
* debug/inspection UI;
* game code that needs clearer fact traversal than reaching into store internals.

This slice should be useful on its own, but it should stop before commands,
systems, rules, archetypes, scheduler, particles/effects, or save/load context.

## 3. Guardrails

* Keep `CompView` as the narrow component fast path.
* Query/view helpers are transient and read-only.
* Do not add hidden ownership, cached mutable fact state, or retained event
  history.
* Do not merge UI state into simulation `World`.
* Do not add marker components for classification.
* Do not add storage policies or config bundles without a concrete use case.
* Keep game-specific fact types under `src/games`.
* Do not run formatting passes such as `zig fmt`.

## 4. Implementation Tasks

1. Define the query/view boundary in code comments.
   * `queries/query.zig` should become the broad read-only query home.
   * `views/view.zig` should stay focused on `CompView`.
   * Queries may wrap existing store APIs, but should not own or mutate facts.

2. Add missing read-only traversal primitives.
   * Add a read-only entity-id iterator or equivalent for trait sets.
   * Add read-only event queue inspection that does not pop or retain records.
   * Expose relation source/target iteration through `World` wrappers if the
     query layer needs it.
   * Keep direct component iteration routed through existing component stores
     and `CompView`.

3. Implement a compact first query surface.
   * Prefer small helpers that compose existing component, relation, event, and
     trait APIs over a large query DSL.
   * Cover common presence checks and traversal paths first.
   * Reject unsupported broad-query shapes explicitly instead of guessing.
   * Leave archetype and particle/effect query integration out of this slice.

4. Add meaningful tests.
   * Query helpers should fail cleanly on uninitialized worlds, unregistered
     stores, dead entities, and stale component views.
   * Read-only event inspection must not remove records.
   * Trait traversal must not expose mutable trait storage.
   * Relation source/target query behavior should preserve existing
     cardinality/index semantics.

5. Refresh docs after implementation.
   * Update `reference.md` with the live query/view shape.
   * Trim `roadmap.md` so completed query work is moved into the baseline.
   * Replace this `todo.md` with the next active slice after validation.

## 5. TODO Comment Audit For Validation

No source TODO comments were changed while preparing this plan. Proposed
handling:

* Address in this slice:
  * `src/engine/world/queries/query.zig:1` broad query placeholder.
* Defer until later roadmap slices:
  * `src/engine/world/commands/command.zig:1`;
  * `src/engine/world/commands/commandQueue.zig:1`;
  * `src/engine/world/systems/system.zig:1`;
  * `src/engine/world/rules/rule.zig:1`;
  * `src/engine/world/scheduler/scheduler.zig:1`;
  * `src/engine/world/archetypes/archetype.zig:1`;
  * `src/engine/world/components/baseComps.zig:178` particle-system TODO.
* Defer as unrelated to this slice:
  * `src/engine/world/entity.zig:22` compact lifecycle mask idea;
  * tilemap flood, shape, tile type, and bounding-box TODOs;
  * `src/engine/world/components/baseComps.zig:77` LOD/minScale note.
* Validate before dropping or rewriting:
  * `src/engine/world/tilemap/tilemapManager.zig:277` still references
    `Body.renderHitbox()`;
  * `src/engine/world/tilemap/tilemapManager.zig:296` still references a
    renderer-construct cleanup.

## 6. Explicit Non-Goals

* no command queues;
* no system execution;
* no rules/reactions;
* no archetype/template spawning;
* no scheduler implementation;
* no particle/effect pools;
* no save/load or retained event history.
