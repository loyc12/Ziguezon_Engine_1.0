# Menuer UI Testbed Roadmap

This roadmap describes the remaining implementation order from the current
[reference.md](reference.md) behavior toward the target state in
[goals.md](goals.md).

## 1. Current Baseline

`menuer` now has a runtime utility-vs-engine mode boundary, a comparable
primary demo surface for both paths, a focused utility primitive harness, and a
focused engine-manager harness.

Current useful pieces to preserve:

* one easy-to-find boolean mode flag in `stepInjects.zig`;
* focused modules for shared UI helpers, direct utility UI, engine manager UI,
  and lifecycle/input/render coordination;
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
* utility mode keeps a primitive control panel for direct panel clear/rebuild,
  widget removal/restore, local event queue holding/clearing, direct hit-test
  readouts, handle mutation, handle state readouts, slot/live counts, and
  drained-event summaries;
* `Panel.clear()` invalidates old widget handles before rebuild through
  generation-bumped slot reuse;
* `eng.Engine` owns an initialized `utl.Randomiser`, so menuer can request
  bounded random choices during input/event handling without adding another RNG
  owner;
* a direct utility debug panel is visible by default and toggleable with `d`;
* primitive debug bounds are off by default and toggleable with `b`;
* engine mode keeps a smaller back panel plus a manager control panel for
  manager handle, layer/z/order, draw order, slight-overlap routing, capture,
  flag controls, lifecycle controls, stale-handle samples, clear invalidation,
  manager queue counts, and drained-event summaries;
* camera movement, camera reset, pause, and active-path wheel gating are
  preserved;
* open/close lifetime unregisters manager panels before deinitializing
  game-owned panel storage.

## 2. Active Implementation Slice

Build a bounded randomized panel-generation harness.

The slice should add a visible control button that deletes the previous random
panel if one exists, then creates a new game-owned generated panel with
randomized widget kinds and insertion order.

Implementation order:

1. Keep ownership local to `src/games/menuer` unless implementation proves an
   engine-only behavior needs demonstration.
2. Add generated-panel state, teardown, and event clearing in the direct utility
   path first.
3. Add the generation button to the existing utility controls or a small focused
   generated-panel control group; keep it visible only when utility mode is
   active.
4. Use `ng.rng` for bounded choices, with a capped widget count and fixed
   panel/widget dimensions. Randomize widget kinds and order, not sizes.
5. Populate only currently supported primitive widgets: labels, buttons,
   checkboxes, spacers, and containers. Do not add scroll, image, sprite,
   text-input, focus, modal, popup, tooltip, docking, hot-reload, theme, or
   global event demos.
6. Update generated-panel readouts for generation count, widget mix/order,
   event counts, hover/press or hit-test state, and stale deletion/rebuild
   behavior.
7. Preserve mode isolation, camera controls, pause/reset controls, and
   active-path mouse-consumption gating.
8. Validate with the menuer sandbox build, plus broader build/test commands if
   utility or engine UI implementation code changes.

## 3. Debug Surface

The debug surface already reports the active path, mouse position,
mouse-consumption state, active event counts, utility hover/press state,
utility queue/control summaries, and engine hover/capture/handle/draw-order
data. The randomized panel slice may extend utility readouts with generated
panel count, widget mix/order, and generated-panel hit or event state. Strengthen
it further only as later engine-specific or utility-specific controls add real
state that needs inspection.

If a single debug panel becomes too tangled because utility and engine modes
need different inputs, split it into separate utility-owned debug panel
instances and draw only the relevant one.

## 4. Validation

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

## 5. Deferred And Future Updates

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
