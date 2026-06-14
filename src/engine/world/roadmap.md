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
* `World.tick(...)` event tick metadata;
* read-only component, relation, event, and trait inspection through
  `WorldQuery`.

Those pieces are reference-baseline facts. Future slices should build on them
instead of treating them as pending phases.

## 2. Current - Commands, Systems, And Rules

Goal: give games a clean path for executable simulation logic that observes
facts and requests changes.

This is the active slice in [todo.md](todo.md). It should:

* restore the current query/test baseline before adding new layers;
* define command records and typed transient command queues;
* provide the smallest useful command ownership surface;
* define compact system execution around read-only query access plus command
  emission;
* define a minimal rule/reaction boundary that can observe events and enqueue
  commands.

Do not add scheduler cadence, archetype spawning, particles/effects, save/load,
replay, retained command history, or UI state in this slice.

## 3. Later - Archetypes And Templates

Goal: support reusable bundles of initial facts.

Required work:

* define archetype/template declarations;
* allow spawning component, relation, trait, and event initialization bundles;
* add command, system, and rule integration only after those surfaces are stable;
* add archetype query integration only after the stored archetype shape exists;
* keep archetype definitions distinct from entity rows unless explicitly stored
  as facts;
* provide one minimal generic example.

## 4. Later - Scheduler

Goal: run World logical work inside engine-owned base ticks.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* build scheduling inside `World.tick(...)`;
* support command/system/rule execution inside explicit World phases;
* support systems that run every base tick;
* support game-defined cadences;
* support delayed events and temporary rules;
* avoid a competing `shouldTick()` loop inside World.

## 5. Later - Particles And Effects

Goal: add first-class effect infrastructure driven by world facts.

Required work:

* define effect trigger records or commands;
* add particle/effect configs and deterministic seeds where needed;
* add packed transient particle pools;
* add render adapters that draw particles without exposing pool internals;
* migrate a concrete game proof only after commands, events, rules, and render
  pieces are stable.

## 6. Later - Context

Goal: reserve the context path for save/load/replay-facing world state.

Do not wire `engine/world/context` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 7. Implementation Constraints

* Keep target design in `goals.md`.
* Keep current facts in `reference.md`.
* Keep active task slices in `todo.md`.
* Keep engine-level examples minimal and generic.
* Keep game-specific facts under `src/games`.
* Prefer explicit ids, policies, and fact tables over hidden object graphs.
* Do not add marker-component support; use traits/metaproperties for
  classification.
* Do not add storage policies or config bundles without a concrete use case.
* Do not run formatting passes such as `zig fmt`.
