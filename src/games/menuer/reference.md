# Menuer UI Testbed Reference

This file describes the current `src/games/menuer` UI sandbox baseline.
Desired rework direction belongs in [goals.md](goals.md). Implementation order
belongs in [roadmap.md](roadmap.md).

## 1. Purpose

`menuer` is the visible proof surface for the utility UI primitives in
`src/utils/ui` and the engine UI manager in `src/engine/ui`.

It currently acts as a small manual sandbox for:

* direct game-owned `utl.Panel` usage;
* engine-registered panel routing through `ng.uiManager`;
* local and manager-forwarded UI events;
* mouse-consumption behavior around UI and camera controls;
* debug readouts for hover, capture, event count, draw order, and panel flags.

## 2. Files

`engineAdapter.zig` wires the game into the engine hooks and sets the window
title/background/debug colors.

`stateInjects.zig` builds UI on `OnGameOpen()` and releases it on
`OnGameClose()`.

`stepInjects.zig` owns all current sandbox state, UI construction, event
handling, debug label updates, input routing, camera controls, and overlay
drawing.

## 3. Direct Utility Panel Coverage

The direct utility path owns `MAIN_PANEL` as a plain `utl.Panel`. It is built
and driven without registering it with `ng.uiManager`.

Current coverage:

* panel creation and deinitialization;
* column, row, and absolute layout;
* labels, buttons, checkbox, spacer, and container widgets;
* stable widget handles;
* local `Panel.updateInput()` and `Panel.popEvent()` handling;
* button click mutation through `setTextFmt()`;
* checkbox changed events and `getChecked()`;
* visual offset mutation through `setVisualOffset()`;
* absolute child hit testing and sibling-order mutation through
  `bringWidgetForward()`;
* `updateLayout()` and text metric/debug queries;
* hovered-widget, child-count, final-box, and text-metric readouts;
* `Panel.wantsMouse()` gating camera wheel zoom;
* direct `Panel.draw()` overlay rendering;
* debug bounds and a final-box marker for the moved button.

## 4. Engine Manager Coverage

The engine path owns `BACK_PANEL` and `FRONT_PANEL` as game-owned
`utl.Panel` values registered with `ng.uiManager`.

Current coverage:

* registering panels with keys, layer, and z values;
* generation-checked `eng.UiPanelHandle` storage;
* overlapping panel routing, with front panel above back panel;
* manager-local event forwarding through `ng.uiManager.popEvent()`;
* button click mutation on both registered panels;
* checkbox changed events on the front registered panel;
* a route toggle through the `u` key, implemented by changing manager input
  enabled flags on both registered panels;
* manager debug queries for registration metadata, visibility/input/draw flags,
  local event counts, hovered panel/widget, captured panel/widget by mouse
  button, pending manager events, draw order, panel count, and `wantsMouse()`;
* back-to-front drawing through `ng.uiManager.drawAll()`;
* unregistering registered panels on close before deinitializing game-owned
  panel storage.

## 5. Input And Rendering

`OnInputUpdate()` updates the direct panel first, then optionally updates the
manager when manager routing is enabled. UI mouse consumption from either path
blocks camera wheel zoom.

Keyboard controls remain game-level controls:

* `u` toggles manager input routing;
* `enter` or `p` toggles pause;
* `w`/`a`/`s`/`d` and arrow keys move the camera;
* `r` resets the camera.

`OnRenderOverlay()` draws the direct panel, then the engine manager panels, then
the standalone manager debug panel. The debug panel itself is not registered
with the manager.

## 6. Gaps Against A Full Dual-Implementation Testbed

The sandbox is not yet a feature-equivalent comparison harness.

Missing or thin coverage:

* no single boolean flag selects between a utility-only implementation and an
  engine-managed implementation of the same UI surface;
* the direct and manager paths show different panels and controls instead of
  mirrored feature coverage;
* the manager route toggle only enables/disables registered-panel input; it does
  not swap implementations;
* the debug panel is a third direct utility panel, not part of either selected
  implementation path;
* visible/input/draw flag behavior is not all user-toggleable from the sandbox;
* runtime register/unregister/re-register, manager `clear()`, and stale-handle
  rejection are not exercised by visible controls;
* widget removal, panel clearing, visibility toggles, enabled toggles, stack
  layout, style mutation, and custom draw widgets are not demonstrated;
* right and middle mouse capture are displayed in debug text but not naturally
  exercised by current controls;
* keyboard focus, text input, keyboard/gamepad navigation, modal blocking,
  close policy, persistent windows, popups, tooltips, docking, hot reload, and
  theme loading are outside the current utility and engine UI contracts.

## 7. Boundaries

`menuer` should remain a sandbox for implemented UI behavior. It should not
invent focus, modal, window, popup, text input, or global event semantics ahead
of the utility and engine UI design docs.

Utility primitive facts belong in `src/utils/ui/reference.md`. Engine
orchestration facts belong in `src/engine/ui/reference.md`. `menuer` should
only document how the game combines and demonstrates those systems.

## 8. Validation

Docs-only changes need no build.

Visible sandbox or UI behavior changes should run:

```sh
zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test
```

Broader utility or engine UI logic changes should also run:

```sh
zig build
zig build test
```

Do not run formatting passes such as `zig fmt`.
