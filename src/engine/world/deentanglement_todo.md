# World Query / Manager / Rule Deentanglement Todo

This file is the active prerequisite slice before retrying [todo.md](todo.md).
It exists because the previous World-owned rule-manager pass hit a real Zig
dependency loop and then drifted into implementation choices outside the useful
work slice. [deentanglement_handoff_note.md](deentanglement_handoff_note.md)
records that failed attempt.

Do this work from a clean implementation baseline. Do not try to rescue partial
failed edits from the earlier attempt.

## 1. Preface - Agent Guardrails

This phase is already completed.

## 2. Query Cleanup

This phase is completed. `WorldQuery` is now a stateless helper namespace and
rule examples/tests pass the inspected World explicitly.

## 3. World / WorldManager Split

This phase is completed. The concrete `World` implementation lives in
`core/world.zig`, and `WorldManager` wraps one active World for the engine.

## 4. Rule Cleanup

Goal: remove persistent World ownership from rule-manager internals and make
rule execution borrow the owning World only for one run.

Target shape:

* `World` owns registered rule storage through a focused `RuleManager`;
* `RuleManager` stores rules, rejects duplicate names, and provides
  deterministic ordering;
* `RuleManager` does not store `*World`;
* `RuleManager` does not store a persistent world context wrapper;
* `RuleManager` does not become a broad world orchestration layer;
* `World` or a closely owned World execution helper constructs any short-lived
  context needed for a rule pass;
* rules read facts through the stateless `WorldQuery` helpers and request
  mutations through the command queue;
* rule execution remains explicit in this slice; do not wire automatic rule
  phases into `World.tick(...)`.

Design checkpoint:

* decide the rule function boundary before moving declarations:
  * whether rules can receive `*World` directly;
  * whether rules receive a narrower short-lived context;
  * whether that context must live in `core/world.zig` to avoid cycles;
  * whether another direct, concrete boundary is clearer.
* Do not choose type erasure, factories, dependency injection, or generic
  wrappers only to silence a compile-time loop.
* If a concrete `RuleContext` that references `World` recreates the known
  dependency loop, stop and report it instead of layering around it.

Required work:

* keep `rules/rule.zig` focused on the smallest stable rule declaration
  surface;
* keep `rules/ruleManager.zig` focused on rule storage and ordering;
* let World-owned code coordinate execution with the current World value;
* update tests so rules inspect facts through
  `WorldQuery.get...( world, ... )`;
* preserve deterministic order, duplicate-name rejection, visible rule failure,
  event inspection without consumption, and command enqueueing;
* do not implement command execution ownership, scheduler cadence, delayed
  events, temporary rules, or `RuleSet`.

Validation gate:

* run `zig build test` after each boundary move:
  * rule declarations;
  * rule manager storage;
  * World-owned rule execution;
  * public exports.
* If a boundary move fails because of a dependency loop, preserve the exact
  compiler error in the follow-up report.

## 5. Documentation Refresh After Rule Cleanup Validation

The query cleanup and World/WorldManager split have received a scoped
documentation refresh. After the rule cleanup passes validation, update the
durable docs again before moving on from this prerequisite sequence.

Required docs:

* update [goals.md](goals.md) with the target ownership model:
  * engine owns `WorldManager`;
  * `WorldManager` wraps one World for now but is shaped for later multi-world
    ownership;
  * concrete World implementation lives under `world/core/`;
  * `WorldQuery` is stateless;
  * rules do not store persistent World ownership.
* update [reference.md](reference.md) with the validated rule boundary and
  public access paths;
* update [roadmap.md](roadmap.md) so completed rule cleanup becomes baseline
  and remaining work is sequenced from the new architecture;
* rewrite [todo.md](todo.md) so the next implementation slice starts from the
  fully validated query / manager / rule boundaries;
* remove stale wording that still treats pre-cleanup rule ownership as current.

Docs should reflect validated code, not the intended design, unless the section
is explicitly target-state guidance in `goals.md`.

## 6. Explicit Non-Goals

Do not implement these in this prerequisite slice:

* true multi-world runtime behavior;
* world id allocation or world registries;
* world switching;
* save/load, replay, undo, or retained world history;
* automatic rule execution from `World.tick(...)`;
* command execution ownership;
* scheduler cadence;
* delayed events or temporary rules;
* `RuleSet`;
* archetype behavior changes;
* particle/effect pools;
* retained UI state inside simulation World;
* game-specific rule migrations beyond test/example updates needed to compile.

## 7. Final Validation

The slice is complete only when:

* `zig build` passes;
* `zig build test` passes;
* query helpers no longer retain World state;
* the engine owns `WorldManager`;
* `WorldManager` wraps the single active World;
* concrete World implementation lives under `src/engine/world/core/`;
* rule-manager internals no longer retain persistent World ownership;
* rule cleanup has been validated from the new `core/world.zig` boundary;
* goals, reference, roadmap, and todo docs have been refreshed after the rule
  cleanup from the validated implementation.

Docs-only edits to this file do not require a build.
