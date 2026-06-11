# UI TODO

Next steps for the retained imperative UI primitive rewrite.

`ui_implementation_reference.md` is the architecture authority. The roadmap is
the phase-order authority. This TODO stays narrower than both: it tracks the
next practical implementation slices after the primitive layer and minimal
engine manager proof.

## 0. Current Baseline

The current UI surface has moved past the first useful primitive milestone:

* `src/utils/ui/panel.zig` owns `Panel`, `Widget`, stable handles, sparse
  configs, dirty flags, layout, child order, hit testing, local events,
  rendering, text metrics, checkbox state, and handle-based introspection.
* `src/utils/ui/mouser.zig` owns engine-agnostic mouse/pointer state, button
  state, modifier state, packed UI targets, hover timing, and per-button widget
  capture.
* `src/engine/ui/uiManager.zig` provides a minimal engine-side manager for
  registered game-owned panels, layer/z/order sorting, front-to-back pointer
  routing, capture, event forwarding, draw ordering, and basic debug queries.
* `src/games/menuer` proves both direct game-owned `Panel` usage and
  manager-routed overlapping panels.
* The old retained `UiContext` manager-first implementation is gone. Do not
  revive that architecture.

## 1. Guardrails

* Preserve center-defined `Box2` semantics for primitive storage, layout, and
  query results.
* Keep top-left helpers as convenience constructors only.
* Keep UI logic in game/user code; do not add a layout scripting language.
* Keep `interface2D.zig` out of this pass unless explicitly reopened.
* Keep primitive events local to `Panel`; manager-level forwarding may drain
  local queues without replacing direct panel usage.
* Preserve the direct game-owned `Panel` path. The manager is orchestration, not
  a mandatory singleton.
* Do not add text input, keyboard navigation, modal blocking, close policy,
  persistent windows, or global engine-event integration until the narrower
  manager contract below is hardened.
* Do not run formatting passes such as `zig fmt`.

Validation rules:

* Docs-only changes need no build.
* Utility-level UI logic changes: run `zig build` and `zig build test`.
* Sandbox or UI-surface changes: also run
  `zig build -Dengine_interface_path=src/games/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test`.

## 2. Next Slice - Manager Contract Hardening

Goal: make the minimal engine manager reliable enough for later focus, modal,
and close-policy work without expanding into those features yet.

Tasks:

* Add focused tests for panel registration reuse after `unregisterPanel()`.
  Verify stale `UiPanelHandle`s do not resolve after generation changes.
* Test visibility, input, and draw capability flags independently:
  * invisible panels should not receive input or draw;
  * input-disabled panels should still draw;
  * draw-disabled panels should still be eligible for input if input is enabled.
* Test hit routing when the top panel is input-disabled and a lower visible
  panel is input-enabled.
* Test capture cleanup when a captured panel is unregistered before release.
* Decide and document whether `clear()` should preserve panel slot generations
  or invalidate all outstanding handles by resetting storage.
* Expose only the manager queries needed by the sandbox and tests. Avoid adding
  broader inspection APIs until there is a concrete caller.

## 3. Next Slice - Input Consumption Boundary

Goal: replace ad hoc game-side `wantsMouse` checks with a small, explicit query
surface that does not imply keyboard focus or modal behavior.

Tasks:

* Add or name manager-level mouse-consumption queries around existing state:
  hovered panel, captured panel, and pending routed events.
* Decide whether direct `Panel` and `UiManager` should share a common
  `wantsMouse()` helper shape or stay as separate convenience calls.
* Keep keyboard capture out of this slice. Do not add `wantsKeyboard()` until
  focus, text input, or close policy exists.
* Update `src/games/menuer` to use the settled query surface instead of local
  helper logic if the API becomes clearer.
* Add tests for consumption state after hover, press/capture, release, and route
  disabled toggles.

## 4. Next Slice - Primitive Usability Polish

Goal: remove small rough edges that make direct `Panel` usage harder than the
reference intends.

Tasks:

* Review public names around computed/final/requested boxes and keep the
  current aliases only where they reduce migration friction.
* Add narrow doc comments for game-facing APIs that are still ambiguous,
  especially ownership and lifetime rules.
* Review `getWidgetPtr()` call sites and docs. It should remain an
  advanced/internal escape hatch, not the normal mutation path.
* Consider a compact remove/clear event story for widgets:
  * no event if this stays purely internal;
  * local event only if game code needs to observe UI-driven removal later.
* Keep per-character text metrics deferred. The current `UiTextMetrics` surface
  is enough for the next slice unless text wrapping or caret work is started.

## 5. Menuer Proof Updates

Goal: keep `src/games/menuer` as a small proof surface, not a full demo app.

Tasks:

* Keep the direct primitive panel visible beside the manager-routed panels.
* Keep the manager toggle and overlapping-panel proof while manager behavior is
  being hardened.
* Add only enough readout to validate new manager contract behavior:
  registration reuse, capability flags, capture cleanup, and mouse consumption.
* Do not recreate popup, modal, slider, window, dropdown, or text-input demos
  until the primitive or manager layer actually supports those concepts.

## 6. TODO Comment Review

Current implicated files checked:

* `src/utils/ui/panel.zig`
* `src/utils/ui/mouser.zig`
* `src/engine/ui/uiManager.zig`
* `src/games/menuer/stepInjects.zig`
* `src/games/menuer/stateInjects.zig`

No live code `TODO` comments were found in those files. No TODO comments were
addressed, deferred, or dropped in this pass.

If future implicated TODO comments appear, validate their handling before
editing code:

* `address`: only when the TODO is directly in the current slice and has clear
  expected behavior.
* `defer`: when the TODO is valid but belongs to a later roadmap phase.
* `drop`: when code or docs already make the TODO obsolete.

## 7. Deferred Features

Do not pull these into the next slices unless the reference or roadmap changes:

* text input;
* keyboard/gamepad navigation;
* scroll areas;
* dropdowns and menu bars;
* tabs;
* tables/lists/property inspectors;
* graph widgets;
* docking;
* hot reload;
* theme files;
* world-space UI anchors;
* global engine event integration;
* modal blocking;
* close policy;
* persistent windows/popups/tooltips.

## 8. Final Iteration - Menuer Debug Panel

Goal: make `src/games/menuer` easier to inspect after the manager/API work is
stable, without turning it into a full demo app.

Tasks:

* Add a dedicated debug panel near the top-right of the screen for centralized
  mouse and manager state.
* Move centralized routing readouts out of the individual test panels:
  * mouse position and hover duration;
  * manager enabled state;
  * hovered panel and hovered widget;
  * captured panel/widget per mouse button;
  * manager event queue count;
  * mouse-consumption result.
* Keep per-panel labels limited to durable panel-local facts:
  * panel name;
  * handle index/generation;
  * layer, z, and draw order;
  * visible/input/draw capability flags;
  * local event count if useful.
* Add optional debug toggles for bounds, hit targets, capture markers, and text
  metrics if they improve readability.
* Prefer one clear central readout over repeating the same routing facts on
  every panel.
* Keep popup, modal, window, dropdown, slider, and text-input demos deferred
  unless the underlying UI layer actually supports them.
