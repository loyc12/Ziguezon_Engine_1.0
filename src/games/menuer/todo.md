# Menuer UI Testbed TODO

Active implementation tasks for `src/games/menuer`. [goals.md](goals.md) is
the target-state authority. [roadmap.md](roadmap.md) is the phase-order
authority. [reference.md](reference.md) describes the current baseline.

## 1. Active Slice

Build the engine-specific manager harness on top of the current runtime
utility-vs-engine mode boundary.

This slice should cover roadmap phase 3 only, plus the minimum debug work
needed to make manager behavior observable.

## 2. Tasks

1. Split mode-specific code into focused files.
   * Move utility-specific UI state/build/update/draw helpers into a
     `utilUi.zig` file.
   * Move engine-manager-specific UI state/build/update/draw helpers into an
     `engineUi.zig` file.
   * Keep `stepInjects.zig` as the small coordinator for lifecycle, mode
     switching, game controls, and overlay ordering.
   * Preserve the current runtime behavior before adding new controls.

2. Add focused engine-only controls.
   * Keep controls visible only in engine mode.
   * Add visible/input/draw flag toggles for registered manager panels.
   * Add register, unregister, and re-register controls for at least one
     manager-registered demo panel.
   * Add a manager `clear()` control only if it can be demonstrated without
     corrupting the surrounding sandbox lifetime.

3. Demonstrate stale-handle behavior.
   * Show stale-handle rejection after unregister.
   * Show slot reuse or generation change after re-register.
   * Show manager-clear invalidation if the clear control is included.
   * Keep stale-handle readouts compact and debug-oriented.

4. Strengthen manager routing readouts.
   * Report layer, z, order, and draw order for registered panels.
   * Report front-to-back input routing through overlapping panels.
   * Report manager event queue counts and drained event summaries.
   * Preserve per-button capture readouts.

5. Preserve the current mode boundary.
   * The utility path must remain inactive while engine controls are used.
   * Mode switching must still clear stale queued utility, panel, and manager
     events.
   * Camera wheel zoom must still be blocked only when the active UI path wants
     the mouse.
   * Camera movement, reset, and pause controls must remain available.

6. Keep the surface focused.
   * Do not add unsupported focus, modal, popup, tooltip, text-input, docking,
     hot-reload, theme, or global event demos.
   * Add code `// TODO:` notes only at concrete future extension points.
   * Remove dead code made obsolete by the manager harness changes.

7. Validate and refresh docs.
   * Run the menuer sandbox build after code changes.
   * Run broader builds/tests only if utility or engine UI implementation code
     changes.
   * Update [reference.md](reference.md) after the engine-specific behavior is
     implemented and verified.
   * Trim this todo to the next remaining slice after completion.

## 3. Out Of Scope For This Slice

Do not add visible placeholder controls for unsupported features.

Leave these for later roadmap phases:

* utility direct panel clear/rebuild controls;
* utility widget removal demos;
* utility local event queue clear controls;
* broader utility-only hit-test/readout controls;
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
