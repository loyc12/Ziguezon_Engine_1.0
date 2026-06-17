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
* compact explicit rules with read-only `WorldQuery` access, deterministic
  ordering, command emission, and event/fact reaction support;
* read-only component, relation, event, and trait inspection through
  `WorldQuery`.

Those pieces are reference-baseline facts. Future slices should build on them
instead of treating them as pending phases.

## 2. Current - Archetypes

Goal: support reusable data-only bundles of initial facts.

Required work:

* define `Archetype` declarations;
* allow spawning component, relation, and trait initialization bundles;
* add spawn-time event records only if a generic use case is clear;
* keep command enqueueing, rule registration, and `RuleSet` integration out of
  the archetype spawn path until those use cases are concrete;
* add archetype query integration only after the stored archetype shape exists;
* keep archetype definitions distinct from entity rows unless explicitly stored
  as facts;
* provide one minimal generic example.

Use `RuleSet` later for reusable groups of executable rules. Do not use
`Template` as the engine-facing name for this world surface unless a separate
non-archetype concept appears.

## 3. Later - Scheduler

Goal: run World logical work inside engine-owned base ticks.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* build scheduling inside `World.tick(...)`;
* support command/rule execution inside explicit World phases;
* support rules that run every base tick;
* support `RuleSet` registration as a grouping convenience once rule cadence
  needs are clearer;
* support game-defined cadences;
* support delayed events and temporary rules;
* avoid a competing `shouldTick()` loop inside World.

## 4. Later - Particles And Effects

Goal: add first-class effect infrastructure driven by world facts.

Required work:

* define effect trigger records or commands;
* add particle/effect configs and deterministic seeds where needed;
* add packed transient particle pools;
* add render adapters that draw particles without exposing pool internals;
* migrate a concrete game proof only after commands, events, rules, and render
  pieces are stable.

## 5. Later - Context

Goal: reserve the context path for save/load/replay-facing world state.

Do not wire `engine/world/context` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 6. Implementation Constraints

* Keep target design in `goals.md`.
* Keep current facts in `reference.md`.
* Keep active task slices in `todo.md`.
* Keep engine-level examples minimal and generic.
* Keep game-specific facts under `src/games`.
* Prefer explicit ids, policies, and fact tables over hidden object graphs.
* Preserve the no-registration, minimal-runtime-cost rule from `goals.md`:
  unused systems may have small init/deinit costs, but should not add meaningful
  per-tick work during standard runtime.
* Do not add marker-component support; use traits/metaproperties for
  classification.
* Do not add storage policies or config bundles without a concrete use case.
* Do not run formatting passes such as `zig fmt`.
