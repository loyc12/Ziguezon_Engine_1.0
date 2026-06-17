# Engine World Rework Todo

This file is the active task loop for the next world-rework slice.
[reference.md](reference.md) describes the current baseline. [goals.md](goals.md)
describes the target state. [roadmap.md](roadmap.md) defines the broader
implementation order.

## 1. Current Slice

Build the first data-only `Archetype` surface.

The slice should let games define reusable bundles of initial World facts and
spawn them through `World` without hiding the resulting entity ids. This is a
data/fact feature, not a logic feature: archetype spawning may attach
components, relations, and traits, but it must not enqueue commands, register
rules, register RuleSets, or add scheduler behavior.

Keep the scope large enough to produce a usable pattern:

* one clear `Archetype` declaration shape;
* explicit World spawn helpers;
* component, relation, and trait initialization through existing typed APIs;
* useful spawn result data for games that need stable ids;
* focused tests and documentation refresh.

## 2. Guardrails

* Use `Archetype` as the engine-facing name. Do not introduce `Template` unless
  a separate non-archetype concept appears later.
* Keep archetypes data-only. Do not register executable logic from archetype
  spawning.
* Keep command enqueueing, rule registration, RuleSet registration, scheduler
  integration, and delayed work out of this slice.
* Do not add spawn-time event emission unless a concrete generic use case
  appears during implementation.
* Keep archetype definitions distinct from entity rows unless explicitly stored
  as facts later.
* Keep game-specific archetype payloads under `src/games`.
* Keep engine examples minimal and generic.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`.
* Do not add marker components for classification; use traits for dataless
  classification facts.
* Do not add storage policies or config bundles without a concrete use case.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Define the data-only archetype boundary.
   * Document declaration expectations in `archetypes/archetype.zig`.
   * Define the minimal `Archetype` fields needed for registration and spawn.
   * If a fully declarative typed fact list is too heavy for this slice, use a
     constrained spawn callback, but document it as initial fact attachment only.
   * Make the allowed spawn work explicit: create entities, attach components,
     add relations, and apply traits.

2. Add the spawn context and result types.
   * Provide a context that gives the archetype just enough access to attach
     initial facts through existing `World` APIs.
   * Provide a result shape that exposes the created root entity and any
     additional ids the archetype chooses to report.
   * Keep ownership and cleanup rules clear for ids allocated during a failed
     spawn.

3. Implement `ArchetypeManager` only as far as registration requires.
   * Support init/deinit and duplicate-name rejection.
   * Reject uninitialized registration and spawn operations cleanly.
   * Keep the manager dormant when no archetypes are registered.
   * Avoid game-specific archetype registries inside `engine/world`.

4. Add World-facing spawn helpers.
   * Route public spawning through `World` so games do not need manager internals.
   * Create entity ids explicitly through `World.createEntity()`.
   * Attach facts through existing `addComp`, `addRelation`, and `applyTrait`
     APIs.
   * Ensure failed fact attachment cannot be reported as a successful spawn.
   * If cleanup is implemented, destroy entities created during a failed spawn
     rather than leaving partially initialized rows.

5. Add one minimal generic example.
   * Keep it genre-agnostic.
   * Prefer existing generic facts such as `Persistent` or `LinkedTo`.
   * Avoid adding built-in content that belongs in `src/games`.

6. Add focused tests.
   * Registration rejects duplicate names and uninitialized use.
   * Spawning attaches initial components, relations, and traits.
   * Missing registered stores or trait/relation sets cause spawn failure.
   * Partial-spawn cleanup is covered if cleanup is implemented.
   * Command and event queues are not touched by archetype spawning.

7. Refresh docs after implementation.
   * Update `reference.md` with the live `Archetype` shape.
   * Trim `roadmap.md` so completed archetype work moves into the baseline.
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
* scheduler phases and rule cadence;
* delayed events and temporary rules;
* command execution ownership;
* `src/engine/world/particles`;
* `src/engine/world/context`;
* archetype query integration after the stored archetype shape exists;
* spawn-time events, only if a concrete generic use case appears.

Unrelated to this slice:

* `src/engine/world/entity.zig:22` compact lifecycle mask idea;
* `src/engine/world/components/baseComps.zig:77` LOD/minScale note;
* `src/engine/world/components/baseComps.zig:178` particle-system TODO.

## 6. Explicit Non-Goals

* no Template surface;
* no RuleSet implementation;
* no scheduler implementation;
* no command enqueueing from archetype spawning;
* no rule registration from archetype spawning;
* no particle/effect pools;
* no save/load, replay, undo, or retained command/event/spawn history;
* no retained UI state inside simulation `World`;
* no tilemap migration work in this `engine/world` slice.
