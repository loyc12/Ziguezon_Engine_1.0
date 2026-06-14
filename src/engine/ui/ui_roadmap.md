# Engine UI Roadmap

This roadmap records engine-side UI phase order from the current
[ui_reference.md](ui_reference.md) baseline toward the target state in
[ui_goals.md](ui_goals.md).

## 1. Completed - Minimal Manager

Goal: prove that the engine can orchestrate utility `Panel` primitives without
making the direct panel path mandatory.

Implemented:

* `UiManager`;
* `UiPanelHandle`;
* `UiPanelConfig`;
* registration of game-owned panels;
* layer/z/order sorting;
* front-to-back panel hit routing;
* per-button captured panel state;
* manager-local event forwarding;
* `drawAll()` orchestration;
* panel count/order, hovered panel, captured panel, and queued-event queries;
* overlapping manager-routed proof in `src/games/menuer`.

Still intentionally absent:

* manager-owned panel lifetime;
* focus;
* keyboard routing;
* modal blocking;
* close policy;
* persistent windows/popups/tooltips;
* global engine event integration beyond the manager-local queue.

## 2. Next - Manager Contract Hardening

Goal: make the current manager reliable enough for later focus, modal, and close
policy work.

Required:

* registration slot reuse tests after `unregisterPanel()`;
* stale `UiPanelHandle` tests after generation changes;
* independent visibility/input/draw capability tests;
* routing test when the top panel is input-disabled and a lower panel is
  input-enabled;
* capture cleanup test when a captured panel is unregistered before release;
* documented and tested `clear()` handle invalidation semantics;
* narrow query surface for the sandbox and tests only.

Do not add focus, keyboard routing, modal blocking, or close policy in this
phase.

## 3. Next - Mouse Consumption Boundary

Goal: replace ad hoc game-side manager mouse checks with an explicit query
surface that does not imply keyboard focus.

Required:

* manager-level query around hovered panel, captured panel, and pending routed
  events, shaped consistently with primitive `Panel.wantsMouse()`;
* tests for consumption after hover, press/capture, release, and disabled
  routing;
* `src/games/menuer` update to use the settled manager query when it improves
  clarity.

Keyboard capture remains deferred until focus, text input, keyboard navigation,
or close policy exists.

## 4. Next - Menuer Manager Debug Panel

Goal: keep `src/games/menuer` useful as a compact manager proof surface.

Required:

* keep the direct utility panel visible beside manager-routed panels;
* keep the manager toggle and overlapping-panel proof;
* add only enough centralized readout to validate manager behavior:
  registration reuse, capability flags, capture cleanup, and mouse consumption;
* move repeated manager routing readouts out of individual test panels when the
  central panel exists.

Do not recreate popup, modal, window, dropdown, slider, or text-input demos here.

## 5. Later - Stronger Engine UI System

Future work, each requiring its own small design pass:

* manager-owned panels or ownership transfer;
* focus rules;
* keyboard/gamepad routing;
* modal blocking;
* close policy;
* persistent windows, popups, and tooltips;
* engine event/command forwarding if the manager-local queue is not enough;
* optional world-space UI routing;
* debug overlays beyond the `menuer` proof.

## 6. Validation Strategy

Docs-only changes need no build.

Manager logic changes:

* run `zig build`;
* run `zig build test`.

Sandbox or visible UI-surface changes:

* also run `zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test`.

Do not run formatting passes such as `zig fmt`.
