# Engine UI Manager Design Brief

This brief defines the smallest engine-owned UI manager for the current retained
imperative `Panel` primitives. It orchestrates panels; it does not redefine
widgets or replace the direct game-owned `Panel` path.

## Ownership

The first manager registers game-owned panels by pointer. Games still allocate,
build, mutate, and deinitialize those panels. Registration only stores routing
metadata: handle, key, layer, z, visibility, and input/draw capability flags.

Manager-owned panels can be added later if ownership transfer proves useful, but
that is not part of this slice.

## Handles And Lifetime

Registered panels receive generation-checked `UiPanelHandle` values. Removing a
registration invalidates old handles and leaves the panel itself untouched.
Slot reuse increments generation so stale handles fail lookups.

Panel pointers must remain valid while registered. Games should unregister a
panel before deinitializing it.

## Ordering

Input routes front-to-back. Higher `layer` wins over lower `layer`; within the
same layer, higher `z` wins; if both match, later registration wins.

Drawing uses the opposite order: lower layer/z first, then later surfaces on top.
This keeps draw order and hit order deterministic without sorting panel storage.

## Input Routing

Each update copies the engine mouse snapshot into the routed panel.

- If a button is already captured, that captured panel receives the release for
  that button even when the pointer moved elsewhere.
- Without capture, the topmost visible/input-enabled panel under the pointer
  receives hover and press.
- A press over a routed panel captures that panel for the pressed button until
  release.
- Lower panels do not receive the same pointer event once a top panel is routed.

The manager does not add focus, keyboard routing, modal blocking, close policy,
global hotkey suppression, text input, dragging, or persistent windows.

## Events

Panels keep their local event queues. After routing input, the manager drains
panel-local events into a manager-visible queue containing the source panel
handle and the original `UiEvent`.

Games may either keep using a direct panel's `popEvent()` path or use the
manager's `popEvent()` path for registered panels.

## Drawing

`drawAll()` draws registered, visible, draw-enabled panels in deterministic
back-to-front layer/z order. Overlay phase callers can use it directly.

## Capability Flags

Registration flags are intentionally small:

- `isVisible`: panel is considered for input and drawing.
- `isInputEnabled`: panel may receive pointer routing.
- `isDrawEnabled`: panel is drawn by `drawAll()`.

Widget-level `isVisible` and `isEnabled` keep their existing behavior. This
slice does not add `isClickable`, `isMovable`, or `isActivable`.

## Debug Inspection

The manager exposes panel count/order, hovered panel, captured panel per mouse
button, and queued event count. These are enough for `menuer` to prove routing
and for later debug overlays to inspect manager state.
