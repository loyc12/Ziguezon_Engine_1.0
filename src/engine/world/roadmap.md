# Engine World Rework Roadmap

This file records implementation order from the current
[reference.md](reference.md) baseline toward the target state in
[goals.md](goals.md).

## 1. Current Starting Point

The world rework has already landed:

* active entity tracking;
* entity destruction with fact cleanup;
* packed and sparse component stores;
* explicit component storage policy declarations;
* component add/get/has/remove APIs;
* component views with generation invalidation;
* relation stores with source/target indexes;
* relation cardinality policies;
* dataless relation facts queried by presence;
* trait sets for dataless classification facts;
* trait registration, apply/remove, presence query, and destruction cleanup;
* typed transient event queues;
* event metadata with sequence, tick order, base tick, and primary entity;
* generic entity, component, relation, and trait events;
* `Persistent` as the first generic trait example;
* `World.tick(...)` event tick metadata;
* read-only component, relation, event, and trait inspection helpers;
* `WorldQuery` as the current transient read-only query facade.

The remaining work should build on those facts rather than re-plan them as
future phases.

## 2. Next - Rules, Systems, And Commands

Goal: give games a clean path for executable simulation logic that observes
facts and requests changes.

Required work:

* define command records and queues separately from events;
* add minimal system registration/execution support;
* add a small rule/reaction layer after event and query semantics are stable;
* keep the first generic example small and game-agnostic;
* preserve explicit phase and event ordering.

## 3. Later - Archetypes And Templates

Goal: support reusable bundles of initial facts.

Required work:

* define archetype/template declarations;
* allow spawning component, relation, trait, and event initialization bundles;
* add archetype query integration only after the stored archetype shape exists;
* keep archetype definitions distinct from entity rows unless explicitly stored
  as facts;
* provide one minimal generic example.

## 4. Later - Scheduler

Goal: run World logical work inside engine-owned base ticks.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* build scheduling inside `World.tick(...)`;
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
* migrate a concrete game proof only after generic events/rules/render pieces
  are stable.

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
