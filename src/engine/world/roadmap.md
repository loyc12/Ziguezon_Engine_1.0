# Engine World Rework Roadmap

This file records remaining implementation order from the current
[reference.md](reference.md) baseline toward the target state in
[goals.md](goals.md). Completed work is summarized only as orientation; active
task details belong in [todo.md](todo.md).

## 1. Previously Implemented Baseline

The following foundations already exist and should not be re-planned as roadmap
tasks:

* entity identity, liveness, destruction, and fact cleanup;
* component stores, storage policies, component views, and component CRUD;
* relation stores, source/target indexes, cardinality policies, and dataless
  relation presence queries;
* trait sets for dataless classification facts, including `Persistent`;
* typed transient event queues, event metadata, and generic entity/component/
  relation/trait events;
* typed transient command queues, command metadata, one-type and aggregate
  command execution callbacks, `CommandContext`, explicit command-type
  registration order, and World/WorldManager command execution APIs;
* `World.tick(...)` event and command metadata, deterministic rule phase, and
  registration-order aggregate command phase;
* engine-owned `WorldManager` wrapping one active concrete `World`;
* concrete `World` implementation in `core/world.zig`;
* World-owned compact explicit rules with field-only manager-backed
  `RuleContext`, deterministic ordering, command emission, visible failure,
  and event/fact reaction support;
* read-only component, relation, event, and trait inspection through
  stateless `WorldQuery` helpers;
* data-only `Archetype` declarations, registration, World spawn helpers,
  initial component/relation/trait fact attachment, failed-spawn cleanup, and
  the generic `PersistentLinkArchetype` example.

Those pieces are reference-baseline facts. Future slices should build on them
instead of treating them as pending phases.

## 2. Current - First Scheduler Cadence

Goal: add the smallest reusable scheduler surface that can skip or run rule
work on deterministic base-tick intervals while keeping the validated
`World.tick(...)` phase order intact.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* keep `World.tick(...)` as the only world simulation entry point for consumed
  base ticks;
* introduce scheduler-owned cadence records without making archetypes,
  commands, or event queues register scheduled work implicitly;
* support a base-tick interval for registered rule work;
* run due scheduled rules before the aggregate command phase, preserving the
  existing command-after-rules ownership model;
* keep unscheduled registered rules running every base tick unless the slice
  explicitly replaces that behavior with an equivalent base-tick cadence;
* keep empty scheduler state at minimal per-tick cost;
* avoid delayed events, temporary rules, `RuleSet`, explicit command execution
  ordering, and recursive command execution in this slice.

Exit criterion: a rule can be registered with a deterministic base-tick cadence,
`World.tick(...)` evaluates whether that cadence is due exactly once per
consumed base tick, due rules can enqueue commands, and the existing aggregate
command phase executes those commands afterward.

## 3. Later - Delayed Work And Broader Cadence

Goal: extend the first scheduler cadence into broader time and delayed-work
behavior after the minimal rule cadence is proven.

Required work:

* support game-defined logical time scales;
* support delayed events;
* support temporary rules;
* support scheduled command execution only if the command phase proves it needs
  explicit delay semantics;
* keep cadence records dormant when no game registers scheduled work.

Do not use archetype spawning as a scheduler substitute. Archetypes are
data-only initial-fact bundles; scheduler work should consume existing rules,
events, commands, and World tick metadata directly.

## 4. Later - RuleSet

Goal: add reusable groups of executable rule declarations once plain rules and
tick phases are proven.

Required work:

* use `RuleSet` as the engine-facing name for grouped executable logic;
* keep `RuleSet` distinct from data-side archetypes;
* support grouped registration convenience for related rules;
* support group-level ordering or cadence only after minimal scheduler cadence
  exists;
* include one minimal generic example once the shape is stable.

## 5. Later - Particles And Effects

Goal: add first-class effect infrastructure driven by world facts.

This area needs a refinement pass before implementation work or a todo slice is
generated from it.

Required work:

* define effect trigger records or commands;
* add particle/effect configs and deterministic seeds where needed;
* add packed transient particle pools;
* add render adapters that draw particles without exposing pool internals;
* migrate a concrete game proof only after commands, events, rules, and render
  pieces are stable.

## 6. Later - Archive

Goal: define archive-facing world state for save/load/replay with names that do
not collide with short-lived rule and command callback contexts.

This area needs a refinement pass before implementation work or a todo slice is
generated from it.

Do not wire `engine/world/archive` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 7. Implementation Constraints

* Keep target design in `goals.md`.
* Keep current facts in `reference.md`.
* Keep active task slices in `todo.md`.
* Keep engine-level examples minimal and generic.
* Keep game-specific facts under `src/games`.
* Prefer explicit ids, policies, and fact tables over hidden object graphs.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`:
  unused systems may have small init/deinit costs, but should not add meaningful
  per-tick work during standard runtime.
* Keep archetypes data-only; do not add command enqueueing, rule registration,
  RuleSet registration, or scheduler behavior to archetype spawning.
* Keep rules from becoming hidden mutable systems; ordinary fact changes should
  flow through explicit command execution or another documented phase boundary.
* Keep short-lived rule and command contexts as simple manager-pointer bundles
  unless a helper removes real ambiguity.
* Do not add marker-component support; use traits/metaproperties for
  classification.
* Do not add storage policies or config bundles without a concrete use case.
* Do not run formatting passes such as `zig fmt`.
