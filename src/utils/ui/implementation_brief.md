# UI Implementation Brief

This is the implementation contract for the next retained-mode UI pass after the MVP. It supplements `ui_roadmap.txt` and `todo.md`; keep broader design rationale in the roadmap and status / backlog tracking in the TODO.

## Scope

Build a v0.5 retained UI feature layer: enough core behavior to make the UI useful for real debug panels, without attempting a full shipped-game widget suite.

This pass should add:

* explicit UI layers
* layer-aware input routing and draw order
* modal input blocking
* scissor / clip helpers for screen UI
* first scroll-area node
* first slider node with drag capture
* tooltip layer behavior
* compact debug overlay for retained UI internals
* stronger `menuer` sandbox coverage for both old and new behaviors

Keep the current MVP architecture: engine-owned manager, retained nodes, `Box2` bounds, simple `sDraw` rendering, UI-local events, and game-facing use through `def.UiManager`.

Treat `interfacer.zig` as a deprecated/stub visual experiment. Do not read from it, refactor it, depend on it, or route rendering through it unless the user explicitly asks for that later.

## Location

All new retained UI implementation files should live under `src/utils/ui/`.

Allowed supporting edits:

* `src/defs.zig` exports for new UI types / helpers
* `src/core/engine/engineCore.zig` only if manager storage changes
* `src/core/engine/engineState.zig` only if init / deinit changes
* `src/core/engine/engineStep.zig` only if frame order must change
* `exampleGames/menuer/*` for the behavior sandbox

Ask before making major structural changes outside those areas.

## Engine Integration Constraints

Do not move UI ownership out of `Engine.uiManager`.

The frame sequence should stay:

* `beginFrame`
* `updateLayout`
* `dispatchInput`
* game `OnUpdateFrame`
* `endFrame`
* game `OnRenderOverlay`
* UI screen draw

Only change this ordering if the new behavior cannot be made correct otherwise, and document the reason in `todo.md`.

Do not integrate retained UI with `src/core/event` in this pass unless the user explicitly changes the scope. The current UI-local event buffer is preferred for v0.5 because it is narrow, already used by `menuer`, and keeps UI command ordering easy to reason about while the global event manager remains mostly unused and insufficiently validated.

Use `Box2` for retained UI layout output, draw bounds, hit testing, overlap checks, clipping decisions, and screen-edge clamping. Its min/max, size, `isOnPoint`, overlap, `clampIn`, `clampOn`, and `clampOut` semantics are suitable for this pass and covered by focused Box2 tests.

## Style Constraints

Match the existing Zig codebase style and naming patterns, especially from complex /src/utils/*/** and /src/core/*/** files

These are intentionally different from standard Zig, so do not run formatting passes such as `zig fmt`.

Comment non-self-documenting or non-obvious code enough so that a skilled zig coder could understand without extremely domain-specific knowledge

Prefer compact implementations. Extract helpers when they reduce repeated layer / clipping / hit-test logic, but do not build a broad framework ahead of the current widgets.

Prefer using /src/utils/** utils over local (re)implementation when it makes sense. If no matching util is available, implement it locally for now, but warn the user it could become a util

## Required Work Chunks

### 1. Layers

Add explicit layer data to the UI system.

Minimum layer set:

* HUD
* panel
* popup
* modal
* tooltip

Implementation expectations:

* Each node has a layer or belongs to a root that has a layer.
* Rendering draws lower layers first and tooltip last.
* Hit testing scans higher input-capable layers first.
* A modal node blocks hit tests to lower layers and non-descendant nodes behind it.
* Existing MVP nodes keep their current behavior when no explicit layer is provided.

Avoid a full multi-root rewrite unless it clearly simplifies the implementation. A compact layer field plus ordered scans is acceptable.

### 2. Clip And Scroll

Add a minimal clipping abstraction around raylib scissor mode for screen UI.

Implementation expectations:

* Add begin / end clip helpers with a small fixed-depth or array-backed stack.
* Add a `scrollArea` node kind or equivalent flag.
* Scroll areas clip their children to their bounds.
* Mouse wheel over a scroll area changes a stored vertical scroll offset.
* Child layout inside a scroll area is offset by the scroll value.
* Clamp scroll offset to a sensible range based on content height.

Do not implement horizontal scroll unless it falls out naturally.

### 3. Slider

Add a simple horizontal slider widget.

Implementation expectations:

* Store min, max, current value, and step or no-step mode.
* Pressing and dragging captures the mouse until release.
* Dragging emits `changed` events when the value changes.
* Slider rendering must show track, fill, and handle.
* `menuer` must demonstrate the slider driving a visible value label.

Keep value storage simple and numeric. Do not add generic typed bindings yet.

### 4. Tooltips

Add tooltip behavior as a top-layer UI feature.

Implementation expectations:

* Nodes can carry tooltip text.
* Hovering a node for a short delay shows a tooltip node or tooltip draw path.
* Tooltips render above all normal UI and do not receive input.
* Tooltip position follows the mouse with screen-edge clamping.
* Moving off the node hides the tooltip.

Use fixed text buffers consistent with the current node text approach. Do not add rich text.

Use Box2 helpers for tooltip bounds when they make the code clearer. Prefer `getSize` / `getSizeX` / `getSizeY` over repeated `scale * 2.0` math.

### 5. Debug Overlay

Add an optional compact debug overlay for retained UI state.

Implementation expectations:

* Toggleable from `menuer`.
* Shows node count, live node count, event count, hovered kind, focused kind, pressed kind, wants mouse, wants keyboard, and active modal state.
* Optionally draws layer-colored bounds for visible nodes.
* Must not create UI events or capture input while only displaying state.

This can live in `UiContext` or a small helper file. Keep it simple.

### 6. Menuer Sandbox

Update `exampleGames/menuer` so the new behavior is visible and manually testable.

The sandbox should demonstrate:

* existing MVP panel / button / checkbox / popup / independent window behavior still works
* layered popup above panel
* modal blocking lower UI
* scroll area with clipped overflowing content
* slider changing a label
* tooltip on at least two controls
* debug overlay toggle
* camera and pause inputs still respect `wantsMouse` / `wantsKeyboard`

## Non-Goals For This Pass

Do not implement these unless needed to complete the above behavior:

* text input
* clipboard
* gamepad navigation
* full keyboard navigation
* dropdowns
* menu bars
* tabs
* tables
* charts / graph widgets
* property inspectors
* hot-reloadable panel definitions
* comptime panel definition API
* world-space UI / anchors
* engine event system integration
* `interfacer.zig` bevel / shape integration
* any cleanup, replacement, or partial integration of `interfacer.zig`
* advanced theme files

## Validation

Required checks:

* `zig build -Dengine_interface_path=exampleGames/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test`
* `zig build`
* `zig build test` after touching utility code such as `Box2`

Do not run `zig fmt`.

Also manually inspect the `menuer` sandbox if a graphical run is available. At minimum, the code should make each new behavior reachable from the sandbox without hidden setup.
