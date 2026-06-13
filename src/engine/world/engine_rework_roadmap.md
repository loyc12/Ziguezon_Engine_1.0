# Engine World Rework Roadmap

This file records implementation order from the current
[engine_rework_reference.md](engine_rework_reference.md) baseline toward the
target state in [engine_rework_goals.md](engine_rework_goals.md).

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
* typed transient event queues;
* event metadata with sequence, tick order, base tick, and primary entity;
* generic entity, component, and relation events;
* `World.tick(...)` event tick metadata.

The remaining work should build on those facts rather than re-plan them as
future phases.

## 2. Next - Reconcile Existing Fact Systems

Goal: harden the entity/component/relation/event baseline before adding another
major fact family.

Required work:

* audit World APIs against current tests and live game use;
* ensure relation cleanup and component cleanup semantics are documented and
  tested together through `World.destroyEntity()`;
* ensure generic event queues are registered where games or tests depend on
  emitted entity/component/relation events;
* decide whether transient event queues need a small retained-history option
  before rules/reactions consume events;
* keep `CompView` component-only until broad query semantics exist.

## 3. Next - Traits And Metaproperties

Goal: add the canonical classification path before marker components or
relation-shaped tags spread further.

Required work:

* define trait/metaproperty payload and dataless forms;
* add typed trait registration, application, removal, and querying;
* integrate trait cleanup with entity destruction;
* emit generic trait events when registered;
* provide at least one small generic example, such as `Selectable` or
  `Visible`;
* document when to choose component, relation, or trait.

## 4. Next - Broad Queries And Views

Goal: let systems, UI, and debug tools inspect stored facts without mutating
storage internals directly.

Required work:

* keep current `CompView` as the narrow component fast path;
* add query helpers only where there is a concrete system, game, or debug need;
* cover components, relations, events, and traits before touching archetypes or
  particles;
* avoid creating hidden fact ownership inside query/view helpers.

## 5. Later - Rules, Systems, And Commands

Goal: give games a clean path for executable simulation logic that observes
facts and requests changes.

Required work:

* define command records and queues separately from events;
* add minimal system registration/execution support;
* add a small rule/reaction layer after event and query semantics are stable;
* keep the first generic example small and game-agnostic;
* preserve explicit phase and event ordering.

## 6. Later - Archetypes And Templates

Goal: support reusable bundles of initial facts.

Required work:

* define archetype/template declarations;
* allow spawning component, relation, trait, and event initialization bundles;
* keep archetype definitions distinct from entity rows unless explicitly stored
  as facts;
* provide one minimal generic example.

## 7. Later - Scheduler

Goal: run World logical work inside engine-owned base ticks.

Required work:

* keep `EngineTiming` as the base-tick/frame-pacing authority;
* build scheduling inside `World.tick(...)`;
* support systems that run every base tick;
* support game-defined cadences;
* support delayed events and temporary rules;
* avoid a competing `shouldTick()` loop inside World.

## 8. Later - Particles And Effects

Goal: add first-class effect infrastructure driven by world facts.

Required work:

* define effect trigger records or commands;
* add particle/effect configs and deterministic seeds where needed;
* add packed transient particle pools;
* add render adapters that draw particles without exposing pool internals;
* migrate a concrete game proof only after generic events/rules/render pieces
  are stable.

## 9. Later - Context

Goal: reserve the context path for save/load/replay-facing world state.

Do not wire `engine/world/context` into runtime code until reusable
serialization/save-load primitives exist in `utils` and the base fact model is
stable enough to describe.

## 10. Implementation Constraints

* Keep target design in `engine_rework_goals.md`.
* Keep current facts in `engine_rework_reference.md`.
* Keep active task slices in `engine_rework_todo.md`.
* Keep engine-level examples minimal and generic.
* Keep game-specific facts under `src/games`.
* Prefer explicit ids, policies, and fact tables over hidden object graphs.
* Do not add marker-component support; use traits/metaproperties for
  classification.
* Do not run formatting passes such as `zig fmt`.
