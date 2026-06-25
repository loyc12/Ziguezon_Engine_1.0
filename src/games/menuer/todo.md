# Menuer UI Testbed TODO

Active implementation tasks for `src/games/menuer`. [goals.md](goals.md) is
the target-state authority. [roadmap.md](roadmap.md) is the phase-order
authority. [reference.md](reference.md) describes the current baseline.

## 1. Active Slice

Build the utility-specific harness on top of the current split utility-vs-engine
testbed.

This slice should cover roadmap phase 4 only, plus the minimum debug work
needed to make direct primitive behavior observable.

## 2. Tasks

1. Preserve the current module boundary.
   * Keep shared primitive helpers in `uiCommon.zig`.
   * Keep direct utility UI state/build/update/draw helpers in `utilUi.zig`.
   * Keep engine-manager-specific helpers in `engineUi.zig`.
   * Keep `stepInjects.zig` as the small coordinator for lifecycle, mode
     switching, game controls, and overlay ordering.

2. Add focused utility-only controls.
   * Keep controls visible only in utility mode.
   * Add direct panel clear/rebuild behavior if it can be demonstrated without
     corrupting the surrounding sandbox lifetime.
   * Add widget removal behavior if the current primitive API remains stable
     enough to demo.
   * Add local event queue clear controls.
   * Add direct hit-test/readout helpers.
   * Add handle-based mutation and introspection that would otherwise be easy
     to regress.

3. Preserve the current mode boundary.
   * The inactive path must remain inactive while the active controls are used.
   * Mode switching must still clear stale queued utility, panel, and manager
     events.
   * Camera wheel zoom must still be blocked only when the active UI path wants
     the mouse.
   * Camera movement, reset, and pause controls must remain available.

4. Keep the surface focused.
   * Do not add unsupported focus, modal, popup, tooltip, text-input, docking,
     hot-reload, theme, or global event demos.
   * Add code `// TODO:` notes only at concrete future extension points.
   * Remove dead code made obsolete by the utility harness changes.

5. Validate and refresh docs.
   * Run the menuer sandbox build after code changes.
   * Run broader builds/tests only if utility or engine UI implementation code
     changes.
   * Update [reference.md](reference.md) after the utility-specific behavior is
     implemented and verified.
   * Trim this todo to the next remaining slice after completion.

## 3. Out Of Scope For This Slice

Do not add visible placeholder controls for unsupported features.

Leave these for later roadmap phases:

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
