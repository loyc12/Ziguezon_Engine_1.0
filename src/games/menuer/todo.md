# Menuer UI Testbed TODO

Active implementation tasks for `src/games/menuer`. [goals.md](goals.md) is
the target-state authority. [roadmap.md](roadmap.md) is the phase-order
authority. [reference.md](reference.md) describes the current baseline.

## 1. Active Slice

Build the runtime utility-vs-engine mode boundary and reshape the primary demo
surface enough that both paths can be compared without clutter.

This slice should cover roadmap phases 1 and 2, plus only the minimum debug
work needed to make the mode switch observable.

## 2. Tasks

1. Add the runtime mode flag.
   * Add an easy-to-find boolean near the top of `stepInjects.zig` for the
     active UI implementation.
   * Add a small input toggle for the flag.
   * Make the current active mode visible in the debug panel.
   * Replace or retire the current `MANAGER_ROUTE_ENABLED` behavior if it no
     longer matches the active-mode model.

2. Separate active and inactive path behavior.
   * Ensure the active path receives input, drains events, updates state, and
     draws its primary surface.
   * Ensure the inactive path does not receive input or emit events.
   * Make inactive manager panels inert through the smallest clean route, such
     as unregistering, hiding, or input-disabling them.
   * Clear stale queued events when switching modes.

3. Extract small build/update/draw helpers.
   * Split the current monolithic `stepInjects.zig` flow into direct helper
     functions for utility mode, engine mode, and debug UI.
   * Keep helpers concrete to the sandbox; do not introduce a generic UI
     abstraction layer.
   * Add concise code `TODO` notes only at real extension points for future
     utility or engine features.

4. Reshape overlapping demonstrations.
   * Give both active modes a comparable primary surface for labels, buttons,
     checkboxes, containers, clicked/changed events, text mutation, checked
     state, hover readouts, event counts, and mouse-consumption behavior.
   * Keep divergent engine-only examples when they are needed to show manager
     layer/z/order, draw order, capture, handles, or flags.
   * Use as few panels and controls as practical.

5. Keep debug UI always active and utility-owned.
   * Keep the debug panel direct `utl.Panel` UI.
   * Report active mode, mouse position, mouse-consumption state, active-path
     event counts, hovered/pressed or captured widget state, and engine handle
     data when engine mode is active.
   * Split debug into separate utility-owned panels only if one panel becomes
     tangled across incompatible state sources.

6. Preserve game controls.
   * Keep camera movement and camera reset behavior.
   * Keep camera wheel zoom blocked while the active UI path wants the mouse.
   * Keep pause behavior unless the mode toggle needs a key reassignment.

7. Validate and refresh docs.
   * Run the menuer sandbox build after code changes.
   * Run broader builds/tests only if utility or engine UI implementation code
     changes.
   * Update [reference.md](reference.md) after the new active-mode behavior is
     implemented and verified.
   * Trim this todo to the next remaining slice after completion.

## 3. Out Of Scope For This Slice

Do not add visible placeholder controls for unsupported features.

Leave these for later roadmap phases:

* runtime register/unregister/re-register controls;
* manager `clear()` controls;
* stale-handle rejection demonstrations;
* full visible/input/draw flag control coverage;
* widget removal demos;
* local event queue clear controls;
* scroll, image, sprite, text-input, focus, modal, popup, tooltip, docking, hot
  reload, theme, or global event integration demos.

## 4. Validation

After visible sandbox changes:

```sh
zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test
```

If utility or engine UI implementation code changes:

```sh
zig build
zig build test
```

Do not run formatting passes such as `zig fmt`.
