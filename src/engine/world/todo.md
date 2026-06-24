# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Define the first minimal `World.tick(...)` simulation phase pipeline.

`World.tick(...)` currently begins event and command tick metadata only. Rules
can run through explicit `applyRules()`, and one command type can be drained
through explicit `execCommandType(...)`. This slice should wire the first
deterministic base-tick pipeline inside `World.tick(...)` without adding broad
scheduler cadence, delayed work, temporary rules, explicit command execution
ordering, or `RuleSet`.

The intentionally small pipeline is:

```text
begin tick metadata
run registered base-tick rules
execute registered command types in registration order
finish tick bookkeeping
```

Keep the scope small enough to validate tick ownership:

* `EngineTiming` remains the base-tick/frame-pacing authority;
* `World.tick(...)` runs once per consumed engine base tick;
* render frames and input polling do not trigger extra World simulation work;
* registered rules run in deterministic order during the rule phase;
* command execution runs after rules request changes;
* empty rule/command state has minimal runtime cost;
* the implementation does not introduce a competing `shouldTick()` loop inside
  World.

## 2. Guardrails

* Use the existing `World.tick(...)`, `RuleManager`, `CommandManager`,
  command queue, `World`, and `WorldManager` surfaces where possible.
* Preserve current event and command metadata setup.
* Do not add scheduler cadence, delayed events, temporary rules, or `RuleSet`.
* Do not add explicit command execution ordering yet. Aggregate command
  execution should use command-type registration order for this slice.
* Do not add particles/effects, archive, replay, undo, retry, pending-command,
  or retained history behavior.
* Do not change archetype behavior or let archetype spawning register rules,
  command handlers, or scheduler work.
* Do not introduce broad type erasure, factories, dependency-injection layers,
  or generic dispatch surfaces unless the compiler or ownership boundary proves
  they are required.
* If registration-order aggregate command execution exposes a real ownership or
  compiler blocker, stop and report the exact issue before widening the design.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

0. Reconfirm the tick call path.
   * Verify `engineStep.tickWorld()` still calls `ng.world.tick(tickContext)`
     once per consumed base tick.
   * Verify render and input paths do not call `World.tick(...)` directly.

1. Define the minimal tick phase shape.
   * Keep `World.tick(...)` as the single entry point.
   * Keep event and command metadata setup at the start of the tick.
   * Add explicit rule phase execution after metadata setup.
   * Add aggregate command execution after the rule phase.
   * Use command-type registration order as the deterministic aggregate
     execution order.
   * Keep explicit command execution ordering as later work.

2. Preserve explicit rule and command ownership.
   * `RuleManager` still owns registered rule ordering.
   * Rules still receive a short-lived field-only `RuleContext`.
   * Command callbacks still receive a short-lived `CommandContext`.
   * Rules may emit no commands.
   * Command callbacks own durable fact mutation.
   * Command callback failure remains visible and does not emit failure events
     by itself.

3. Add registration-order aggregate command execution.
   * Add `CommandManager.execAllCommands(context)`.
   * Add `World.execAllCommands()`.
   * Add `WorldManager.execAllCommands()`.
   * Keep `execCommandType(CommandType, amount)` as the typed partial-drain API.
   * Track command-type registration order explicitly; do not rely on hash-map
     iteration order.
   * Drain all queued commands present for each registered command type in
     registration order.
   * Queue-only command types with no queued records should not fail an empty
     tick.
   * Queue-only command types with queued records and no execution callback
     should produce a visible failure result.
   * Aggregate failures should not prevent later registered command types from
     running during the same aggregate command phase.

4. Wire the base-tick pipeline.
   * `World.tick(...)` should begin event and command metadata.
   * `World.tick(...)` should run registered rules once.
   * `World.tick(...)` should execute aggregate commands once after rules.
   * Empty rule/command state should keep minimal runtime cost.

5. Add focused tests.
   * `World.tick(...)` begins event and command metadata once per call;
   * registered rules run during `World.tick(...)` in deterministic order;
   * commands emitted by tick-run rules execute after the rule phase;
   * aggregate command execution uses command-type registration order;
   * empty queue-only command types do not fail an empty tick;
   * queued command records without an execution callback produce visible
     aggregate failures;
   * command execution failures remain visible and do not stop later work that
     belongs to the validated command phase;
   * empty rule/command state does not require registered work;
   * explicit manual `applyRules()` behavior remains valid if it is kept.

6. Refresh docs after implementation.
   * Update `reference.md` with the live tick phase surface.
   * Trim `roadmap.md` so minimal tick phases become baseline.
   * Keep `goals.md` aligned with the validated tick ownership model.
   * Replace this `todo.md` with the next minimal scheduler-cadence slice only
     after validation and only if the roadmap still defines it clearly.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Docs-only edits to this file do not require a build.

## 5. Deferred Work

Later roadmap slices:

* explicit command execution ordering at command registration or instantiation,
  replacing plain registration order only when a concrete use case needs it;
* recursive commands-calling-commands behavior;
* game-defined cadences beyond the first base-tick phase;
* delayed events and temporary rules;
* `RuleSet` declarations and grouped rule registration;
* `src/engine/world/particles`, after refinement;
* `src/engine/world/archive`, after refinement.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.
