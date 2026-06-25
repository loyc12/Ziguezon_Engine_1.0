# Menuer UI Testbed TODO

Active implementation tasks for `src/games/menuer`. [goals.md](goals.md) is
the target-state authority. [roadmap.md](roadmap.md) is the phase-order
authority. [reference.md](reference.md) describes the current baseline.

## 1. Active Slice

Add bounded random panel generation to the engine-managed menuer harness.

The feature should mirror the current utility-mode generated panel, but route
the generated panel through `ng.uiManager`. A visible engine-mode button should
delete the previous generated engine panel if it exists, clear stale local and
manager-forwarded events, unregister the old manager handle, deinitialize old
panel storage, create a new generated panel, register it with the manager, and
report the resulting manager state.

Randomization should not change panel or widget dimensions.

## 2. Feasibility Notes

This is feasible with the current feature set.

Useful existing pieces:

* utility mode already has bounded generated-panel creation, replacement,
  event draining, readouts, and mouse-consumption checks;
* `engineUi.zig` already owns game-created panels, registers them with
  `ng.uiManager`, unregisters them on close, drains manager events, and reports
  manager handle state;
* `ng.rng` is initialized by the engine and can provide bounded random choices;
* `utl.Panel` already supports runtime `init()`, `deinit()`, widget creation,
  local event clearing, hit testing, direct drawing, and mouse-consumption
  checks;
* `ng.uiManager` already handles registered-panel input routing, manager event
  forwarding, draw ordering, stale panel handles, and manager `wantsMouse()`.

Primary constraints:

* preserve the current module boundary;
* cap the generated widget count;
* use fixed panel dimensions and fixed widget dimensions;
* randomize widget kinds and insertion order only;
* clear generated-panel local events and manager-forwarded events during
  replacement;
* unregister the old generated panel before deinitializing its storage;
* avoid adding unsupported widget concepts or placeholder controls.

## 3. Tasks

1. Preserve the current module boundary.
   * Keep shared fixed layout helpers in `uiCommon.zig`.
   * Keep generated utility panel behavior in `utilUi.zig`.
   * Keep engine-generated panel state/build/register/update/draw helpers in
     `engineUi.zig`.
   * Keep `stepInjects.zig` as the lifecycle, mode, game-control, and overlay
     coordinator.

2. Add generated engine-panel state and lifetime.
   * Add nullable generated-panel storage in the engine path.
   * Add an `eng.UiPanelHandle` for the registered generated panel.
   * Add generation counters and compact readout state.
   * Add a replacement helper that clears stale local and manager-forwarded
     events, unregisters the old generated panel, deinitializes it, creates the
     replacement, registers it, and leaves no stale active handles.
   * Ensure `close()` unregisters and releases generated-panel storage.

3. Add the visible engine generation control.
   * Add an engine-mode button such as `Random panel`.
   * Keep it inactive and invisible while utility mode is active through the
     existing active-path manager flag boundary.
   * Use the existing engine RNG from `ng.rng`; do not create a separate global
     RNG owner.

4. Generate bounded content.
   * Use a fixed generated panel box and fixed widget row heights.
   * Randomize only widget kind and insertion order.
   * Use supported primitive widgets only: labels, buttons, checkboxes,
     spacers, and containers.
   * Cap the generated widget count to a small readable range.
   * Use deterministic key construction per generation/index so handle and
     event readouts remain understandable.
   * Share small generator helpers with utility mode only when that removes
     meaningful duplication without hiding the manager lifecycle.

5. Handle manager events and readouts.
   * Drain generated-panel manager events while the engine path is active.
   * Report generation count, widget count, widget mix/order, pending/drained
     generated events, manager handle state, hovered/captured or hit-test
     state, stale/replacement state, and last generated event.
   * Include the generated panel in engine-mode mouse consumption through
     normal `ng.uiManager` registration and `wantsMouse()` routing.

6. Preserve existing behavior.
   * Existing engine register/unregister/re-register, manager clear, front/back
     route tests, draw-order controls, panel flags, and stale-handle readouts
     must still work.
   * Existing utility clear/rebuild, generated utility panel, widget removal,
     queue clear, hit-test, and handle mutation controls must still work.
   * Mode switching must still clear stale queued utility, generated utility,
     registered-panel, generated engine, and manager events.
   * Camera movement, reset, pause, and active-path wheel gating must remain
     available.

7. Keep the surface focused.
   * Do not add random dimensions.
   * Do not add unsupported scroll, image, sprite, text-input, focus, modal,
     popup, tooltip, docking, hot-reload, theme, or global event demos.
   * Add code `// TODO:` notes only at concrete future extension points.
   * Remove dead code made obsolete by the generated engine-panel work.

8. Validate and refresh docs.
   * Run the menuer sandbox build after visible sandbox changes.
   * Run broader builds/tests because engine UI implementation code changes.
   * Update [reference.md](reference.md) after implementation and validation.
   * Trim this todo and roadmap after the slice is complete.

## 4. Validation

Visible sandbox or UI behavior changes should run:

```sh
zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test
```

If utility or engine UI implementation code changes:

```sh
zig build
zig build test
```

Do not run formatting passes such as `zig fmt`.
