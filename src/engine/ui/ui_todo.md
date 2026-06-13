# Engine UI TODO

Next implementation slices for `src/engine/ui`. [ui_reference.md](ui_reference.md)
describes the current baseline. [ui_goals.md](ui_goals.md) describes the target
state. [ui_roadmap.md](ui_roadmap.md) is the phase-order authority.

## 1. Current Baseline

* `src/engine/ui/uiManager.zig` registers game-owned utility panels.
* Registered panels are sorted by layer, z, and order.
* Pointer input routes front-to-back.
* Per-button panel capture exists.
* Panel-local events can be forwarded into a manager queue.
* Draw orchestration and basic debug queries exist.
* `src/games/menuer` proves direct utility panels and manager-routed overlapping
  panels side by side.

## 2. Guardrails

* Keep utility primitives independent from `eng.Engine`.
* Preserve direct game-owned `Panel` usage.
* Treat the manager as orchestration, not a required singleton.
* Keep primitive events local to `Panel`; forwarding may drain local queues but
  should not replace direct usage.
* Do not add keyboard capture, focus, modal blocking, close policy, persistent
  windows, or global engine event integration in the current manager-hardening
  slice.
* Do not run formatting passes such as `zig fmt`.

## 3. Manager Contract Hardening

Tasks:

* Add focused tests for panel registration reuse after `unregisterPanel()`.
* Verify stale `UiPanelHandle`s do not resolve after generation changes.
* Test visibility, input, and draw capability flags independently:
  * invisible panels should not receive input or draw;
  * input-disabled panels should still draw;
  * draw-disabled panels should still be eligible for input if input is enabled.
* Test hit routing when the top panel is input-disabled and a lower visible
  panel is input-enabled.
* Test capture cleanup when a captured panel is unregistered before release.
* Test and document that `clear()` invalidates outstanding handles while
  preserving reusable slot capacity.
* Expose only manager queries needed by tests and `menuer`.

## 4. Mouse Consumption Boundary

Tasks:

* Finalize and test manager-level mouse-consumption queries around:
  * hovered panel;
  * captured panel;
  * pending routed events.
* Keep `Panel.wantsMouse()` primitive-only; move refinements to utils only when
  they do not depend on manager routing policy.
* Keep keyboard capture out of this slice.
* Do not add `wantsKeyboard()` until focus, text input, keyboard navigation, or
  close policy exists.
* Update `src/games/menuer` to use the settled query surface if it removes local
  helper logic.
* Add tests for consumption state after hover, press/capture, release, and
  route-disabled toggles.

## 5. Menuer Proof Updates

Tasks:

* Keep the direct utility primitive panel visible.
* Keep the manager toggle and overlapping-panel proof while manager behavior is
  hardened.
* Add a dedicated debug panel near the top-right of the screen for centralized
  mouse and manager state when useful.
* Move centralized routing readouts out of individual test panels:
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

## 6. Deferred Features

Do not pull these into the current engine slices:

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

## 7. TODO Comment Review

Before implementation, check current TODO comments in implicated files:

* `src/engine/ui/uiManager.zig`;
* `src/games/menuer/stepInjects.zig`;
* `src/games/menuer/stateInjects.zig`;
* any utility file touched only because the manager contract needs it.

Handle each TODO explicitly:

* `address`: directly in the current slice with clear expected behavior;
* `defer`: valid but belongs to a later roadmap phase;
* `drop`: obsolete because code or docs already supersede it.
