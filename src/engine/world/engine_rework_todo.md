# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[engine_rework_reference.md](engine_rework_reference.md) describes the current
baseline. [engine_rework_goals.md](engine_rework_goals.md) describes the target
state. [engine_rework_roadmap.md](engine_rework_roadmap.md) defines the broader
implementation order.

## 1. Current Baseline

* Entity creation, liveness checks, and destruction exist.
* Component stores and component views exist.
* Relation stores, indexes, cleanup, and cardinality policies exist.
* Typed transient event queues and generic entity/component/relation events
  exist.
* Commands, systems, rules, traits, archetypes, scheduler, broad queries,
  particles/effects, and context are still placeholder or minimal surfaces.

## 2. Guardrails

* Do not describe relations or events as future-only work; they are live.
* Do not add marker components for classification.
* Keep `CompView` component-only until broad query semantics are designed.
* Keep `EngineTiming` as the base-tick and frame-pacing authority.
* Keep game-specific fact types under `src/games`.
* Do not run formatting passes such as `zig fmt`.

## 3. Baseline Reconciliation

Tasks:

* Audit `World.destroyEntity()` tests for combined relation and component
  cleanup coverage.
* Verify generic event emission behavior when event queues are not registered.
* Verify generic event emission behavior when queues are registered before
  entity/component/relation operations.
* Check whether `RelationManager.removeEntity()` result data is sufficient for
  debugging cleanup failures.
* Check whether `EventManager.clearAll()` / `countAll()` are enough for current
  game and test needs.
* Update any stale docs or TODO comments that still describe relations/events
  as unimplemented.

## 4. Trait Entry Criteria

Before implementing traits:

* decide the minimal trait declaration shape;
* decide whether traits can carry payloads immediately or start dataless;
* define trait cleanup on entity destruction;
* define generic trait events;
* define the first generic examples;
* document component vs relation vs trait selection rules.

## 5. Deferred

Do not start these until baseline reconciliation and trait entry decisions are
settled:

* broad query/view helpers;
* command queues;
* system registration/execution;
* rules/reactions;
* archetypes/templates;
* scheduler;
* particles/effects;
* context/save-load-facing records.
