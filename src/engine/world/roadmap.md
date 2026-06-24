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
* compact explicit rules with read-only `WorldQuery` access, deterministic
  ordering, command emission, and event/fact reaction support;
* read-only component, relation, event, and trait inspection through
  stateless `WorldQuery` helpers;
* data-only `Archetype` declarations, registration, World spawn helpers,
  initial component/relation/trait fact attachment, failed-spawn cleanup, and
  the generic `PersistentLinkArchetype` example.

Those pieces are reference-baseline facts. Future slices should build on them
instead of treating them as pending phases.

## 2. Current - Rule Cleanup And World-Owned Rule Manager

Goal: make the existing compact `RuleManager` a stable World-owned logic
surface now that query helpers are stateless and the concrete World lives in
`core/world.zig`.

Required work:

* add `RuleManager` ownership to `World` init/deinit with dormant cost when no
  rules are registered;
* expose World-facing rule registration, inspection, and run helpers so games do
  not need to own manager internals for ordinary simulation passes;
* preserve explicit, named, ordered rule declarations;
* preserve read-only `WorldQuery` access inside rules;
* preserve command emission as the main requested-change path;
* make rule failure behavior explicit and visible from the World-facing run
  helper;
* keep event/fact reaction rules deterministic;
* add focused tests for World-owned rules reading facts, reading events,
  preserving event queues, emitting commands, and reporting failure.

Exit criterion: games can register, inspect, and explicitly run ordered rules
through `World` without owning `RuleManager` directly. Rule cadence, grouped
registration, and command execution remain outside this slice.

Do not use `RuleSet` as a prerequisite for this slice. Plain rules should be
comfortable enough before grouped rule registration is introduced.

## 3. Next - Command Execution Ownership

Goal: define how queued commands become world fact changes.

Required work:

* define the command execution boundary and phase ownership;
* support explicit command handler or executor registration where needed;
* keep command execution deterministic and inspectable;
* report command failures through events, logs, or queued failure records rather
  than silently dropping requests;
* decide when command queues are consumed or cleared after execution;
* keep command payloads as plain requested-change facts;
* add tests proving commands apply once, in order, and fail visibly.

Exit criterion: queued commands can be executed through a documented
World-owned phase, successful commands are applied exactly once in deterministic
order, and failed commands produce visible failure information without leaving
queue ownership ambiguous.

This should happen before broad scheduler cadence work. A scheduler that runs
rules but leaves requested changes permanently game-local would not validate the
intended world pipeline.

## 4. Next - Minimal World Tick Phases

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
execute queued commands
finish tick bookkeeping
```

Exit criterion: each `World.tick(...)` call for one consumed game update runs
the metadata, rule, and command phases once in deterministic order, while render
frames and input updates do not trigger additional World simulation work.

Add more phases only when a concrete game or engine use case requires them.

## 5. Later - Scheduler Cadence And Delayed Work

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

## 6. Later - RuleSet

Goal: add reusable groups of executable rule declarations once plain rules and
tick phases are proven.

Required work:

* use `RuleSet` as the engine-facing name for grouped executable logic;
* keep `RuleSet` distinct from data-side archetypes;
* support grouped registration convenience for related rules;
* support group-level ordering or cadence only after minimal scheduler cadence
  exists;
* include one minimal generic example once the shape is stable.

## 7. Later - Particles And Effects

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

## 8. Later - Context

Goal: reserve the context path for save/load/replay-facing world state.

This area needs a refinement pass before implementation work or a todo slice is
generated from it.

Do not wire `engine/world/context` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 9. Implementation Constraints

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
* Do not add marker-component support; use traits/metaproperties for
  classification.
* Do not add storage policies or config bundles without a concrete use case.
* Do not run formatting passes such as `zig fmt`.
