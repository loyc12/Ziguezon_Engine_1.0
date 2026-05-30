# UI TODO

Action checklist for the retained-mode UI system. Design rationale lives in `ui_roadmap.txt`; keep this file short and implementation-focused.

## 0. Current Decisions

* Retained-mode UI tree owned by the engine.
* No raygui dependency.
* Use `Box2` as the final layout / hit-test rectangle.
* Use `def.sDraw` for screen UI and `def.wDraw` only for simple world-space labels / markers.
* UI update runs from `updateFrame` / `OnUpdateFrame`.
* Screen UI render runs from `renderAll` / `OnRenderOverlay`.
* World-space UI, if needed, is a separate lightweight path in `OnRenderWorld`.
* UI reads game state through bindings / snapshots and writes back through events or commands.

## 1. Prerequisites

* Review `Box2` `isOn` / `isIn` / `isOut` semantics before relying on it for UI.
* Add small Box2 tests or debug checks for point hit tests, overlap, containment, and clamp behavior.
* Decide whether `interfacer.zig` becomes only a panel-shape renderer or stays fully separate until later.
* Verify the current event system can carry UI click / command events cleanly.

## 2. Core Files

* Create `uiContext.zig`.
* Create `uiNode.zig`.
* Create `uiInput.zig`.
* Create `uiEvent.zig`.
* Create `uiStyle.zig`.
* Create `uiRender.zig`.
* Export the public UI surface through `defs.zig` once the first pieces compile.

## 3. Engine Integration

* Add a UI context / manager field to `Engine`.
* Initialize UI during engine startup.
* Deinitialize UI during engine shutdown.
* In `updateFrame`, collect `UiInput`.
* In `updateFrame`, run UI layout and input dispatch.
* In `renderAll`, draw screen UI inside the overlay phase.
* Add input capture helpers: `wantsMouse`, `wantsKeyboard`, focused id, hovered id.

## 4. Retained Tree

* Add stable `UiId`.
* Add node storage.
* Add parent / child links.
* Add visibility and enabled flags.
* Add node destruction with deferred cleanup.
* Add close propagation for parent-owned children.
* Add dependency links for menu chains.
* Add detach behavior for independent spawned windows.
* Add invariants for parent cycles, dependency cycles, and stale ids.

## 5. Layout

* Implement absolute positioning.
* Implement vertical stack.
* Implement horizontal stack.
* Implement floating roots.
* Store final bounds as `Box2`.
* Add padding, margin, min size, desired size, and max size.
* Defer flex-style layout until at least one real panel exposes the need.

## 6. Input

* Create a per-frame `UiInput` snapshot.
* Resolve mouse hover by layer and depth.
* Resolve click / press / release events.
* Track hovered node.
* Track pressed node.
* Track focused node.
* Track active / captured node.
* Support outside-click close for transient menus.
* Support escape close for menus / popups.

## 7. Rendering

* Add a small renderer interface / module.
* Draw panels.
* Draw labels.
* Draw buttons.
* Draw checkbox / toggle state.
* Add clip region wrappers for scroll areas.
* Add debug drawing for node bounds and focus / hover state.

## 8. First Widgets

* Panel.
* Label.
* Button.
* Checkbox / toggle.
* Slider.
* Scroll area.

## 9. Menus And Popups

* Add dependent submenu.
* Closing an upper menu closes lower dependent menus.
* Opening a sibling submenu closes the old lower branch.
* Add independent spawned window that survives opener closure.
* Add modal popup behavior.
* Add tooltip layer behavior.

## 10. First End-To-End Panel

* Build one minimal debug panel.
* Show static text from a UI definition.
* Show live data through a simple binding or pushed snapshot.
* Click a button and emit an event.
* Let game code handle the event.
* Close and reopen the panel without losing unrelated UI state.

## 11. Later

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

