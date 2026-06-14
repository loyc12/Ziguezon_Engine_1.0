# Engine UI Reference

This file is the descriptive baseline for engine-side UI orchestration.
Target design belongs in [ui_goals.md](ui_goals.md). Implementation order
belongs in [ui_roadmap.md](ui_roadmap.md). Active task slices belong in
[ui_todo.md](ui_todo.md).

This file is functionally independent from `src/utils/ui/reference.md`: the
engine may use the utility primitives, but engine policy, routing, and lifecycle
decisions live here.

## 1. Scope

`src/engine/ui` owns the coordination layer above game-owned or future
engine-owned UI primitives:

* panel registration;
* generation-checked panel handles;
* layer, z, and registration-order sorting;
* front-to-back pointer routing;
* per-button panel capture;
* manager-level event forwarding;
* draw ordering;
* manager debug queries;
* engine/game input-consumption boundaries.

The engine layer does not redefine widgets, layouts, primitive hit testing, text
metrics, or primitive drawing. Those remain utility concerns.

## 2. Current Surface

`src/engine/ui/uiManager.zig` provides the current minimal manager.

Registered panels are game-owned. The manager stores only registration metadata:

* key;
* `UiPanelHandle`;
* layer and z;
* registration order;
* visibility, input, and draw capability flags;
* pointer to the registered `Panel`.

Games must keep a registered panel alive until it is unregistered or the manager
is cleared/deinitialized.

## 3. Handles And Lifetime

`UiPanelHandle` identifies a manager registration, not ownership of a `Panel`.
It is generation checked:

* unregistering a panel invalidates its handle;
* reusing a dead slot increments generation;
* stale handles must not resolve after slot reuse;
* clearing the manager must invalidate outstanding handles.

The current intended `clear()` behavior is to preserve storage capacity but mark
all slots dead and bump their generations. This keeps allocations reusable while
invalidating handles.

Manager-owned panels can be added later only if ownership transfer proves useful.
That is not part of the current manager contract.

## 4. Ordering

Input routes front-to-back:

1. higher `layer`;
2. higher `z`;
3. later registration order.

Drawing routes back-to-front:

1. lower `layer`;
2. lower `z`;
3. earlier registration order.

Draw-order queries should expose only what `menuer`, tests, or debug panels
need. Avoid broad inspection APIs without a concrete caller.

## 5. Capability Flags

Registration flags are independent:

* `isVisible`: panel is eligible for input and draw;
* `isInputEnabled`: panel can receive pointer input while still drawing;
* `isDrawEnabled`: panel can receive input while skipped by `drawAll()`.

Invisible panels should not receive input or draw. Input-disabled panels should
still draw. Draw-disabled panels should still be eligible for input when visible
and input-enabled.

## 6. Pointer Routing And Capture

Each manager input update receives the engine mouse snapshot and routes it to
registered panels:

* without capture, the topmost visible/input-enabled panel under the pointer
  receives hover and press;
* if a button is captured, the captured panel receives updates until release;
* a press over a routed panel captures that panel for the pressed button;
* release clears capture for that button;
* unregistering, hiding, or input-disabling a captured panel clears its capture;
* lower panels do not receive the same pointer event once a top panel is routed.

This is still pointer routing only. It does not imply focus, keyboard capture,
modal blocking, close policy, dragging, or text input.

## 7. Events

Panels keep their local event queues. After routing input, the manager may drain
panel-local events into a manager-visible queue containing:

* source panel handle;
* original primitive `UiEvent`.

Direct game-owned panels can keep using their local `popEvent()` path. Registered
panels can use the manager event path when central orchestration is useful.

The manager-local queue remains separate from the engine world/event systems
until a real cross-system dispatch need exists.

## 8. Mouse Consumption Boundary

Engine/game code needs an explicit mouse-consumption query so UI interactions do
not also drive camera zoom or other pointer gameplay.

The direct utility `Panel.wantsMouse()` helper is primitive-only. The
manager-level query should use the same broad shape while being based only on
current manager state:

* hovered panel;
* captured panel;
* pending routed events.

Do not add `wantsKeyboard()` until focus, text input, keyboard navigation, or
close policy exists. Mouse consumption does not suppress keyboard hotkeys by
itself.

Any API improvement learned from manager-side usage should be documented here
first, then moved into `src/utils/ui` only if it remains engine-agnostic.

## 9. Menuer Proof Surface

`src/games/menuer` is the engine UI proof surface. It should stay small:

* keep the direct utility `Panel` visible;
* keep manager-routed overlapping panels;
* keep a manager route toggle while contract behavior is being hardened;
* centralize manager/mouse readouts in a debug panel when needed;
* avoid popup, modal, window, dropdown, slider, and text-input demos until the
  engine or utility layer actually supports those concepts.

## 10. Deferred Engine Features

Do not pull these into the manager contract until their own design pass exists:

* manager-owned panel lifetime;
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
* theme-file loading.

## 11. Validation

Docs-only changes need no build.

Engine UI implementation changes should run:

* `zig build`;
* `zig build test`;
* `zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test`
  when the sandbox or visible UI surface changes.

Do not run formatting passes such as `zig fmt`.
