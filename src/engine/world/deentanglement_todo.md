# World Query / Manager / Rule Deentanglement Todo

This file is the active prerequisite slice before retrying [todo.md](todo.md).
It exists because the previous World-owned rule-manager pass hit a real Zig
dependency loop and then drifted into implementation choices outside the useful
work slice. [deentanglement_handoff_note.md](deentanglement_handoff_note.md)
records that failed attempt.

Do this work from a clean implementation baseline. Do not try to rescue partial
failed edits from the earlier attempt.

## 1. Preface - Agent Guardrails

Before code changes, make compact instruction updates to `AGENTS.md` and the
relevant style docs.

Required direction:

* stay inside the active todo slice;
* do not make large ad-hoc architecture fixes when a slice exposes a broader
  issue;
* report out-of-scope issues, contradictions, and dependency loops to the user
  with exact files and compiler errors;
* ask before broad module reshaping, type erasure, generic factories,
  dependency-injection layers, or compatibility surfaces;
* avoid pointless indirection such as one-use factories, wrappers around a
  single concrete type, needless heap allocations or type erasure, and
  abstraction layers whose only purpose is hiding direct ownership;
* prefer direct concrete code until the compiler or a clear ownership problem
  proves a boundary must change;

Keep these instruction edits short. Do not paste a long postmortem into
`AGENTS.md`; detailed context belongs in this file and the handoff note.

## 2. Query Cleanup

Goal: make `WorldQuery` a stateless helper namespace for const access to World
facts.

Required work:

* remove the stored `world : *World` field from `WorldQuery`;
* remove `WorldQuery.init(...)`;
* pass `world` explicitly into query helpers;
* prefer `world : *const World` for read-only helpers;
* use `world : *World` only where an existing World API forces mutable access;
* keep query helpers focused on read-only inspection of entities, components,
  relations, traits, events, and view validity;
* update tests and rule examples from `query.get...(...)` to
  `WorldQuery.get...( world, ... )`;
* do not move rule ownership or rule execution while doing this step.

Validation gate:

* run `zig build test`;
* if this exposes unrelated failures, report them instead of expanding the
  query slice.

## 3. World / WorldManager Split

Goal: move concrete World implementation into `world/core/` and make
`WorldManager` the engine-owned facade that wraps one World for now.

Target shape:

* `src/engine/world/core/world.zig` owns the concrete `World` type and closely
  owned World behavior;
* `src/engine/world/worldManager.zig` owns the `WorldManager` type, public
  world-facing re-exports, and top-level manager/facade behavior;
* the engine owns `WorldManager`, not `World` directly;
* `WorldManager` holds a single `World` instance for now;
* `WorldManager` should be shaped so it can later become a multi-world manager
  without forcing game code to know current storage details;
* do not implement true multi-world behavior in this slice;
* do not add a world registry, world ids, world switching, save/load, or
  retained world history yet.

Required work:

* move the current concrete `World` implementation out of `worldManager.zig`
  and into `core/world.zig`;
* update imports so files that need concrete World behavior import
  `core/world.zig`;
* keep `worldManager.zig` thin and avoid absorbing query or rule
  implementation details;
* expose only the WorldManager helpers needed by current engine/game callers;
* preserve the current single-world behavior through the manager wrapper;
* update engine ownership sites so the engine owns and steps through
  `WorldManager`;
* keep the public surface compact; avoid compatibility aliases unless a caller
  transition truly needs them;
* remove dead code made obsolete by the move.

Validation gate:

* run `zig build`;
* run `zig build test`;
* if the move exposes a dependency loop, stop and report the exact loop before
  changing the architecture.

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

## 5. Documentation Refresh After Validation

After the code changes pass validation, update the durable docs before retrying
the old [todo.md](todo.md) work.

Required docs:

* update [goals.md](goals.md) with the target ownership model:
  * engine owns `WorldManager`;
  * `WorldManager` wraps one World for now but is shaped for later multi-world
    ownership;
  * concrete World implementation lives under `world/core/`;
  * `WorldQuery` is stateless;
  * rules do not store persistent World ownership.
* update [reference.md](reference.md) with the validated current baseline and
  public access paths;
* update [roadmap.md](roadmap.md) so completed deentanglement work becomes
  baseline and remaining work is sequenced from the new architecture;
* rewrite [todo.md](todo.md) so the next implementation slice starts from the
  validated query / manager / rule boundaries;
* remove stale wording that still treats `worldManager.zig` as the concrete
  World implementation file.

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
* goals, reference, roadmap, and todo docs have been refreshed from the
  validated implementation.

Docs-only edits to this file do not require a build.
