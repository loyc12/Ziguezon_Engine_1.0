# Engine UI TODO

Active implementation slices for `src/engine/ui`. [ui_reference.md](ui_reference.md)
describes the current baseline. [ui_goals.md](ui_goals.md) describes the target
state. [ui_roadmap.md](ui_roadmap.md) is the phase-order authority.

## 1. Active Slice

No active immediate implementation slice.

The manager contract, mouse-consumption boundary, and `menuer` proof surface
currently satisfy [ui_goals.md](ui_goals.md). Do not start focus, keyboard,
modal, close-policy, persistent-window, or global event integration work from
this todo without first opening a dedicated design pass.

## 2. Validation Snapshot

Current completed behavior to preserve:

* direct game-owned `Panel` usage remains valid;
* registered panels are game-owned and generation-checked through
  `UiPanelHandle`;
* unregister, slot reuse, and `clear()` invalidate stale handles;
* visibility, input, and draw flags stay independent;
* manager pointer routing is front-to-back;
* drawing is back-to-front;
* per-button capture persists until release;
* capture is cleaned up when a registered panel becomes invalid for input;
* manager-local events do not replace primitive panel-local events;
* `UiManager.wantsMouse()` is based on hovered panel, captured panel, and
  pending routed events;
* `src/games/menuer` demonstrates direct utility panels, manager-routed
  overlapping panels, a route toggle, and centralized manager/mouse debug
  readouts.

## 3. Next Intake

When continuing engine UI work, first choose exactly one design-pass topic:

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
* debug overlays beyond the `menuer` proof;
* manager-owned panels or ownership transfer.

For the chosen topic, update these docs before implementation:

1. Add the intended target behavior to [ui_goals.md](ui_goals.md) if it changes
   the engine UI target state.
2. Add implementation order and boundaries to [ui_roadmap.md](ui_roadmap.md).
3. Replace this holding todo with the precise next implementation slice.

## 4. Validation Commands

Docs-only changes need no build.

After manager logic changes:

* `zig build`;
* `zig build test`.

After sandbox or visible UI-surface changes:

* `zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test`.

Do not run formatting passes such as `zig fmt`.
