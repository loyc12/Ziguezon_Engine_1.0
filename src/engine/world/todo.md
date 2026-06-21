# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Make the existing compact `RuleManager` World-owned.

The slice should let games register, inspect, and explicitly run ordered rules
through `World` without owning `RuleManager` directly. Rules remain named,
ordered logic declarations that read through `WorldQuery` and request changes by
enqueuing commands.

Keep the scope small enough to validate ownership:

* one `RuleManager` owned by `World`;
* World-facing rule registration and inspection helpers;
* one explicit World-facing rule run helper;
* existing read-only query and command emission behavior preserved;
* focused tests and documentation refresh.

## 2. Guardrails

* Use the existing `Rule`, `RuleContext`, `RuleManager`, `WorldQuery`, and
  command queue APIs where possible.
* Keep rules explicit, named, and ordered.
* Keep rule runs explicit in this slice; do not automatically run rules from
  `World.tick(...)` yet.
* Do not implement command execution ownership in this slice.
* Do not implement scheduler cadence, delayed events, temporary rules, or
  `RuleSet`.
* Do not add particle/effect, context, save/load, replay, undo, or retained
  history behavior.
* Do not change archetype behavior or let archetype spawning register rules.
* Keep game-specific rules under `src/games`.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Add rule manager ownership to `World`.
   * Import the rule surface into `worldManager.zig`.
   * Add a `RuleManager` field alongside the other fact managers.
   * Initialize and deinitialize it with the World-owned managers.
   * Keep an empty World rule manager dormant when no rules are registered.

2. Add World-facing rule APIs.
   * Add `registerRule`.
   * Add `hasRule`.
   * Add `getRuleCount`.
   * Add an explicit `runRules` helper that delegates to the owned manager.
   * Reject uninitialized World use cleanly.

3. Preserve rule behavior through World.
   * Rules must still read current facts through `WorldQuery`.
   * Rules must still peek or iterate events without consuming them.
   * Rules must still enqueue commands through the existing command manager.
   * Rule failure must be visible through the World-facing run helper.

4. Add focused tests.
   * World initializes and deinitializes its rule manager.
   * Registration rejects duplicate names and uninitialized use.
   * World-owned rules run in deterministic order.
   * Rules can inspect facts and enqueue commands through World-owned execution.
   * Rules can inspect events without consuming event queues.
   * Failed rules make `runRules` return failure and stop the run.

5. Refresh docs after implementation.
   * Update `reference.md` with the live World-owned rule surface.
   * Trim `roadmap.md` so completed rule-manager ownership moves into the
     baseline.
   * Replace this `todo.md` with the command execution ownership slice after
     validation.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Use targeted tests while developing, but the slice is not complete until the
world test surface compiles and the relevant tests pass.

Docs-only edits to this file do not require a build.

## 5. Deferred Work

Later roadmap slices:

* command handler or executor registration;
* deterministic command execution and queue consumption;
* automatic rule and command phases from `World.tick(...)`;
* game-defined cadences beyond the first base-tick phase;
* delayed events and temporary rules;
* `RuleSet` declarations and grouped rule registration;
* `src/engine/world/particles`, after refinement;
* `src/engine/world/context`, after refinement.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.

## 6. Explicit Non-Goals

* no automatic `World.tick(...)` rule phase;
* no command execution ownership;
* no scheduler cadence;
* no `RuleSet`;
* no archetype behavior changes;
* no particle/effect pools;
* no save/load, replay, undo, or retained command/event/spawn history;
* no retained UI state inside simulation `World`;
* no tilemap migration work in this `engine/world` slice.
