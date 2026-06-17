# Enginer Design

This file will define the simulation used by `enginer` to validate engine
`World` features. The purpose and validation target belong in
[goals.md](goals.md). Implementation order can move into a future `roadmap.md`
when the design is ready to build.

## 1. Design Role

`enginer` needs a small coherent simulation, not a collection of unrelated
feature samples.

The design should exist to exercise engine-world systems in combination:
entities, components, relations, traits, events, archetypes, rules, scheduling,
queries, debug views, and effects.

## 2. Premise

TBD.

Choose a compact premise that naturally creates:

* persistent entities;
* temporary entities or effects;
* ownership, containment, or dependency relations;
* classified entities through traits;
* recurring rules;
* generated events;
* readable debug output.

## 3. Core Entities

TBD.

This section should list the main entity kinds the simulation owns and what
engine-world features each one is meant to exercise.

## 4. State Model

TBD.

Use this section for game-owned components, relations, traits, events, and
archetypes once the premise is chosen.

## 5. Simulation Loop

TBD.

Define the repeated state changes, scheduled work, rules, reactions, and event
flow that make the simulation run without manual intervention.

## 6. Inspection And Controls

TBD.

Define the overlay, debug views, logs, pause/step controls, and player/debug
inputs needed to validate behavior while the simulation runs.

## 7. Validation Scenarios

TBD.

Record concrete scenarios that prove engine-world features compose correctly.
Each scenario should state what is initialized, what changes over time, what is
observable, and what failure would look like.
