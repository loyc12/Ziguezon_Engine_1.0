# UI Implementation Brief

This is the implementation contract for the first retained-mode UI pass. It supplements `ui_roadmap.txt` and `todo.md`; keep broader design rationale in the roadmap and actionable task lists in the TODO.

## Scope

Build an MVP v0 retained-mode UI foundation large enough to prove the architecture and engine integration, but not a full final widget suite.

The v0 should include:

* engine-owned UI context / manager
* retained node storage
* stable node ids
* parent / child hierarchy
* dependency links for menu invalidation
* basic input capture
* basic layout
* basic screen-space rendering through existing draw primitives
* event buffer or equivalent game-facing action output
* `exampleGames/menuer/` sandbox demo

## Location

All new UI implementation files should live under src/utils/ui/


## Engine Integration Constraints

Minimize engine changes. Allowed engine edits are limited to what is needed to hook the UI system cleanly into the current loop.

Expected allowed areas:

* `src/core/ui/*` ( except `interfacer.zig` )
* `src/core/engine/engineCore.zig`
* `src/core/engine/engineStep.zig`
* `src/core/event/event.zig`
* `src/core/event/eventManager.zig`
* def.zig exports/imports needed to expose the UI manager through existing engine conventions

Ask before making major structural changes outside those areas.

The UI context should be treated like the existing managers / registries, not like a tiny global camera helper. Prefer an `Engine`-owned manager/context field.

## Style Constraints

Match the existing Zig codebase style and naming patterns.

These are intentionally different from standard zig, so do not run formatting passes such as `zig fmt`.

If the existing local style conflicts with a meaningful performance or correctness concern, pause and raise the issue before changing style broadly.

## Existing UI Code

The current UI code is an unused proof-of-concept and can be reworked freely.

Do not hook `interfacer.zig` into v0 rendering. Use simpler `sDraw`-based primitives first. `interfacer.zig` may be revisited later as a panel-shape renderer.

## Sandbox

Use exampleGames/menuer/ as the integration and behavior sandbox.

The sandbox should demonstrate:

* visible panel
* label
* button with click event
* checkbox / toggle
* submenu or popup
* independent spawned window that survives opener closure
* basic hover / focus / capture debug display

## Non-Goals For V0

Do not implement these unless needed to complete the proof-of-concept:

* text input
* clipboard
* gamepad navigation
* full keyboard navigation
* advanced theme files
* hot-reloadable panel definitions
* complex tables
* charts / graph widgets
* `interfacer.zig` bevel/shape integration

