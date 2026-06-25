# Menuer UI Testbed Roadmap

This roadmap describes the implementation order from the current
[reference.md](reference.md) baseline toward the target state in
[goals.md](goals.md).

## 1. Current Baseline

`menuer` already proves both UI usage paths, but not as a dual-path comparison
harness.

Current useful pieces to preserve:

* a direct utility `MAIN_PANEL` with primitive widgets, local events, local
  `wantsMouse()`, direct draw, layout, mutation, and debug readouts;
* engine-managed `BACK_PANEL` and `FRONT_PANEL` with registration handles,
  layer/z ordering, manager event forwarding, capture/hover debug, draw order,
  and manager `wantsMouse()`;
* a direct utility manager-debug panel;
* camera wheel zoom gated by utility or manager mouse consumption;
* open/close lifetime that unregisters manager panels before deinitializing
  game-owned panel storage.

The current `u` key toggles manager input routing only. It is not the final
runtime implementation selector.

## 2. Phase 1 - Runtime Mode Boundary

Add one easy-to-find runtime boolean for the active UI path.

Expected behavior:

* one path is active at a time;
* the active path builds, receives input, emits events, updates debug state, and
  draws its primary surface;
* the inactive path is not allowed to receive input or emit events;
* inactive manager panels are unregistered, hidden/input-disabled, or otherwise
  made inert through the smallest clean implementation;
* the active path is visible in the always-active debug UI;
* a separate debug visibility flag may be added if the debug panel needs its own
  runtime toggle.

Keep the mode boundary direct. Do not add a generic UI abstraction layer unless
the implementation proves a real duplicated-ownership problem.

## 3. Phase 2 - Shared Demonstration Shape

Reshape the primary utility and engine examples so overlapping features share a
similar form factor where practical.

Shared behavior to cover:

* labels;
* buttons;
* checkboxes;
* spacers;
* containers;
* column, row, absolute, and stack layout if stack remains useful enough to
  show;
* clicked and changed events;
* text and formatted text mutation;
* checked-state query/mutation;
* visible and enabled state mutation;
* supported widget or panel movement;
* style mutation;
* hover, pressed/captured, event count, final-box, and text-metric readouts;
* mouse-consumption gating for camera wheel zoom.

Use the fewest panels and widgets that demonstrate these behaviors clearly.
Diverge from shared form factor when engine-only or utility-only behavior would
otherwise be hidden.

## 4. Phase 3 - Engine-Specific Harness

Keep a focused engine-only section for manager behavior that direct utility UI
cannot demonstrate.

Coverage to add or strengthen:

* visible/input/draw flag toggles;
* register, unregister, and re-register controls;
* manager `clear()` control;
* stale-handle rejection readout after unregister, slot reuse, and clear;
* layer/z/order draw and input routing readouts;
* per-button capture behavior where the current controls can naturally exercise
  it;
* manager event queue count and drained-event summaries.

Prefer visible controls only for implemented behavior. Put code-local `TODO`
notes at obvious extension points for future manager concepts that are not yet
implemented.

## 5. Phase 4 - Utility-Specific Harness

Keep a focused utility-only section for primitive behavior that does not require
engine orchestration.

Coverage to add or strengthen:

* direct panel clear/rebuild behavior;
* widget removal if the current primitive API remains stable enough to demo;
* enabled/visible widget mutation;
* local event queue clearing;
* direct hit-test/readout helpers;
* handle-based mutation and introspection that would otherwise be easy to
  regress.

Do not duplicate engine-only controls unless they clarify the comparison.

## 6. Phase 5 - Debug Surface

Keep the debug UI direct utility-owned and always active by default.

The debug surface should report:

* active path;
* utility path state when utility mode is active;
* engine path state when engine mode is active;
* mouse position and mouse-consumption state;
* event counts;
* hovered and pressed/captured widgets;
* manager handles, generations, draw order, and flags when engine mode is
  active.

If a single debug panel becomes too tangled because utility and engine modes
need different inputs, split it into separate utility-owned debug panel
instances and draw only the relevant one.

## 7. Phase 6 - Cleanup And Validation

After the mode split and feature coverage are in place:

* remove obsolete route-toggle semantics that no longer match the runtime mode
  boundary;
* remove dead code made obsolete by the selected structure;
* keep any deferred extension points as concise `TODO` notes in code;
* update [reference.md](reference.md) to describe the new current behavior;
* trim this roadmap to remaining work.

Validation for visible sandbox changes:

```sh
zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test
```

If utility or engine UI implementation code changes:

```sh
zig build
zig build test
```

Do not run formatting passes such as `zig fmt`.

## 8. Deferred And Future Updates

Do not show unimplemented UI concepts in the visible sandbox. Keep the visual
surface focused on behavior that exists today.

When future utility or engine UI features are implemented, update this roadmap
before expanding `menuer`. Add the feature to the active plan only when it is
implemented enough to demonstrate without placeholders.

Deferred utility candidates:

* richer text metrics;
* text wrapping or clipping;
* scroll-region primitives;
* image or sprite widgets;
* custom draw widgets if they get a stable caller-facing contract;
* additional layout helpers such as min/max sizing, anchors, or grid layout.

Deferred engine candidates:

* focus rules;
* keyboard routing;
* keyboard/gamepad navigation;
* text input;
* modal blocking;
* close policy;
* persistent windows, popups, and tooltips;
* global engine event integration;
* world-space UI anchors;
* docking;
* hot reload;
* theme-file loading.

For deferred behavior, add code `TODO` notes only where the current
implementation already has a natural extension point. Do not add disabled
buttons, placeholder panels, or visible rows for features that do not exist yet.
