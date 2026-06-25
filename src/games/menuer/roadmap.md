# Menuer UI Testbed Roadmap

This roadmap describes the remaining implementation order from the current
[reference.md](reference.md) behavior toward the target state in
[goals.md](goals.md).

## 1. Current Baseline

`menuer` now has a runtime utility-vs-engine mode boundary and a comparable
primary demo surface for both paths.

Current useful pieces to preserve:

* one easy-to-find boolean mode flag in `stepInjects.zig`;
* `u` toggles the active implementation at runtime;
* the active path receives input, drains events, updates state, and draws its
  primary surface;
* inactive manager panels are hidden, input-disabled, draw-disabled, and have
  stale queued events cleared on mode switch;
* utility and engine primary surfaces both demonstrate labels, buttons,
  checkbox, spacer, row/absolute containers, clicked/changed events, text
  mutation, checked-state mutation, visibility/enabled mutation, style
  mutation, hover/press readouts, event counts, text metrics, final-box marker,
  and active-path mouse consumption;
* a direct utility debug panel is visible by default and toggleable with `d`;
* primitive debug bounds are off by default and toggleable with `b`;
* engine mode keeps a smaller back panel for manager handle, layer/z/order,
  draw order, slight-overlap routing, capture, and flag readouts;
* camera movement, camera reset, pause, and active-path wheel gating are
  preserved;
* open/close lifetime unregisters manager panels before deinitializing
  game-owned panel storage.

## 2. Phase 3 - Engine-Specific Harness

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

## 3. Phase 4 - Utility-Specific Harness

Keep a focused utility-only section for primitive behavior that does not require
engine orchestration.

Coverage to add or strengthen:

* direct panel clear/rebuild behavior;
* widget removal if the current primitive API remains stable enough to demo;
* enabled/visible widget mutation beyond the current primary-surface mutation;
* local event queue clearing;
* direct hit-test/readout helpers;
* handle-based mutation and introspection that would otherwise be easy to
  regress.

Do not duplicate engine-only controls unless they clarify the comparison.

## 4. Phase 5 - Debug Surface

Keep the debug UI direct utility-owned and always active by default.

The debug surface already reports the active path, mouse position,
mouse-consumption state, active event counts, utility hover/press state, and
engine hover/capture/handle/draw-order data. Strengthen it only as later
engine-specific or utility-specific controls add real state that needs
inspection.

If a single debug panel becomes too tangled because utility and engine modes
need different inputs, split it into separate utility-owned debug panel
instances and draw only the relevant one.

## 5. Phase 6 - Cleanup And Validation

After each harness slice:

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

## 6. Deferred And Future Updates

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
