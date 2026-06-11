# UI TODO

Next steps for the retained imperative UI primitive rewrite.

`ui_implementation_reference.md` is the architecture authority. The roadmap is
the phase-order authority. This TODO should stay narrower than either file: it
tracks the next implementation slices, not every future UI ambition.

## 0. Current Baseline

The primitive layer is now usable without an engine manager:

* `src/utils/ui/panel.zig` owns `Panel`, `Widget`, stable handles, sparse
  configs, dirty flags, layout, child order, hit testing, local events,
  rendering, text metrics, checkbox state, and handle-based introspection.
* `src/utils/ui/mouser.zig` owns engine-agnostic mouse/pointer state, button
  state, modifier state, packed UI targets, hover timing, and per-button widget
  capture.
* `src/utils/utilsDef.zig` exports the primitive UI surface, including
  `UiTextMetrics`.
* `src/games/menuer` is a game-owned primitive UI testbed that demonstrates a
  direct panel, row layout, absolute child placement, button and checkbox
  events, retained text mutation, visual offset movement, final-box queries,
  debug bounds, and text metric queries.
* `eng.Engine` owns mouse state but does not own a UI manager.
* The old retained `UiContext` implementation has been removed. Do not revive
  the old manager-first architecture.

## 1. Immediate Guardrails

* Preserve center-defined `Box2` semantics for all primitive storage and query
  results.
* Keep top-left helpers as convenience constructors only.
* Keep UI logic in game/user code; do not add a layout scripting language.
* Keep `interface2D.zig` out of this pass unless explicitly reopened.
* Keep the primitive event queue local to `Panel` until a global dispatch path is
  validated and needed.
* Do not run formatting passes such as `zig fmt`.
* Validate implementation changes with:
  * `zig build`
  * `zig build test` after utility-level logic changes
  * `zig build -Dengine_interface_path=src/games/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test` after sandbox or UI-surface changes

## 2. Next Slice - Primitive Stabilization

Goal: lock down the primitive contract before engine-side orchestration depends
on it.

Tasks:

* Add focused tests or equivalent low-friction checks for:
  * `UiHandle` generation reuse after `removeWidget()`;
  * `MouseUiTarget` packing/unpacking round trips;
  * child draw order and front-to-back hit-test order;
  * `moveWidgetToSiblingIndex()`, `bringWidgetForward()`, and
    `sendWidgetBackward()`;
  * absolute root boxes using screen-space center-defined boxes;
  * absolute child boxes using parent-center-relative local boxes;
  * disabled and hidden widgets being skipped by hit testing;
  * press/release on the same interactive widget being required for click or
    changed events;
  * modifier left/right press timers being tracked separately instead of using
    one aggregate held-time value;
  * text changes dirtying text/render caches without forcing layout unless
    text-driven layout is introduced.
* Review whether `getWidgetCount()` should keep counting storage slots or gain
  an alive-widget companion query.
* Decide whether `getWidgetBox()` should stay as the computed-box name or be
  renamed/aliased to `getWidgetComputedBox()` for clarity.
* Keep `getWidgetPtr()` available but documented as advanced/internal; do not
  make mutable pointer access the normal user path.
* Recheck public doc comments after any naming or query changes.

## 3. Next Slice - Engine Manager Design Brief

Goal: specify the smallest engine-owned UI manager that orchestrates `Panel`
without redefining widgets.

Tasks:

* Write a compact design brief before implementation. Cover:
  * panel ownership versus panel registration;
  * panel handles/ids and lifetime rules;
  * layer and z-order sorting;
  * front-to-back input routing across panels;
  * how shared mouse state is copied into panels;
  * which panel receives capture while a button is held;
  * how panel-local events are drained and exposed to engine/game code;
  * draw-all ordering in the overlay phase;
  * which capability flags belong on panels, widgets, or manager registrations;
  * debug inspection needs.
* Review capability flags before adding them. Preserve the existing
  `isVisible` / `isEnabled` behavior, consider clearer input names such as
  `isInputEnabled` or `isInteractive` before adding `isClickable`, defer
  `isMovable` until dragging/window movement exists, and do not add
  `isActivable` without first defining what activation means.
* Keep focus, keyboard navigation, modal blocking, close policy, text input, and
  persistent windows out of the first manager implementation.
* Preserve the direct game-owned `Panel` path. The manager is convenience and
  orchestration, not a mandatory UI singleton.

## 4. Next Slice - Minimal Engine Manager

Goal: implement the smallest manager that proves multi-panel orchestration.

Tasks:

* Add an engine-side manager type built on existing `Panel` primitives.
* Support registered game-owned panels first, unless ownership transfer is
  clearly simpler.
* Store panel layer/z metadata separately from `Panel`.
* Route pointer input front-to-back:
  * topmost hit panel receives hover;
  * pressed/captured panel continues receiving release for that button;
  * lower panels do not receive the same pointer event once consumed.
* Drain panel-local events into a manager-visible queue or iterator.
* Draw registered panels in deterministic layer/z order.
* Expose minimal manager queries:
  * hovered panel;
  * captured panel per mouse button;
  * event count or event drain;
  * debug panel count/order.
* Do not add modal, popup, close-policy, focus, keyboard, or global hotkey
  suppression in this slice.

## 5. Menuer Manager Proof

Goal: keep `src/games/menuer` as proof that both direct and manager-routed UI are
easy to use.

Tasks:

* Keep the current direct primitive panel example small.
* Add a second panel or route that goes through the engine manager once it
  exists.
* Keep the game-owned implementation available behind a toggleable flag while
  building the engine-owned UI beside it. Use this as an A/B proof that the
  manager improves orchestration without replacing the simple direct-panel path.
* Demonstrate:
  * two overlapping panels with deterministic layer/z behavior;
  * front-to-back hit routing;
  * capture surviving pointer movement outside the original widget until
    release;
  * event forwarding from panel-local events;
  * draw-all ordering;
  * debug readout for hovered/captured panel.
* Do not recreate stale popup/modal/slider/window demos until the primitive or
  manager layer actually supports those concepts.

## 6. TODO Comment Review

Live TODO comments found in implicated files:

* `src/utils/ui/mouser.zig`: `// TODO : split into individualize left and right
  press timers`
  * Handling: address in the primitive stabilization slice.
  * Reason: the mouse buttons already have independent `MouseButtonState`
    storage, and modifier sides should follow the same intuitive rule instead
    of aggregating timing across left/right keys.
  * Remove the code TODO after the timer split is implemented and validated.

## 7. Deferred Features

Do not pull these into the next slices unless the reference or roadmap is
updated:

* text input;
* keyboard/gamepad navigation;
* scroll areas;
* dropdowns and menu bars;
* tabs;
* tables/lists/property inspectors;
* graph widgets;
* docking;
* hot reload;
* theme files;
* world-space UI anchors;
* global engine event integration;
* modal blocking;
* close policy;
* persistent windows/popups/tooltips.
