# Menuer UI Testbed TODO

Active implementation tasks for `src/games/menuer`. [goals.md](goals.md) is
the target-state authority. [roadmap.md](roadmap.md) is the phase-order
authority. [reference.md](reference.md) describes the current baseline.

## 1. Active Slice

Add bounded random panel generation to the utility-side menuer harness.

The feature should be a visible utility-mode button that deletes the previous
generated random panel if it exists, then creates a new generated panel with
randomized widget kinds and insertion order. Randomization should not change
panel or widget dimensions.

## 2. Feasibility Notes

This is feasible with the current feature set.

Useful existing pieces:

* `ng.rng` is initialized by the engine and can provide bounded random choices.
* `utl.Panel` already supports runtime `init()`, `deinit()`, `clear()`,
  widget creation, widget removal, local events, hit testing, direct drawing,
  and mouse-consumption checks.
* The current utility harness already demonstrates safe clear/rebuild and stale
  handle readouts.

Primary constraints:

* cap the generated widget count;
* use fixed panel dimensions and fixed widget dimensions;
* randomize widget kinds and insertion order only;
* clear generated-panel events during replacement;
* deinitialize the previous generated panel before storing a replacement;
* avoid adding unsupported widget concepts or placeholder controls.

## 3. Tasks

1. Preserve the current module boundary.
   * Keep shared fixed layout helpers in `uiCommon.zig`.
   * Keep generated utility panel state/build/update/draw helpers in
     `utilUi.zig`.
   * Keep engine-manager-specific behavior in `engineUi.zig`.
   * Keep `stepInjects.zig` as the lifecycle, mode, game-control, and overlay
     coordinator.

2. Add generated-panel state and lifetime.
   * Add nullable generated-panel storage in the utility path.
   * Add generation counters and compact readout state.
   * Add a replacement helper that clears stale events, deinitializes any old
     generated panel, creates the new panel, and leaves no stale active handles.
   * Ensure `close()` releases generated-panel storage.

3. Add the visible generation control.
   * Add a utility-mode button such as `Random panel`.
   * Keep it inactive and invisible while engine mode is active through the
     existing active-path draw/update boundary.
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

5. Handle generated-panel events and readouts.
   * Drain generated-panel local events while the utility path is active.
   * Report generation count, widget count, widget mix/order, pending/drained
     events, hovered/pressed or hit-test state, and last generated event.
   * Include the generated panel in utility-mode `wantsMouse()` so camera wheel
     zoom is blocked when hovering or pressing generated widgets.

6. Preserve existing behavior.
   * Existing utility clear/rebuild, widget removal, queue clear, hit-test, and
     handle mutation controls must still work.
   * Mode switching must still clear stale queued utility, generated-panel, and
     manager events.
   * Camera movement, reset, pause, and active-path wheel gating must remain
     available.

7. Keep the surface focused.
   * Do not add random dimensions.
   * Do not add unsupported scroll, image, sprite, text-input, focus, modal,
     popup, tooltip, docking, hot-reload, theme, or global event demos.
   * Add code `// TODO:` notes only at concrete future extension points.
   * Remove dead code made obsolete by the generated-panel work.

8. Validate and refresh docs.
   * Run the menuer sandbox build after visible sandbox changes.
   * Run broader builds/tests only if utility or engine UI implementation code
     changes.
   * Update [reference.md](reference.md) after implementation and validation.
   * Trim this todo and roadmap after the slice is complete.

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
