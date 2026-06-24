# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Define the first minimal scheduler cadence surface for rule work.

`World.tick(...)` now runs the validated base-tick pipeline:

```text
begin event and command tick metadata
run registered rules once in deterministic rule order
execute registered command types once in registration order
```

This slice should add the smallest scheduler-owned cadence layer that can run
rule work on deterministic base-tick intervals without changing the command
phase, adding delayed work, or introducing `RuleSet`.

Keep the scope small enough to validate cadence ownership:

* `EngineTiming` remains the base-tick/frame-pacing authority;
* `World.tick(...)` remains the only World simulation entry point;
* scheduler cadence is evaluated once per consumed base tick;
* scheduled rules run before aggregate command execution;
* due scheduled rules may enqueue commands;
* aggregate command execution still runs after rules request changes;
* empty scheduler state has minimal runtime cost;
* the implementation does not introduce a competing `shouldTick()` loop inside
  World.

## 2. Guardrails

* Preserve the existing `World.tick(...)` phase order.
* Use the existing `scheduler` folder only if it can stay direct and compact.
* Do not add delayed events, temporary rules, `RuleSet`, particles/effects,
  archive, replay, undo, retry, pending-command, or retained history behavior.
* Do not add explicit command execution ordering yet.
* Do not make archetype spawning register rules, command handlers, scheduler
  work, or other executable behavior.
* Do not introduce broad type erasure, factories, dependency-injection layers,
  or generic dispatch surfaces unless the compiler or ownership boundary proves
  they are required.
* If cadence scheduling exposes a real ownership or compiler blocker, stop and
  report the exact issue before widening the design.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

0. Reconfirm the current tick baseline.
   * Verify `World.tick(...)` still begins event and command metadata.
   * Verify registered rules still run before aggregate commands.
   * Verify aggregate commands still drain in command-type registration order.

1. Define the minimal cadence shape.
   * Add a scheduler-owned record for rule cadence.
   * Use base-tick interval cadence only for this slice.
   * Treat interval `1` as every consumed base tick.
   * Reject or visibly fail invalid interval `0`.
   * Keep game-defined time scales for later work.

2. Wire scheduled rule execution.
   * `World.tick(...)` should evaluate scheduler cadence once.
   * Due scheduled rules should run before aggregate command execution.
   * Rules that are not moved into scheduled cadence should keep their current
     every-base-tick behavior unless the implementation replaces them with an
     equivalent interval-1 schedule.
   * Rule callbacks should still receive short-lived field-only `RuleContext`.
   * Rule failure should remain visible.

3. Preserve command ownership.
   * Commands emitted by due scheduled rules should execute in the existing
     aggregate command phase.
   * Command callbacks should still receive short-lived `CommandContext`.
   * Command callback failure should remain visible and should not emit failure
     events by itself.
   * Queued command records without callbacks should still be logged, counted as
     failed work, and discarded during the failed drain.

4. Add focused tests.
   * interval-1 scheduled rules run every `World.tick(...)`;
   * interval-N scheduled rules run only on due base ticks;
   * invalid interval `0` is rejected or visibly fails without hidden behavior;
   * due scheduled rules run before aggregate command execution;
   * commands emitted by scheduled rules execute after the rule phase;
   * empty scheduler state does not require registered work;
   * existing unscheduled rule behavior remains valid or is intentionally
     replaced by equivalent interval-1 behavior.

5. Refresh docs after implementation.
   * Update `reference.md` with the live scheduler cadence surface.
   * Trim `roadmap.md` so first scheduler cadence becomes baseline.
   * Keep `goals.md` aligned with the validated cadence ownership model.
   * Replace this `todo.md` with the next roadmap slice only after validation
     and only if the roadmap defines it clearly.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Docs-only edits to this file do not require a build.

## 5. Deferred Work

Later roadmap slices:

* game-defined logical time scales;
* delayed events and temporary rules;
* explicit command execution ordering at command registration or instantiation,
  replacing plain registration order only when a concrete use case needs it;
* recursive commands-calling-commands behavior;
* `RuleSet` declarations and grouped rule registration;
* `src/engine/world/particles`, after refinement;
* `src/engine/world/archive`, after refinement.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.
