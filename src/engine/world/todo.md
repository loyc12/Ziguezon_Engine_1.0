# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
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
* Components must carry entity data; dataless components are invalid.
* Traits must stay dataless; payload-bearing traits are invalid.
* Add storage policies or config bundles only when a concrete use case needs
  them.
* Keep `CompView` component-only until broad query semantics are designed.
* Keep `EngineTiming` as the base-tick and frame-pacing authority.
* Keep game-specific fact types under `src/games`.
* Destroy entity ids last, after World-owned fact cleanup has run.
* Do not run formatting passes such as `zig fmt`.

## 3. Baseline Reconciliation

Tasks:

* Audit `World.destroyEntity()` tests for combined relation and component
  cleanup coverage.
* Verify generic event emission behavior when event queues are not registered.
* Verify generic event emission behavior when queues are registered before
  entity/component/relation operations.
* Ensure cleanup functions log their own concrete failures through `log()`.
* Keep `EventManager` queues transient for now; do not integrate retained event
  history until a concrete debug or rules/reactions use case needs it.
* Keep `EventManager.clearAll()` / `countAll()` if they cover current game and
  test needs.
* Audit event payload validation and add easy checks for unfit event types
  without blocking dataless event facts.
* Update any stale docs or TODO comments that still describe relations/events
  as unimplemented.

## 4. Trait Implementation Criteria

Implementation decisions:

* traits are dataless classification facts;
* components are the dataful per-entity fact path;
* future trait metadata, if needed, is type-level metadata, not per-entity data;
* trait events follow existing generic event behavior and emit only when their
  event queues are registered;
* `Persistent` is the first generic trait example, marking entities whose
  related facts should be save-relevant once save/load exists.

Tasks:

* Define the zero-sized trait declaration shape.
* Add typed trait registration, application, removal, and presence querying.
* Reject payload-bearing traits at compile time when practical.
* Integrate trait cleanup before entity ids are invalidated by destruction.
* Add generic `TraitApplied` and `TraitRemoved` events.
* Add the dataless `Persistent` example trait.
* Document and enforce component vs relation vs trait selection rules.

## 5. Deferred

Do not start these until baseline reconciliation and the initial trait
implementation are complete:

* broad query/view helpers;
* command queues;
* system registration/execution;
* rules/reactions;
* archetypes/templates;
* scheduler;
* particles/effects;
* context/save-load-facing records.
