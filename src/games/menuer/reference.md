# Menuer UI Testbed Reference

This file describes the current `src/games/menuer` UI sandbox baseline.
Desired rework direction belongs in [goals.md](goals.md). Implementation order
belongs in [roadmap.md](roadmap.md).

## 1. Purpose

`menuer` is the visible proof surface for the utility UI primitives in
`src/utils/ui` and the engine UI manager in `src/engine/ui`.

It currently acts as a dual-path manual sandbox for:

* direct game-owned `utl.Panel` usage;
* engine-registered panel routing through `ng.uiManager`;
* local and manager-forwarded UI events;
* runtime utility-vs-engine mode selection;
* mouse-consumption behavior around UI and camera controls;
* debug readouts for hover, press/capture, event count, draw order, handles,
  panel flags, and optional primitive bounds.

## 2. Files

`engineAdapter.zig` wires the game into the engine hooks and sets the window
title/background/debug colors.

`stateInjects.zig` builds UI on `OnGameOpen()` and releases it on
`OnGameClose()`.

`stepInjects.zig` owns sandbox state, UI construction, active-mode switching,
event handling, debug label updates, camera controls, and overlay drawing.

## 3. Runtime Mode Boundary

`ACTIVE_UI_USES_ENGINE_MANAGER` is the single runtime mode flag in
`stepInjects.zig`.

The `u` key toggles the active path:

* utility mode updates and draws the direct `MAIN_PANEL`;
* engine mode updates and draws the registered manager panels;
* the debug panel stays direct utility UI in both modes and is visible by
  default;
* primitive debug bounds are off by default and can be toggled independently;
* queued utility, registered-panel, and manager events are cleared when modes
  switch;
* inactive manager panels are made inert through their visibility, input, and
  draw flags.

The inactive primary surface is not updated or drawn, and its events are not
drained while inactive.

## 4. Shared Primary Surface

Both active modes expose the same primary demo shape:

* one column panel at the same screen position;
* labels, buttons, checkbox, spacer, row container, and absolute container;
* clicked and changed event handling;
* text mutation and formatted text mutation;
* checkbox state query and programmatic checkbox mutation;
* visual offset mutation;
* widget visibility/enabled mutation through the `Move / style` button;
* style mutation on the moved button;
* absolute child hit testing and sibling-order mutation through
  `bringWidgetForward()`;
* hover, left-press, event-count, final-box, and text-metric readouts;
* a final-box marker for the moved button;
* active-path `wantsMouse()` gating camera wheel zoom.

The utility path demonstrates this through direct `Panel.updateInput()`,
`Panel.popEvent()`, `Panel.wantsMouse()`, and `Panel.draw()`.

The engine path demonstrates the same surface through `UiManager.updateInput()`,
manager event forwarding, `UiManager.wantsMouse()`, and `UiManager.drawAll()`.

## 5. Engine-Specific Coverage

Engine mode also registers a smaller back panel beside the primary engine panel,
with a small overlap left in place for manager-layer inspection. It keeps
coverage for:

* generation-checked `eng.UiPanelHandle` storage;
* registration metadata readouts;
* layer, z, and registration-order draw routing;
* overlapping panel routing;
* manager-local event forwarding;
* visibility/input/draw flag readouts;
* hovered panel/widget and per-button captured panel/widget debug text;
* manager event count, panel count, and draw-order readouts;
* unregistering registered panels on close before deinitializing game-owned
  panel storage.

## 6. Input And Rendering

Keyboard controls remain game-level controls:

* `u` toggles active UI mode;
* `d` toggles the utility debug panel;
* `b` toggles primitive debug bounds, including the gold text-metric boxes and
  cyan widget/panel boxes;
* `enter` or `p` toggles pause;
* arrow keys move the camera;
* `r` resets the camera.

`OnInputUpdate()` updates only the active UI path, then refreshes the utility
debug panel. Camera wheel zoom runs only when the active UI path does not want
the mouse.

`OnRenderOverlay()` draws only the active primary UI path, then draws the
standalone utility debug panel. In engine mode, manager drawing covers the
registered engine panels.

## 7. Remaining Gaps

The sandbox is now a runtime comparison harness, but not the full target state.

Remaining gaps include:

* no visible runtime register/unregister/re-register controls;
* no manager `clear()` control;
* no stale-handle rejection demonstration after unregister, slot reuse, or
  clear;
* no full visible/input/draw flag control coverage;
* no widget removal demo;
* no local event queue clear control;
* no direct panel clear/rebuild demo;
* no scroll, image, sprite, text-input, focus, modal, popup, tooltip, docking,
  hot reload, theme, or global event integration demos.

## 8. Boundaries

`menuer` should remain a sandbox for implemented UI behavior. It should not
invent focus, modal, window, popup, text input, or global event semantics ahead
of the utility and engine UI design docs.

Utility primitive facts belong in `src/utils/ui/reference.md`. Engine
orchestration facts belong in `src/engine/ui/reference.md`. `menuer` should
only document how the game combines and demonstrates those systems.

## 9. Validation

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
