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
* typed transient command queues, command metadata, and World command APIs;
* `World.tick(...)` event tick metadata;
* engine-owned `WorldManager` wrapping one active concrete `World`;
* concrete `World` implementation in `core/world.zig`;
* World-owned compact explicit rules with manager-backed `RuleContext`,
  deterministic ordering, command emission, visible failure, and event/fact
  reaction support;
* read-only component, relation, event, and trait inspection through
  stateless `WorldQuery` helpers;
* data-only `Archetype` declarations, registration, World spawn helpers,
  initial component/relation/trait fact attachment, failed-spawn cleanup, and
  the generic `PersistentLinkArchetype` example.

Those pieces are reference-baseline facts. Future slices should build on them
instead of treating them as pending phases.

## 2. Current - Command Execution Ownership

Goal: define how queued commands become world fact changes.

Required work:

* simplify `RuleContext` into a small manager-pointer bundle before adding
  `CommandContext`;
* define a command execution boundary owned by command infrastructure and
  surfaced through World/WorldManager APIs;
* add a narrow `CommandContext` that mirrors the manager-pointer context shape
  without borrowing `RuleContext`;
* register one command execution callback alongside each command queue when the
  command type is registered;
* execute all currently queued commands for one command type through
  `CommandManager`;
* keep command execution deterministic and inspectable;
* pop attempted commands before callback execution;
* report missing queues or missing callbacks as developer-facing errors with
  false/failure results;
* report callback failures with warnings and execution counts, then continue
  through later queued commands of the same type;
* keep command payloads as plain requested-change facts;
* add tests proving commands apply once, in order, and fail visibly.

Exit criterion: queued commands can be executed through a documented
World-owned phase, successful commands are applied exactly once in deterministic
order for one command type, and failed attempts produce visible failure
information without leaving queue ownership ambiguous.

This should happen before broad scheduler cadence work. A scheduler that runs
rules but leaves requested changes permanently game-local would not validate the
intended world pipeline.

Defer aggregate all-command-type execution, cross-type ordering, recursive
commands-calling-commands, retry/pending command semantics, delayed commands,
and handler replacement after registration until a later design pass.

## 3. Next - Minimal World Tick Phases

Goal: run the first deterministic world simulation pipeline once per game
update inside engine-owned base ticks.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* keep `World.tick(...)` as the World-owned entry point for consumed game
  updates;
* make clear that `World.tick(...)` is run once per consumed game update/base
  tick, not during frame rendering or input polling;
* preserve current event and command tick metadata setup;
* run registered base-tick rules in a deterministic phase;
* execute queued commands in an explicit deterministic phase;
* keep an empty scheduler/rule/command state at minimal runtime cost;
* avoid a competing `shouldTick()` loop inside World.

The first pipeline can be intentionally small:

```text
begin tick metadata
run registered base-tick rules
execute the validated command phase
finish tick bookkeeping
```

Exit criterion: each `World.tick(...)` call for one consumed game update runs
the metadata, rule, and command phases once in deterministic order, while render
frames and input updates do not trigger additional World simulation work.

Add more phases only when a concrete game or engine use case requires them.

## 4. Later - Scheduler Cadence And Delayed Work

Goal: extend the minimal tick pipeline into reusable scheduling.

Required work:

* support rules that run at slower or faster logical cadences;
* support game-defined logical time scales;
* support delayed events;
* support temporary rules;
* support scheduled command execution only if the command phase proves it needs
  explicit delay semantics;
* keep cadence records dormant when no game registers scheduled work.

Do not use archetype spawning as a scheduler substitute. Archetypes are
data-only initial-fact bundles; scheduler work should consume existing rules,
events, commands, and World tick metadata directly.

## 5. Later - RuleSet

Goal: add reusable groups of executable rule declarations once plain rules and
tick phases are proven.

Required work:

* use `RuleSet` as the engine-facing name for grouped executable logic;
* keep `RuleSet` distinct from data-side archetypes;
* support grouped registration convenience for related rules;
* support group-level ordering or cadence only after minimal scheduler cadence
  exists;
* include one minimal generic example once the shape is stable.

## 6. Later - Particles And Effects

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

## 7. Later - Archive

Goal: define archive-facing world state for save/load/replay with names that do
not collide with short-lived rule and command callback contexts.

This area needs a refinement pass before implementation work or a todo slice is
generated from it.

Do not wire `engine/world/archive` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 8. Implementation Constraints

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
