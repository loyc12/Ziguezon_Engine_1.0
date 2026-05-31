# UI TODO

Action checklist for the retained-mode UI system. Design rationale lives in `ui_roadmap.txt`; the active implementation contract lives in `implementation_brief.md`.

## 0. Current Decisions

* Retained-mode UI tree owned by the engine through `Engine.uiManager`.
* No raygui dependency.
* Use `Box2` as the final layout / hit-test rectangle.
* Use `def.sDraw` for screen UI and `def.wDraw` only for separate world-space labels / markers.
* UI frame processing runs in `engineStep.updateFrame`: `beginFrame`, `updateLayout`, `dispatchInput`, game `OnUpdateFrame`, then `endFrame`.
* Screen UI render runs from `engineStep.renderAll` in the overlay phase after game `OnRenderOverlay` and before debug FPS / TPS text.
* UI currently reads game state through direct sandbox updates and writes back through a UI-local event buffer.
* `interfacer.zig` is a deprecated/stub visual experiment for now. Ignore it for retained UI work until the user explicitly asks to revisit it.

## 1. Completed MVP

* Engine-owned `UiManager` / `UiContext` lifecycle: init during engine start, deinit during engine stop.
* Core files exist: `uiContext.zig`, `uiNode.zig`, `uiInput.zig`, `uiTypes.zig`.
* Public retained UI types are exported through `defs.zig`.
* Stable `UiId` with index + generation and `UiId.none()`.
* Retained node storage with slot reuse and stale-id rejection.
* Node kinds: root, panel, label, button, checkbox, popup, window.
* Parent / child hierarchy.
* Dependency links for menu / popup invalidation.
* Close propagation for parent-owned children and dependent nodes.
* Visibility, enabled, modal, detached-root, close-on-outside, and close-on-escape flags.
* Basic absolute, vertical, horizontal, and floating layout.
* Final bounds stored as `Box2`.
* Per-frame `UiInput` snapshot for mouse, wheel, Escape, Enter, and Space.
* Mouse hover, press, release, focus, capture helpers, and basic keyboard capture.
* Outside-click and Escape close for transient UI.
* UI-local events for clicked, changed, and closed.
* Basic `sDraw` rendering for panels / windows / popups, labels, buttons, and checkboxes.
* `exampleGames/menuer` sandbox demonstrates panel, label, button, checkbox, dependent popup, independent window, close behavior, and capture debug text.

## 2. Completed v0.5 Feature Layer

* Explicit UI layers: HUD, panel, popup, modal, tooltip.
* Layer-aware draw order and hit testing.
* Modal hit-test blocking for lower / non-descendant UI.
* Raylib scissor clip helpers for retained screen UI.
* Scroll-area node with clipped children, wheel scrolling, and vertical scroll clamping.
* Horizontal slider node with mouse drag capture and float changed events.
* Fixed-buffer tooltip text with hover delay, top overlay rendering, and screen-edge clamping.
* Toggleable compact debug overlay for node count, live count, event count, hover / focus / press kinds, capture flags, modal state, and optional layer-colored bounds.
* `exampleGames/menuer` sandbox demonstrates the retained MVP controls plus popup layering, modal blocking, scroll area, slider label updates, tooltips, debug overlay, and input capture suppression.

## 3. Verifying State

* Run `zig build`
* Run `zig build -Dengine_interface_path=exampleGames/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test`
* Run `zig build test` after utility-level changes
* Do not run formatting pass

Passed as of 2026-05-31, 15:19 EDT

## 4. Active Next Slice

No active retained UI implementation slice is defined after the v0.5 pass.

## 5. Resolved Conflicts And Known Gaps

* Box2 is suitable for retained UI layout bounds, hit tests, overlap checks, and screen-edge clamping. The relation semantics and `clampIn` / `clampOn` / `clampOut` behavior are now covered by focused Box2 tests.
* Prefer Box2 `getSize` / `getSizeX` / `getSizeY` over ad hoc `scale * 2.0` math in new UI code.
* `ui_roadmap.txt` recommends UI actions become engine events through `src/core/event`, but the current global `EventManager` is unused, lightly validated, and has uncompiled-risk code paths. Keep the UI-local event buffer for the next slice; revisit global event integration after the event manager has tests or a real non-UI consumer.
* `ui_roadmap.txt` describes a renderer interface backed by `sDraw` plus the visual half of `interfacer.zig`; the current implementation directly renders in `uiContext.zig` through `sDraw`. Since `interfacer.zig` is treated as a stub, the next slice should ignore it entirely and extract a small render helper only if scroll clipping or layers make it clearly useful.
* There are no dedicated unit tests for retained UI behavior yet; current UI validation is build plus the `menuer` sandbox.

## 6. Later

* Engine event integration for UI commands after `src/core/event` has a validated dispatch contract.
* Comptime panel definitions and `ui.show` / `ui.hide` API.
* Text input.
* Dropdown.
* Menu bar.
* Tab bar.
* Table / list rows.
* Property inspector.
* Tree view.
* Graph / debug plot custom draw node.
* Keyboard navigation.
* Gamepad navigation.
* Clipboard.
* Theme / skin files.
* Hot-reloadable panel definitions.
* World-space UI / anchors.
* Possible replacement or rewrite of `interfacer.zig` as a retained UI panel renderer, only after explicit user approval.
