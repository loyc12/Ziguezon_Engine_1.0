# UI Implementation Brief

This is the implementation contract for the next retained-mode UI pass after the v0.5 feature layer. It supplements `ui_roadmap.txt` and `todo.md`; keep broader design rationale in the roadmap and status / backlog tracking in the TODO.

## Current Baseline

The retained UI system already has:

* engine-owned `UiManager` / `UiContext` lifecycle
* retained node storage with stable `UiId`
* parent / child ownership and dependency invalidation
* root, panel, label, button, checkbox, popup, window, scroll-area, slider, and tooltip behavior
* HUD, panel, popup, modal, and tooltip layers
* modal blocking, layer-aware hit testing, clipped scroll regions, slider drag capture, tooltip delay, and debug overlay
* UI-local clicked / changed / closed event buffer
* `menuer` sandbox coverage for the current retained controls and input capture

Escape currently closes the frontmost eligible `closeOnEscape` node and sets keyboard capture when that input is consumed. This prevents duplicate game handling when game code checks `wantsKeyboard()` after UI dispatch, but it is not yet a complete focused-menu close policy.

## Scope

Build the next composability / input-policy pass. The goal is to make the current UI surface model easier to reason about and easier to instantiate before adding larger shipped-game widgets.

This pass should focus on:

* auditing `panel`, `popup`, `window`, and `modal` behavior against a smaller surface/options model
* preserving convenient public archetypes / helper constructors for common menu surfaces
* replacing or extending one-off close flags with a compact close-policy / closing-input representation
* guaranteeing one consumed close input produces one UI close action and suppresses duplicate game handling for that frame
* adding UI-local time tracking
* adding delayed activation / input guards for newly spawned popups, modals, and menus
* updating `menuer` so the new behavior is visible and manually testable

Keep the current core architecture: engine-owned manager, retained nodes, `Box2` bounds, simple `sDraw` rendering, UI-local events, and game-facing use through `def.UiManager`.

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
* game `OnFrameUpdate`
* `endFrame`
* game `OnRenderOverlay`
* UI screen draw

Only change this ordering if the new behavior cannot be made correct otherwise, and document the reason in `todo.md`.

Do not integrate retained UI with `src/core/event` in this pass unless the user explicitly changes the scope. The current UI-local event buffer is preferred because it is narrow, already used by `menuer`, and keeps UI command ordering easy to reason about while the global event manager remains mostly unused and insufficiently validated.

Use `Box2` for retained UI layout output, draw bounds, hit testing, overlap checks, clipping decisions, and screen-edge clamping. Prefer `getSize` / `getSizeX` / `getSizeY` over repeated `scale * 2.0` math.

## Style Constraints

Match the existing Zig codebase style and naming patterns, especially from complex /src/utils/*/** and /src/core/*/** files

These are intentionally different from standard Zig, so do not run formatting passes such as `zig fmt`.

Comment non-self-documenting or non-obvious code enough so that a skilled zig coder could understand without extremely domain-specific knowledge

Prefer compact implementations. Extract helpers when they reduce repeated surface / close-policy / time-guard logic, but do not build a broad framework ahead of the current behavior.

Prefer using /src/utils/** utils over local (re)implementation when it makes sense. If no matching util is available, implement it locally for now, but warn the user it could become a util

## Required Work Chunks

### 1. Surface Behavior Audit

Inventory the current behavior differences between panels, popups, windows, modals, detached roots, and floating layout.

Implementation expectations:

* Identify which differences are real behavior differences and which are only defaults, layer, style, or naming.
* Keep separate node kinds only where they have distinct layout, input, or render behavior.
* Keep public names / helpers where they improve call-site readability.
* Do not perform a large rewrite until the audit makes the smaller primitive shape obvious.
* Remove dead or deprecated codeblocks if a consolidation makes them obsolete.

Document any remaining ambiguity in `todo.md`.

### 2. Surface Archetypes / Templates

Add or sketch ergonomic constructors / templates for common menu surfaces.

Implementation expectations:

* A caller should be able to create ordinary panels, transient popups, independent windows, and modals without manually setting every low-level option.
* Archetypes should populate sensible defaults for layer, close policy, modal blocking, movability, dependency ownership, and delayed activation.
* The underlying data should remain composable; avoid baking every menu flavor into a new primitive.
* Keep call sites in `menuer` readable enough to judge whether the API is actually easier to use.

If this is too large to implement cleanly in one pass, first land the option structs / helper shape and update `todo.md` with the remaining migration work.

### 3. Close Policy / Closing Input

Replace or extend `closeOnEscape` / `closeOnOutside` style booleans with a compact close-policy model before adding more one-off flags such as `closeOnEnter`.

Implementation expectations:

* Support at least Escape and outside click.
* Include Enter if it can be added without complicating the model.
* Leave room for explicit close buttons / commands and future custom inputs.
* A consumed close input should close only one eligible UI surface per frame.
* Prefer focused surface first; if focus is absent or unsuitable, use the frontmost eligible transient as the fallback.
* Set keyboard or mouse capture when a close input is consumed so game code cannot also act on the same input.
* Emit the existing closed event behavior unless the event shape needs a small, documented extension.

Do not add full keyboard navigation as part of this work.

### 4. UI Timebase

Add UI-local time tracking to `UiContext` or the manager-owned UI state.

Implementation expectations:

* Track a monotonically increasing UI frame counter.
* Track elapsed seconds only if it is straightforward with the current input/frame data.
* Use the timebase for new delayed activation guards.
* Preserve existing tooltip delay behavior and migrate it to the shared timebase only if that keeps the implementation simpler.
* Keep the timebase UI-owned, not duplicated in `menuer`.

This timebase should be small, but shaped so later animated graphs / transitions can reuse it.

### 5. Delayed Activation / Input Guards

Add configurable delayed activation for newly spawned popups, modals, and menus.

Implementation expectations:

* A surface can ignore close inputs and direct interactions for a configured number of UI frames or seconds after creation.
* The default delay should prevent same-frame accidental close without making normal menus feel sluggish.
* The guard should apply to close-on-outside and close inputs.
* Decide whether hover-only behavior, such as tooltip readiness, should be blocked during the guard and document the result.
* `menuer` should include at least one reachable transient surface that demonstrates the guard.

### 6. Menuer Sandbox

Update `exampleGames/menuer` so the new behavior is visible and manually testable.

The sandbox should demonstrate:

* existing MVP and v0.5 behavior still works
* a popup / modal with delayed activation
* Escape or another close input closes only one eligible UI surface
* game pause / camera / settings-style inputs still respect `wantsMouse` / `wantsKeyboard`
* the new surface archetype helpers are used at least once if implemented

Keep sandbox additions direct and readable. Do not turn `menuer` into a UI framework.

## Non-Goals For This Pass

Do not implement these unless needed to complete the above behavior:

* textual input
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
* full comptime panel definition API
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



# User note on current build ( keep even if empty )
