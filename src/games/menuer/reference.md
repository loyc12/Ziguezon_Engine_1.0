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
* bounded runtime randomized utility panel generation;
* mouse-consumption behavior around UI and camera controls;
* debug readouts for hover, press/capture, event count, draw order, handles,
  panel flags, utility hit tests, generated-panel state, local queues, and
  optional primitive bounds.

## 2. Files

`engineAdapter.zig` wires the game into the engine hooks and sets the window
title/background/debug colors.

`stateInjects.zig` builds UI on `OnGameOpen()` and releases it on
`OnGameClose()`.

`stepInjects.zig` owns the small coordinator surface: active-mode switching,
debug-panel lifetime, game controls, mouse-consumption gating, and overlay
ordering.

`uiCommon.zig` owns shared panel layout/config helpers and the primary demo
surface used by both implementation paths.

`utilUi.zig` owns the direct utility panels, generated random utility panel,
local event handling, utility debug readouts, utility-only primitive controls,
and direct drawing.

`engineUi.zig` owns the manager-routed front, back, and control panels, manager
registration lifecycle, manager event handling, engine-specific debug readouts,
and manager drawing.

## 3. Runtime Mode Boundary

`ACTIVE_UI_USES_ENGINE_MANAGER` is the single runtime mode flag in
`stepInjects.zig`.

The `u` key toggles the active path:

* utility mode updates and draws the direct primary panel, its utility-only
  primitive control panel, and any generated random utility panel;
* engine mode updates and draws the registered manager panels;
* the debug panel stays direct utility UI in both modes and is visible by
  default;
* primitive debug bounds are off by default and can be toggled independently;
* queued utility, generated-panel, registered-panel, and manager events are
  cleared when modes switch;
* inactive manager panels are made inert through their visibility, input, and
  draw flags.

The inactive primary surface is not updated or drawn, and its events are not
drained while inactive. Utility, generated-panel, registered-panel, and manager
queues are cleared on mode switch so stale events do not fire when a path
becomes active again.

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

## 5. Utility-Specific Coverage

Utility mode also shows a focused primitive control panel below the primary
surface. It keeps coverage for:

* direct `Panel.clear()` plus immediate primary-panel rebuild;
* stale-handle readouts after clear/rebuild and widget removal;
* widget removal and restore through generation-checked `utl.UiHandle` values;
* local event queue holding and `Panel.clearEvents()` controls;
* direct `Panel.hitTest()` readouts at the current mouse position;
* handle-based mutation of enabled state, desired size, row gap, and formatted
  text;
* bounded random panel generation through the `Random panel` button;
* replacement of the previous generated panel after clearing its local events
  and deinitializing its storage;
* generated panels with fixed panel size, fixed widget row height, three to
  seven randomized primitive widgets, and randomized insertion order;
* generated labels, buttons, checkboxes, spacers, and visible containers only;
* generated-panel local event draining, hit/hover/press readouts, generation
  count, widget count, widget order, queue counts, and last-event summary;
* widget slot count, live widget count, pending queue count, drained-event
  count, and last-event summaries;
* utility-only controls staying inactive while engine mode is selected.

`Panel.clear()` invalidates old widget handles before rebuild by leaving slots
available for generation-bumped reuse. The harness reports the old and new
handle states so this behavior stays visible.

## 6. Engine-Specific Coverage

Engine mode also registers a smaller back panel beside the primary engine panel,
with a small overlap left in place for manager-layer inspection, plus a focused
manager control panel below the primary surface. It keeps coverage for:

* generation-checked `eng.UiPanelHandle` storage;
* registration metadata readouts, including layer, z, and order;
* layer, z, and registration-order draw routing;
* overlapping front/back input routing;
* manager-local event forwarding;
* visibility/input/draw flag readouts and controls for the front registered
  demo panel;
* register, unregister, and re-register controls for the front registered demo
  panel;
* manager `clear()` through a recoverable control path that restores the back
  and control panels while leaving the front demo unregistered;
* stale-handle rejection after unregister, slot reuse after re-register, and
  clear invalidation readouts;
* hovered panel/widget and per-button captured panel/widget debug text;
* manager queue-before-drain counts, drained-event counts, last-event summaries,
  panel count, and draw-order readouts;
* unregistering registered panels on close before deinitializing game-owned
  panel storage.

## 7. Input And Rendering

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
the mouse. In utility mode, both the primary panel and the utility control
panel contribute to active-path mouse consumption. If a generated utility panel
exists, it also contributes to active-path mouse consumption so hovering or
pressing generated widgets blocks camera wheel zoom.

`OnRenderOverlay()` draws only the active UI path, then draws the standalone
utility debug panel. In utility mode, generated panels draw between the primary
panel and the utility control panel. In engine mode, manager drawing covers the
registered engine panels.

## 8. Deferred Gaps

The current sandbox covers the planned direct utility, generated utility, and
engine-manager comparison surface. Future expansion should start from a new
utility or engine design slice, not from visible placeholders in `menuer`.

Deferred gaps include:

* stack-layout comparison if a concrete caller needs it;
* scroll, image, sprite, text-input, focus, modal, popup, tooltip, docking, hot
  reload, theme, or global event integration demos.

## 9. Boundaries

`menuer` should remain a sandbox for implemented UI behavior. It should not
invent focus, modal, window, popup, text input, or global event semantics ahead
of the utility and engine UI design docs.

Utility primitive facts belong in `src/utils/ui/reference.md`. Engine
orchestration facts belong in `src/engine/ui/reference.md`. `menuer` should
only document how the game combines and demonstrates those systems.

## 10. Validation

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
