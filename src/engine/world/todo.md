# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Define the first World-owned command execution boundary.

Rules can now enqueue commands through `RuleContext`, but commands remain
queued requested-change facts. This slice should first simplify `RuleContext`
to match the intended manager-pointer context shape, then implement how one
registered command payload type becomes deterministic World fact mutations
without adding scheduler cadence or automatic rule execution from
`World.tick(...)`.

Keep the scope small enough to validate ownership:

* rule and command contexts are simple manager-pointer bundles;
* command execution callbacks are registered when command queues are registered;
* queued commands of one command type execute in deterministic FIFO order;
* successful commands apply exactly once;
* attempted commands are popped before their callbacks run;
* failed command execution logs a warning and remains visible in result counts;
* queue consumption/clearing ownership is explicit;
* rules may run without enqueueing commands, but command emission remains the
  default path when a rule wants durable World mutations.

## 2. Guardrails

* Use existing `CommandManager`, command queue, `World`, and `WorldManager`
  surfaces where possible.
* Keep command payloads as plain requested-change facts.
* Keep `CommandContext` separate from `RuleContext`; do not broaden
  `RuleContext` for command execution.
* Do not include `CommandManager` in `CommandContext`; commands-calling-commands
  are deferred until proven useful.
* Do not run commands automatically from `World.tick(...)` in this slice unless
  the command execution boundary itself cannot be validated explicitly.
* Do not add scheduler cadence, delayed events, temporary rules, or `RuleSet`.
* Do not add particle/effect, archive, replay, undo, retry, pending-command, or
  retained history behavior.
* Do not change archetype behavior or let archetype spawning register command
  handlers.
* Keep game-specific command handlers under `src/games` unless a generic engine
  test handler is needed.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

0. Simplify `RuleContext`.
   * Remove duplicated helper APIs from `RuleContext`.
   * Keep only the active-entity map and relevant manager pointers.
   * Update rule code and tests to call manager functions directly through the
     context pointers.

1. Define the command execution shape.
   * Add a new `commands/commandContext.zig` file.
   * Keep `CommandContext` as a small manager-pointer bundle for mutation and
     event emission.
   * Do not include `CommandManager` in `CommandContext`.
   * Use the existing `CommandRecord(CommandType)` as the command instance
     passed to execution callbacks.
   * Define command execution callbacks as `bool` functions receiving
     `*CommandContext` and a command record.
   * Keep the shape concrete; do not add type erasure, factories, or broad
     dispatch layers unless the compiler or ownership boundary requires it.

2. Register execution callbacks with command queues.
   * Register a command execution function alongside the command type when the
     queue is generated in `CommandManager`.
   * Do not support replacing execution callbacks after command registration.
   * Report duplicate command registration as the existing duplicate queue
     registration failure.

3. Add execution APIs for one command type.
   * Add queue-level `execCommands(amount, context)`, where `amount == 0`
     means execute all commands currently queued for that type.
   * Add `CommandManager.execCommandType(CommandType, amount, context)`.
   * Add World/WorldManager forwarding surfaces for the same one-type execution.
   * Pop commands before callback execution.
   * Continue after callback failure.
   * Return an execution count/result struct with attempted, succeeded, and
     failed counts.
   * Log missing queues or missing execution callbacks as errors with false or
     failure results.
   * Log callback execution failures as warnings.

4. Preserve rule/command separation.
   * Rules are not required to enqueue commands.
   * Rules may inspect facts, validate invariants, emit suitable events/effect
     triggers, or request no work.
   * Rules should use commands as the default path for durable World mutation.
   * Command execution callbacks own the fact mutation phase.
   * Command callbacks may emit events for successful simulation outcomes.
   * Command callback failure itself should not emit simulation events.

5. Add focused tests.
   * `RuleContext` no longer duplicates manager helper APIs;
   * duplicate command registration remains rejected;
   * missing command queue or missing execution callback is visibly reported;
   * queued commands of one command type execute once in FIFO order;
   * `amount == 0` executes all commands initially queued for that type;
   * failed command callbacks are visible, popped, and do not stop later
     commands of the same type;
   * command execution can mutate components, relations, traits, or events
     through the documented World-owned path.

6. Refresh docs after implementation.
   * Update `reference.md` with the live command execution surface.
   * Trim `roadmap.md` so completed command execution becomes baseline.
   * Keep `goals.md` aligned with the validated command ownership model.
   * Replace this `todo.md` with the next minimal World tick phase slice after
     validation.

## 4. Validation

Run after code changes:

* `zig build`;
* `zig build test`.

Docs-only edits to this file do not require a build.

## 5. Deferred Work

Later roadmap slices:

* automatic rule and command phases from `World.tick(...)`;
* aggregate `execAllCommandTypes` behavior and cross-type ordering;
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
