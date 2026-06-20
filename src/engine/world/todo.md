# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Build the first minimal scheduler phase surface.

The slice should let `World.tick(...)` run registered logical work in an
explicit, deterministic phase without taking over engine timing. The scheduler
is a logic feature, not an entity/fact initialization feature: it may run rules
and later dispatch command execution, but it must not create archetypes,
register archetypes, emit spawn events, own game-specific systems, or implement
a competing base-tick loop.

Keep the scope small enough to validate the lifecycle:

* one clear scheduler declaration shape;
* deterministic registration and run order;
* explicit World-owned phase entry from `World.tick(...)`;
* read-only query plus command-manager access consistent with the current rule
  surface;
* focused tests and documentation refresh.

## 2. Guardrails

* Keep `EngineTiming` as the base-tick and frame-pacing authority.
* Run scheduler work from `World.tick(...)`; do not add a separate
  `shouldTick()` loop inside World.
* Keep the first scheduler pass minimal: one phase is enough unless existing
  code proves a second phase is needed.
* Use existing `Rule`, `RuleContext`, `RuleManager`, `WorldQuery`, and command
  queue APIs where possible.
* Do not implement `RuleSet` unless the minimal scheduler cannot be validated
  without it.
* Do not add delayed events, temporary rules, particles, effects, save/load,
  replay, undo, or retained history in this slice.
* Do not move UI state into simulation `World`.
* Keep game-specific scheduler content under `src/games`.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Define the scheduler boundary.
   * Document the first declaration shape in `scheduler/scheduler.zig`.
   * Decide whether the first surface stores rules directly or owns a
     `RuleManager` per phase.
   * Keep the allowed work explicit: query current facts, inspect events, and
     enqueue commands through existing rule APIs.
   * Keep command execution ownership deferred unless a tiny explicit phase is
     required for validation.

2. Add scheduler lifecycle.
   * Support init/deinit.
   * Reject uninitialized registration and run operations cleanly.
   * Reject duplicate names or phase entries if the chosen shape names them.
   * Keep the scheduler dormant when no work is registered.

3. Add World-owned scheduler wiring.
   * Add the scheduler manager to `World` init/deinit only after its standalone
     behavior is tested.
   * Route logical execution through `World.tick(...)`.
   * Preserve existing event and command tick metadata behavior.
   * Ensure scheduler work cannot run on an uninitialized World.

4. Add one minimal generic example.
   * Keep it genre-agnostic.
   * Prefer a rule that reads existing World facts and enqueues a test command.
   * Avoid built-in content that belongs in `src/games`.

5. Add focused tests.
   * Registration rejects duplicate names and uninitialized use.
   * Registered scheduler work runs in deterministic order.
   * `World.tick(...)` runs scheduler work once per consumed base tick.
   * Rules can inspect facts/events and enqueue commands through existing APIs.
   * Empty scheduler state adds no observable per-tick work.
   * Scheduler work does not mutate facts except through explicitly allowed
     command enqueueing.

6. Refresh docs after implementation.
   * Update `reference.md` with the live scheduler shape.
   * Trim `roadmap.md` so completed scheduler work moves into the baseline.
   * Replace this `todo.md` with the next active slice after validation.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Use targeted tests while developing, but the slice is not complete until the
world test surface compiles and the relevant tests pass.

Docs-only edits to this file do not require a build.

## 5. Deferred Work

Later roadmap slices:

* `RuleSet` declarations and grouped rule registration;
* game-defined cadences beyond the first base-tick phase;
* delayed events and temporary rules;
* command execution ownership beyond enqueueing;
* `src/engine/world/particles`;
* `src/engine/world/context`;
* archetype query integration after a concrete query use case appears;
* spawn-time events, only if a concrete generic use case appears.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.

## 6. Explicit Non-Goals

* no Template surface;
* no archetype behavior changes;
* no particle/effect pools;
* no save/load, replay, undo, or retained command/event/spawn history;
* no retained UI state inside simulation `World`;
* no tilemap migration work in this `engine/world` slice.
