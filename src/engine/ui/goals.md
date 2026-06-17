# Engine UI Goals

This file is the target-state authority for engine-side UI orchestration.
Current implementation facts belong in [ui_reference.md](ui_reference.md).
Implementation order belongs in [ui_roadmap.md](ui_roadmap.md). Active task
slices belong in [ui_todo.md](ui_todo.md).

## 1. Purpose

The engine UI layer should coordinate UI primitives without replacing the
utility UI system or forcing every game to use a single global UI model.

The target is an engine-owned orchestration layer that can route input, manage
registered surfaces, expose debug state, and eventually support stronger UI
concepts when they are explicitly designed.

## 2. Ownership Boundary

`src/utils/ui` owns primitive UI behavior:

* panels;
* widgets;
* layout;
* geometry;
* primitive hit testing;
* primitive events;
* primitive rendering.

`src/engine/ui` owns engine orchestration:

* registration;
* handles and lifetime policy;
* layer/z/order sorting;
* pointer routing;
* capture;
* manager-level event forwarding;
* draw orchestration;
* engine/game input-consumption boundaries;
* debug queries for engine-facing UI state.

Game code may still use utility panels directly.

## 3. Manager Contract

The manager should make registered game-owned panels reliable before adding
heavier UI concepts.

The contract should preserve:

* generation-checked panel handles;
* stale-handle rejection after unregister and clear;
* independent visible/input/draw capability flags;
* front-to-back pointer routing;
* back-to-front draw routing;
* per-button capture until release;
* capture cleanup when a panel becomes invalid for input;
* a narrow query surface driven by tests and `src/games/menuer`.

Manager-owned panels may be added later only if ownership transfer proves
useful.

## 4. Input Boundary

Engine/game code needs an explicit mouse-consumption boundary so UI interaction
does not also drive camera zoom or other pointer gameplay.

Mouse consumption should be based on manager state such as:

* hovered panel;
* captured panel;
* pending routed events.

Keyboard capture should remain deferred until focus, text input, keyboard
navigation, or close policy exists.

## 5. Event Boundary

Primitive panels keep local event queues.

The manager may forward panel-local events into a manager-visible queue when
central orchestration is useful, but direct game-owned panels must be able to
keep using their local `popEvent()` path.

The manager-local queue should remain separate from engine world/event systems
until a real cross-system dispatch need exists.

## 6. Proof Surface

`src/games/menuer` is the proof surface for engine UI behavior.

It should stay small and focused on:

* direct utility panel usage;
* manager-routed overlapping panels;
* manager route toggles while behavior is being hardened;
* centralized debug readouts for registered panels, capture, hover, event
  counts, and mouse consumption.

Avoid turning `menuer` into a showcase for widgets the engine or utility layer
does not support yet.

## 7. Deferred Features

These require their own design pass before they become manager contract:

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

## 8. Success Condition

The engine can orchestrate registered UI panels predictably, games can still
use utility panels directly, input consumption is explicit, and future focus or
modal work can build on a tested manager contract instead of ad hoc routing.
