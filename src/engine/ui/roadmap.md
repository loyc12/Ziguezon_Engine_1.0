# Engine UI Roadmap

This roadmap records engine-side UI phase order from the current
[ui_reference.md](ui_reference.md) baseline toward the target state in
[ui_goals.md](ui_goals.md).

## 1. Current Status

The immediate engine UI manager goal is complete.

Validated current behavior:

* `UiManager` registers game-owned utility `Panel` primitives without replacing
  direct panel usage.
* Panel handles are generation-checked and reject stale handles after
  unregister, slot reuse, and `clear()`.
* Visibility, input, and draw capability flags are independent.
* Pointer input routes front-to-back and drawing routes back-to-front.
* Per-button capture persists until release and is cleared when a panel becomes
  invalid for input.
* Manager-local event forwarding coexists with primitive panel-local events.
* `wantsMouse()` exposes the mouse-consumption boundary from hover, capture,
  and pending routed events.
* `src/games/menuer` keeps both direct utility panel usage and manager-routed
  overlapping panels visible, with a centralized manager/mouse debug panel.

## 2. No Active Immediate Slice

There is no remaining immediate implementation work implied by
[ui_goals.md](ui_goals.md).

The goals file’s success condition is satisfied: the engine can orchestrate
registered UI panels predictably, games can still use utility panels directly,
input consumption is explicit, and later focus/modal work has a tested manager
contract to build on.

Keep [ui_todo.md](ui_todo.md) in a holding state until a new design pass is
chosen.

## 3. Later Design Passes

Each future item needs its own small design pass before becoming an active
implementation slice:

* manager-owned panels or ownership transfer;
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
* theme-file loading;
* debug overlays beyond the `menuer` proof.

## 4. Validation Strategy

Docs-only changes need no build.

Manager logic changes:

* run `zig build`;
* run `zig build test`.

Sandbox or visible UI-surface changes:

* also run `zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test`.

Do not run formatting passes such as `zig fmt`.
