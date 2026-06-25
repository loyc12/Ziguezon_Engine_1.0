# Menuer UI Testbed Goals

This file describes the desired endpoint for turning `src/games/menuer` into a
dual-path UI testbed. Current baseline facts belong in [reference.md](reference.md).
Implementation order belongs in [roadmap.md](roadmap.md).

## 1. Purpose

`menuer` should fully feature both supported UI usage paths:

* direct utility UI through game-owned `utl.Panel` values;
* engine-managed UI through game-owned panels registered with `ng.uiManager`.

The sandbox should make both paths easy to compare while staying small enough
to remain a practical regression surface for future UI work.

## 2. Toggle Requirement

The selected implementation path should be controlled by one simple runtime
boolean flag.

The flag should be easy to find near the top of the sandbox implementation and
should choose which implementation path builds, updates, handles events, and
draws the primary test surface.

The flag toggles the active UI type. The selected path should be obvious from
the on-screen debug state. The inactive path should not receive input, draw its
primary surface, or emit events while inactive.

## 3. Feature Parity Target

The utility and engine-managed paths should demonstrate the full extent of their
implemented abilities with as few examples as practical.

Overlapping behavior should share form factor when that makes comparison easier
and does not hide either system's capabilities. Divergent examples are allowed
when one path needs a different shape to demonstrate behavior the other path
does not have.

Target shared coverage:

* panel creation and teardown;
* labels, buttons, checkboxes, spacers, and containers;
* column, row, absolute, and stack layout if stack remains supported by the
  primitive API;
* local or forwarded clicked and changed events;
* text mutation and formatted text mutation;
* checked-state query and mutation;
* visible/enabled state mutation;
* panel or widget movement through supported geometry APIs;
* style mutation where it is already supported by primitives;
* hover, pressed/captured, event-count, final-box, and text-metric readouts;
* mouse-consumption behavior that prevents camera wheel zoom;
* clear teardown/rebuild behavior without stale handles or queued stale events.

## 4. Engine-Specific Coverage

The engine-managed path should keep proving engine UI manager behavior that a
direct utility panel cannot prove:

* registration metadata and generation-checked handles;
* layer, z, and registration-order routing;
* front-to-back input routing;
* back-to-front draw routing;
* per-button capture;
* visible/input/draw flag independence;
* manager-local event forwarding;
* unregister and re-register behavior;
* stale-handle rejection after unregister, slot reuse, and manager clear;
* manager-level `wantsMouse()` behavior.

## 5. Utility-Specific Coverage

The direct utility path should keep proving primitive usage without depending
on engine orchestration:

* direct `Panel.updateInput()`;
* direct `Panel.popEvent()`;
* direct `Panel.wantsMouse()`;
* direct `Panel.draw()`;
* handle-based mutation and introspection;
* panel-local ownership and deinitialization.

## 6. Debug Surface

The sandbox should keep a compact debug area that reports the selected path and
the relevant state for that path. The debug surface should remain direct utility
UI and always active by default, or be controlled by a separate debug flag.

If the utility and engine paths need incompatible debug inputs, use separate
debug panel instances rather than making one panel depend on two unrelated
sources of truth.

Debug readouts should help validate behavior without becoming a separate UI
framework. Useful readouts include:

* active path;
* hovered panel and widget;
* pressed or captured widget;
* event counts;
* selected route/input/draw flags;
* panel handle generation data when the engine path is active;
* draw order when the engine path is active;
* mouse-consumption state.

## 7. Boundaries

Do not use `menuer` to add unsupported UI concepts ahead of their design pass.

Out of scope until explicitly designed in `src/utils/ui` or `src/engine/ui`:

* keyboard focus;
* text input;
* keyboard/gamepad navigation;
* modal blocking;
* close policy;
* persistent windows, popups, and tooltips;
* docking;
* hot reload;
* theme files;
* global engine event integration.

Do not broaden the rework into ownership transfer, type erasure, generic
factories, or a compatibility layer unless the chosen roadmap proves a concrete
need and the user approves the boundary change.

When the code needs extension hooks for deferred UI behavior, prefer clear
`TODO` notes near the relevant implementation point. Do not show unimplemented
features in the visible sandbox.

## 8. Success Condition

`menuer` can be switched between direct utility and engine-managed UI with one
boolean flag, both paths demonstrate the same core primitive feature set, and
the engine path additionally proves manager-specific routing, handles, flags,
events, and stale-handle behavior.

Future UI tweaks should be able to use the sandbox to answer whether a change
belongs in `src/utils/ui`, `src/engine/ui`, or game-side integration code.
