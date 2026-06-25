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
* utility mode has a `Random panel` control that clears stale generated events,
  deinitializes any previous generated panel, and creates a new generated panel
  with fixed panel/widget dimensions;
* generated panels use `ng.rng` to pick three to seven supported primitive
  widgets, then shuffle their insertion order while keeping labels, buttons,
  checkboxes, spacers, and visible containers as the only generated kinds;
* generated-panel local events are drained while utility mode is active, with
  generation count, previous generated count, widget count/order, queue drain
  counts, hit/hover/press state, last generated event, and mouse-consumption
  state visible through utility readouts;
* a direct utility debug panel is visible by default and toggleable with `d`;
* primitive debug bounds are off by default and toggleable with `b`;
* engine mode keeps a smaller back panel plus a manager control panel for
  manager handle, layer/z/order, draw order, slight-overlap routing, capture,
  flag controls, lifecycle controls, stale-handle samples, clear invalidation,
  manager queue counts, and drained-event summaries;
* camera movement, camera reset, pause, and active-path wheel gating are
  preserved;
* open/close lifetime unregisters manager panels before deinitializing
  game-owned panel storage, and releases generated utility panel storage.

## 2. Active Implementation Slice

Add bounded random panel generation to the engine-managed path.

The slice should mirror the current utility-mode random panel behavior while
proving the engine-specific manager surfaces: registration handles, routed
input, manager event forwarding, draw ordering, stale handle cleanup, and
manager-level mouse consumption.

Implementation order:

1. Preserve the existing module boundary.
   Keep shared fixed layout helpers in `uiCommon.zig`, generated utility panel
   behavior in `utilUi.zig`, engine-generated panel state and manager behavior
   in `engineUi.zig`, and active-mode coordination in `stepInjects.zig`.
2. Add engine-generated panel state, registration handle storage, replacement
   helpers, and teardown in the engine path.
3. Add a visible engine-mode control such as `Random panel` to the manager
   control panel. Keep it inactive and invisible while utility mode is active
   through the existing manager active-mode flags.
4. Use `ng.rng` for bounded choices. Keep fixed generated panel dimensions and
   fixed widget row heights, and randomize only widget kind plus insertion
   order.
5. Populate only supported primitive widgets: labels, buttons, checkboxes,
   spacers, and containers. Reuse or factor the utility generator only when it
   avoids meaningful duplication without hiding the manager lifecycle.
6. Register the generated panel with `ng.uiManager`, clear stale panel-local
   and manager-forwarded events during replacement, and unregister the old
   generated panel before deinitializing its storage.
7. Drain generated-panel manager events while engine mode is active and report
   generation count, widget count, widget order/mix, manager pending/drained
   events, hovered/captured or hit-test state, stale/replacement state, and last
   generated event.
8. Include the generated engine panel in manager `wantsMouse()` behavior through
   normal registration and input routing. Camera movement, reset, pause, and
   active-path wheel gating must remain available.
9. Validate with the menuer sandbox build, plus broader build/test commands
   because the slice touches engine UI implementation code.

## 3. Debug Surface

The debug surface already reports the active path, mouse position,
mouse-consumption state, active event counts, utility hover/press state,
utility queue/control summaries, generated-panel count/order/hit/event state,
and engine hover/capture/handle/draw-order data. Strengthen it further only as
later engine-specific or utility-specific controls add real state that needs
inspection.

The engine-generated panel slice should extend the engine debug/readout surface
only with state needed to validate registered generated-panel behavior: manager
handle state, route/capture state, pending/drained generated events, and
generated widget order. Avoid adding placeholder rows for unsupported UI
features.

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
