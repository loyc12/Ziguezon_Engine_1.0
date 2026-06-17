# Enginer Goals

This file records the broad target for `enginer`, the engine-world feature
testbed. Current engine-world facts belong in `src/engine/world/reference.md`.
Implementation order for engine-world internals belongs in
`src/engine/world/roadmap.md` and `src/engine/world/todo.md`.

## 1. Purpose

`enginer` should be the game-owned sandbox for engine `World` features, similar
to how `menuer` exercises retained UI features.

The testbed should make world features visible, copyable, and easy for agents
to extend without turning `src/engine/world` into a game-content directory.
It should prove engine-facing APIs through concrete game usage while keeping
examples small enough to remain readable.

## 2. Target Shape

`enginer` should eventually demonstrate the main world feature families:

* entity creation and lifecycle;
* component store registration and mutation;
* relation store registration and relation changes;
* trait/metaproperty use for dataless classification;
* event queues and event inspection;
* archetype spawning;
* rule and reaction execution;
* RuleSet registration when that surface exists;
* world tick scheduling and logical time;
* particle/effect records when that surface exists;
* world queries, debug views, and basic inspection overlays.

Each demo should be game-owned. Engine examples should stay minimal and generic;
`enginer` can hold richer combinations that show how those primitives are meant
to be assembled by a real game.

## 3. Agent Guidelines

Future agents should use `enginer` as an integration harness, not as a dumping
ground.

Prefer one focused demo slice per feature. Keep names explicit, keep data close
to the demo that owns it, and leave short comments where lifecycle, ownership,
or API expectations are not obvious.

When adding a demo:

* route through public engine/world APIs where possible;
* avoid reaching into manager internals unless the engine surface is missing;
* keep setup in lifecycle hooks, deterministic simulation in tick hooks, and
  inspection/rendering in render hooks;
* keep game-specific components, relations, traits, events, rules, archetypes,
  and views under `src/games/enginer`;
* update this file or a future local roadmap/todo when the direction changes.

## 4. Boundaries

`enginer` is allowed to be practical and slightly redundant if that makes engine
usage easier to inspect.

It should not:

* define engine API targets by itself;
* store broad engine-world design direction that belongs in
  `src/engine/world/goals.md`;
* hide engine behavior behind large game-specific abstractions;
* preserve stale demo code after the underlying engine feature changes;
* add compatibility wrappers unless they make active demos clearer.

## 5. Initial Success

The first usable version should compile as `zig build enginer`, open a small
world-feature sandbox, and expose enough visible/debug state that future agents
can add or validate one world feature at a time.

Near-term success means `enginer` can demonstrate the active engine-world todo
slice with game-owned data and clear validation behavior, then continue growing
as later world features land.
