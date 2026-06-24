# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Define the first World-owned command execution boundary.

Rules can now enqueue commands through `RuleContext`, but commands remain
queued requested-change facts. This slice should decide and implement how
registered command payloads become deterministic World fact mutations without
adding scheduler cadence or automatic rule execution from `World.tick(...)`.

Keep the scope small enough to validate ownership:

* command handlers or executors are registered through World-owned surfaces;
* queued commands execute in deterministic order;
* successful commands apply exactly once;
* failed commands remain visible through return values, logs, events, or a
  documented failure queue;
* queue consumption/clearing ownership is explicit;
* rules still only request mutation by enqueueing commands.

## 2. Guardrails

* Use existing `CommandManager`, command queue, `World`, and `WorldManager`
  surfaces where possible.
* Keep command payloads as plain requested-change facts.
* Do not run commands automatically from `World.tick(...)` in this slice unless
  the command execution boundary itself cannot be validated explicitly.
* Do not add scheduler cadence, delayed events, temporary rules, or `RuleSet`.
* Do not add particle/effect, context, save/load, replay, undo, or retained
  history behavior.
* Do not change archetype behavior or let archetype spawning register command
  handlers.
* Keep game-specific command handlers under `src/games` unless a generic engine
  test handler is needed.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Define the command execution shape.
   * Choose the narrow command handler declaration surface.
   * Decide whether command execution lives in a focused manager or remains a
     narrow World-owned helper around `CommandManager`.
   * Keep the shape concrete; do not add type erasure, factories, or broad
     dispatch layers unless the compiler or ownership boundary requires it.

2. Add World-facing execution APIs.
   * Register handlers for command payload types.
   * Execute one command type or all registered command types explicitly.
   * Report handler failure visibly.
   * Document whether successful commands are popped before, during, or after
     execution.

3. Preserve rule/command separation.
   * Rules enqueue commands only.
   * Command handlers own the fact mutation phase.
   * Event emission from command handlers should use normal World APIs.

4. Add focused tests.
   * duplicate handler registration is rejected;
   * unregistered command execution is a visible no-op or failure;
   * queued commands execute once in order;
   * failed command handlers are visible and do not silently drop requests;
   * command execution can mutate components, relations, traits, or events
     through the documented World-owned path.

5. Refresh docs after implementation.
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
* game-defined cadences beyond the first base-tick phase;
* delayed events and temporary rules;
* `RuleSet` declarations and grouped rule registration;
* `src/engine/world/particles`, after refinement;
* `src/engine/world/context`, after refinement.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.
