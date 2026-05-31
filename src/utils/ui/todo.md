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
* `interfacer.zig` is not wired into retained UI rendering yet.

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

## 2. Verifying State

* Run `zig build`
* Run `zig build -Dengine_interface_path=exampleGames/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test`
* Do not run formatting pass

Passed as of 2026-05-31, 13:58

## 3. Active Next Slice

Implement the next core feature layer described in `implementation_brief.md`.

Expected headline tasks:

* Add explicit UI layers and route draw / hit-test order through them.
* Add a scissor / clip abstraction and first scroll-area behavior.
* Add slider support with drag capture and changed events.
* Add modal blocking behavior that prevents interaction below modal nodes.
* Add tooltip nodes on a top layer with hover delay.
* Add a compact UI debug overlay for layer / focus / hover / capture state.
* Extend `exampleGames/menuer` to exercise each new behavior.

## 4. Known Gaps And Clashes

* `ui_roadmap.txt` says Box2 semantics should be fixed / verified before UI relies on it, but the MVP already relies on `Box2.isOnPoint` for hit testing. Treat Box2 verification as a near-term correctness task, not a prerequisite that can still block the MVP.
* `ui_roadmap.txt` recommends UI actions become engine events through `src/core/event`, but the MVP currently uses a UI-local event buffer. Keep the local buffer for the next slice unless engine event integration is explicitly selected.
* `ui_roadmap.txt` describes a renderer interface backed by `sDraw` plus the visual half of `interfacer.zig`; the current implementation directly renders in `uiContext.zig` through `sDraw`. The next slice should extract a small render helper only if scroll clipping or layers make it clearly useful.
* `implementation_brief.md` keeps `interfacer.zig` integration out of scope for now to preserve the previous constraint. This is a deliberate deferral from the roadmap.
* There are no dedicated unit tests for retained UI or Box2 UI semantics yet; current validation is build plus the `menuer` sandbox.

## 5. Later

* Engine event integration for UI commands.
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
* `interfacer.zig` bevel / shape integration as a retained UI panel renderer.
