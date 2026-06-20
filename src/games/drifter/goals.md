# Drifter Goals

This file records the purpose, constraints, and validation target for
`drifter`, the engine-world feature testbed.

The game design that makes the testbed run as a coherent simulation belongs in
[design.md](design.md). Current engine-world facts belong in
`src/engine/world/reference.md`. Implementation order for engine-world
internals belongs in `src/engine/world/roadmap.md` and
`src/engine/world/todo.md`.

## 1. Purpose

`drifter` should be the game-owned sandbox for engine `World` features,
similar to how `menuer` exercises retained UI features.

The testbed should make world features visible, copyable, and easy for agents
to extend without turning `src/engine/world` into a game-content directory.

It should prove engine-facing APIs through concrete game usage. That usage
should be a small but proper simulation, not a menu of unrelated API examples.

## 2. Simulation Requirement

`drifter` should validate world features through a coherent running simulation.
The simulation can be artificial, but it should have enough real state,
relationships, rules, events, and time progression to expose whether
engine-world APIs compose correctly.

Features should be added because the simulation needs them, then inspected and
validated through visible or logged debug state. Isolated fixtures are still
useful for development, but the long-term target is one integrated simulation
that exercises the world stack together.

`design.md` defines the fiction, entities, resources, systems, loops, and
debug/player interactions used to drive that simulation.

## 3. Validation Goals

`drifter` should eventually validate the main world feature families:

* stable entity lifecycles across setup, ticking, rendering, and cleanup;
* component store registration and mutation in live simulation state;
* relation store registration and relation changes between meaningful entities;
* trait/metaproperty use for dataless classification;
* event queues and event inspection;
* archetype spawning that creates meaningful initial state;
* rule and reaction execution that changes simulation behavior;
* RuleSet registration when that surface exists;
* world tick scheduling and logical time affecting behavior predictably;
* particle/effect records responding to world facts when that surface exists;
* world queries, debug views, and inspection overlays.

Each validation slice should be game-owned. Engine examples should stay minimal
and generic; `drifter` can hold richer combinations that show how those
primitives are meant to be assembled by a real game.

## 4. Documentation Split

* `goals.md` defines the purpose, constraints, and validation target for the
  testbed.
* `design.md` defines the simulation premise, entities, resources, rules,
  loops, and debug/player controls.
* Future `roadmap.md` should define implementation order from the current
  scaffold toward these goals.
* Future `todo.md` should define the active task slice.

## 5. Agent Guidelines

Future agents should use `drifter` as an integration harness, not as a dumping
ground.

Prefer one focused simulation slice per feature. Keep names explicit, keep data
close to the system that owns it, and leave short comments where lifecycle,
ownership, or API expectations are not obvious.

When adding a demo:

* route through public engine/world APIs where possible;
* avoid reaching into manager internals unless the engine surface is missing;
* keep setup in lifecycle hooks, deterministic simulation in tick hooks, and
  inspection/rendering in render hooks;
* keep game-specific components, relations, traits, events, rules, archetypes,
  and views under `src/games/drifter`;
* update `design.md` when the simulation premise or model changes;
* update this file only when the purpose, boundaries, or validation target
  changes.

## 6. Boundaries

`drifter` is allowed to be practical and slightly redundant if that makes engine
usage easier to inspect.

It should not:

* define engine API targets by itself;
* store broad engine-world design direction that belongs in
  `src/engine/world/goals.md`;
* hide engine behavior behind large game-specific abstractions;
* preserve stale demo code after the underlying engine feature changes;
* add compatibility wrappers unless they make active demos clearer.

## 7. Initial Success

The first usable version should compile as `zig build drifter`, open a small
world-feature simulation, and expose enough visible/debug state that future
agents can add or validate one world feature at a time.

Near-term success means `drifter` can demonstrate the active engine-world todo
slice with game-owned data and clear validation behavior, then continue growing
as later world features land.

Long-term success means `drifter` runs a coherent simulation whose entity,
component, relation, trait, event, rule, archetype, query, timing, and effect
usage can validate the engine-world stack as a composed system.
