# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Collapse the separate system surface into the rule surface.

The current `systems` and `rules` implementations are mechanically almost the
same: ordered callbacks receive read-only `WorldQuery` access and enqueue
commands. Keep the preferred name `Rule`, and make rules the single executable
simulation-logic primitive for both:

* broad simulation passes that inspect current facts;
* event/fact reactions that enqueue follow-up commands.

This slice should remove duplicated system/rule code before archetypes,
scheduler phases, particles, or save/load build on top of the wrong boundary.

## 2. Guardrails

* Prefer the name `Rule` over `System` for the unified executable logic surface.
* Treat “system” as descriptive language only if needed, not as an engine-owned
  public API type.
* Do not keep compatibility aliases unless a live caller needs them.
* Keep rules read-only with respect to broad `WorldQuery` traversal.
* Rules should continue to emit requested changes through commands.
* Preserve event queue semantics: peeking and iteration must not pop records.
* Do not add scheduler cadence, rule phases, temporary rules, delayed events,
  delayed commands, replay, undo, or retained history in this slice.
* Keep game-specific rule lists under `src/games`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Define the unified rule boundary.
   * Update `rules/rule.zig` docs so `Rule` covers broad passes and reactions.
   * Keep `RuleContext` as read-only `WorldQuery` plus command emission.
   * Make the default interpretation simple: a rule is an explicit callback run
     by a caller, not a scheduler-owned job.
   * Preserve the existing `order` field as the deterministic ordering hook.
   * Do not add `RuleKind`, phases, cadence, or event filters in this merge.

2. Move useful system behavior into rules.
   * Preserve ordered registration and explicit `runAll(world)` behavior.
   * Preserve duplicate-name and uninitialized-use rejection.
   * Preserve tests that demonstrate broad fact inspection plus command
     emission.
   * Preserve tests that demonstrate event observation without consuming events.

3. Remove the duplicated system subsystem.
   * Delete or empty `src/engine/world/systems/system.zig` and
     `src/engine/world/systems/systemManager.zig` if no live caller remains.
   * Remove `System`, `SystemContext`, `SystemFn`, and `SystemManager` exports
     from `src/engine/engineDef.zig`.
   * Remove system-specific wording from tests, docs, and comments unless it is
     intentionally descriptive.
   * Check `src/games` and engine code for live system API references before
     deleting public exports.

4. Keep command integration unchanged.
   * Rules should still enqueue commands, not directly mutate broad query
     results.
   * Command queues should remain typed, transient, ordered, and manually
     drained.
   * `World.tick(...)` should keep command/event metadata behavior unchanged
     unless a direct conflict appears.

5. Refresh docs after implementation.
   * Update `reference.md` so rules are the sole executable logic primitive.
   * Trim `roadmap.md` so it no longer plans for separate command/system/rule
     execution.
   * Move archetypes/templates back to the next active slice after validation.
   * Replace this `todo.md` with the archetype/template slice once the merge is
     complete.

6. Add focused tests.
   * Unified rule tests should cover current-fact inspection plus command
     emission.
   * Unified rule tests should cover queued event observation without popping.
   * Removal tests should ensure no `SystemManager` declarations are still
     exported through `engineDef.zig`.
   * Existing command queue and World command API tests should continue to pass.

## 4. Design Decisions

The following decisions guide the merge:

* Keep the unified manager name as `RuleManager`.
* Delete `src/engine/world/systems/` after useful behavior and tests are moved
  into `rules`.
* Rules own deterministic ordering now through the existing `order` field.
* Rules may eventually own cadence metadata, but cadence shape should be decided
  during the scheduler slice. Do not add cadence enum values, tick intervals, or
  phase tags during this merge.

## 5. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Use targeted tests while developing, but the slice is not complete until the
world test surface compiles and the relevant tests pass.

## 6. Deferred Work

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

## 7. Explicit Non-Goals

* no archetype/template spawning;
* no scheduler implementation;
* no particle/effect pools;
* no save/load, replay, undo, or retained command/event/rule history;
* no retained UI state inside simulation `World`;
* no tilemap migration work in this `engine/world` slice.
