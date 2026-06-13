# Documentation Guidelines

This project uses local Markdown files to keep long-lived design context close
to the code it describes. These files define the naming scheme and intended role
of reference, goals, roadmap, and todo documents.

## 1. Purpose

Use these docs to separate current facts, target design, implementation order,
and immediate tasks.

This is a reference for documentation tasks. It should not make agents infer
extra work beyond the user's current request.

## 2. File Types

### Reference

`reference.md` or `*_reference.md` records the descriptive system state for the
documented scope.

When it is the only doc in a scope, the reference describes the current system
as it exists now. It may also hold short, non-authoritative notes about
plausible future expansion avenues when no concrete work is planned.

When it is accompanied by goals, roadmap, or todo docs for a major rework, the
reference describes the baseline state before or at the start of that rework.
It should stay descriptive. Rework direction belongs in goals. Planned concrete
work belongs in roadmap or todo files.

### Goals

`goals.md` or `*_goals.md` describes the desired endpoint of major work. During
a rework, it is the top authority for target state and design direction.

Goals files are prescriptive and should stay relatively stable during the
rework. They may include:

* intended final features and architecture;
* reason for the rework;
* design philosophy;
* user preferences and hard constraints;
* non-negotiable boundaries;
* feature-centric uncertain or deferred work.

Use a goals file only for rework in a folder or subfolder. During an active
rework, goals, roadmap, and todo files should all exist, even when the roadmap is
short enough to fit in one todo slice.

### Roadmap

`roadmap.md` or `*_roadmap.md` is the high-level implementation guide from the
reference baseline toward the goals endpoint.

Roadmaps should be trimmed as work completes, but should always retain at least
the remaining work needed to reach the active goals file. Keep sequencing and
implementation-order details here rather than overloading the goals file.

Implementation-detail-centric uncertain or deferred work can live in the
roadmap when it is relevant to sequencing.

### Todo

`todo.md` or `*_todo.md` is the active task loop document.

Todos should contain precise, known, actionable future work. Vague, speculative,
or less certain notes should usually be folded into reference, goals, or roadmap
docs instead.

Todos are expected to change frequently while work is being prepared, executed,
or closed. Rework todos should reference the relevant goals and roadmap, and
mostly derive their task order from the roadmap.

## 3. Authority And Conflicts

For descriptive current-state or baseline conflicts, authority generally flows:

```text
reference > roadmap > todo
```

For rework target-state and design-direction conflicts, use:

```text
goals > roadmap > todo
```

Reference future-expansion notes are idea parking. They should not override
goals, roadmap, or todo direction.

Major conflicts should be surfaced to the user before overwriting anything. Do
not silently merge contradictory design direction, current implementation facts,
or ownership boundaries.

When code and docs disagree, inspect the current implementation before editing
docs. If the request is to refresh docs, update them to match the implementation
unless the user explicitly asks for a design proposal instead.

## 4. Naming And Placement

Documentation should live near the code it governs.

Use short names when the doc covers the whole folder:

```text
reference.md
goals.md
roadmap.md
todo.md
```

Use specific names when the doc covers one subsystem or topic inside a broader
folder:

```text
logger_reference.md
engine_rework_roadmap.md
ui_todo.md
```

When a concern crosses module boundaries, split by ownership directory first.
For example, utility UI primitive behavior belongs under `src/utils/ui`, while
engine UI orchestration belongs under `src/engine/ui`.

Engine-dependent utility polish should be documented on the engine side first.
Move it back to utility docs only if it proves to be engine-agnostic.

## 5. Major Rework Lifecycle

Major work should have the full rework doc set and usually follows this shape:

1. Reference describes the current baseline.
2. Goals define the desired endpoint and stable design constraints.
3. Roadmap defines high-level implementation order.
4. Todo defines the next precise task slice.
5. Todo is updated repeatedly as work progresses.
6. When goals are reached, the user asks an agent to fold the relevant outcome
   back into the reference.
7. Goals, roadmap, and todo are deleted or reworked depending on whether a new
   goal starts immediately.

Do not assume a goals, roadmap, or todo file should exist forever. These files
exist when preparing, doing, or closing major work.

## 6. Reference Style

Reference files should be useful later, not just a record of what changed.

Good reference sections include:

* purpose;
* current public shape;
* ownership and lifetime;
* data model;
* important behavior contracts;
* boundaries with adjacent systems;
* short, non-authoritative future expansion avenues;
* non-goals;
* validation notes when they are specific to the system.

Avoid long histories of completed work. If history matters, keep it to the
minimum needed to understand the current contract.

## 7. Roadmap Style

Roadmaps should describe implementation order, not every detail of the final
architecture.

Keep roadmaps:

* current with the implementation;
* focused on remaining work;
* explicit about sequencing dependencies;
* clear about deferred implementation-detail concerns;
* free of stale completed checklists unless a short baseline helps orientation.


## 8. Validation

Docs-only changes usually need no build.

Include validation commands inside a doc only when the system has specific
commands or checks that future agents are likely to miss. Otherwise rely on the
project's normal code-work validation habits and `AGENTS.md`.
