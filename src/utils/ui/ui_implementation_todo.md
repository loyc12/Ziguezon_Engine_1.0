# UI TODO

Next steps for the retained imperative UI primitive rewrite.

`ui_implementation_reference.md` is the architecture authority. The roadmap is
the phase-order authority. This TODO should stay narrower than either file: it
tracks the next implementation slices, not every future UI ambition.

## 0. Current Baseline

The first primitive slice exists:

* `src/utils/ui/panel.zig` owns `Panel`, `Widget`, handles, configs, dirty
  flags, layout, hit testing, events, rendering, and basic introspection.
* `src/utils/ui/mouser.zig` owns engine-agnostic mouse/pointer state, button
  state, modifier state, UI targets, hover timing, and click timing.
* `src/utils/utilsDef.zig` exports the primitive UI surface.
* `eng.Engine` owns mouse state but no longer owns an engine UI manager.
* `src/games/menuer` is a game-owned primitive UI testbed.
* The old retained `UiContext` implementation has been removed.

Do not revive the old manager-first architecture. Engine-side UI management is a
later subsystem built on these primitives.

## 1. Immediate Guardrails

* Preserve center-defined `Box2` semantics for all primitive storage and query
  results.
* Keep top-left helpers as convenience constructors only.
* Keep UI logic in game/user code; do not add a layout scripting language.
* Keep `interface2D.zig` out of this pass.
* Do not run formatting passes such as `zig fmt`.
* Validate implementation changes with:
  * `zig build`
  * `zig build test` after utility-level logic changes
  * `zig build -Dengine_interface_path=src/games/menuer/engineInterface.zig -Dexecutable_name=ui_menuer_test` after sandbox or UI-surface changes

## 2. Next Slice - Primitive API Hardening

Goal: make the existing primitive API safer and easier to use before adding more
widgets.

Tasks:

* Audit public names in `panel.zig` and `mouser.zig` for consistency.
* Decide whether `mouser.zig` should remain named that way or be renamed to
  `mouse.zig`; update exports only if the rename is worth the churn.
* Add doc comments to public primitive types and public game-facing methods
  whose behavior is not obvious.
* Add convenience queries:
  * `getWidgetRequestedBox()`
  * `getWidgetText()`
  * `isWidgetAlive()`
  * `isWidgetVisible()`
  * `getDebugDrawBounds()`
* Add event helpers:
  * `clearEvents()`
  * `peekEventCount()` or keep `getEventCount()` if that name is preferred
  * `wasClicked( handle )` only if its queue semantics are clear and documented
* Avoid exposing mutable widget pointers as the normal user path.
* Keep any direct pointer access clearly marked as advanced/internal.

## 3. Next Slice - Layout And Child Order

Goal: make static panels predictable enough to compose without inspecting
internal arrays.

Tasks:

* Define and document child ordering rules for draw order and hit-test order.
* Add child iteration or ordered child collection without exposing raw storage.
* Add child count by parent if the current count helper is not enough.
* Confirm absolute children of a container use center-relative local boxes.
* Confirm root absolute widgets use screen-space center-defined boxes.
* Add a simple reorder API if needed:
  * bring widget forward/backward within its parent, or
  * move widget to explicit sibling index.
* Add layout mutation helpers if missing:
  * set panel box
  * set panel layout
  * set widget layout/config fields that affect layout
  * set widget enabled/interactivity state
* Recheck dirty rules for structure, layout, text, render, and hit caches after
  each mutation.

## 4. Next Slice - Text Cache And Introspection

Goal: expose useful text state without pretending per-character layout exists
before it is actually cached.

Tasks:

* Replace the current single `textSize` cache with a small text metrics struct
  if that makes queries clearer.
* Expose:
  * measured text size
  * text draw origin
  * line height
  * final text box or label text box
* Document how label alignment affects draw origin.
* Keep per-character/glyph bounds deferred until the text cache stores enough
  data to answer accurately.
* Ensure text changes dirty only the needed caches.
* Add one menuer debug readout that proves text metrics can be queried.

## 5. Next Slice - Input Correctness

Goal: make panel-local input dependable enough that an engine manager can later
route the same state front-to-back across panels.

Tasks:

* Audit `MouseUiTarget` packing and unpacking against `UiHandle` generation
  behavior.
* Ensure pressed/captured widget state survives across frames until release.
* Track and expose pressed handle per mouse button.
* Confirm hover duration resets only when hovered panel/widget changes.
* Confirm click events only fire when press and release happen on the same
  interactive widget.
* Decide whether disabled widgets should block hit testing or be skipped.
* Add right and middle button capture behavior if it is trivial and does not add
  policy complexity.
* Keep focus, keyboard navigation, modal blocking, and global capture out of the
  primitive layer for now.

## 6. Next Slice - Widget Set

Goal: add only the next primitive widgets that materially improve static UI
composition.

Tasks:

* Consider adding `checkbox` now that button/label/container behavior exists.
* If checkbox is added:
  * store checked state as durable widget state;
  * add `setChecked()` / `getChecked()`;
  * emit `changed`;
  * draw a simple checked/unchecked surface;
  * add a menuer example.
* Consider adding image/sprite only if existing render helpers make it cheap.
* Do not add sliders, scroll areas, text input, tabs, lists, docking, or theme
  files in this slice.

## 7. Menuer Testbed Updates

Goal: keep `src/games/menuer` as proof that the API is easy to use directly from
game code.

Tasks:

* Keep the sandbox small and rebuild examples from scratch when stale.
* Demonstrate:
  * one direct game-owned panel;
  * label and button;
  * row or column layout;
  * absolute child placement if layout rules are touched;
  * click event handling;
  * text mutation after click;
  * visual offset movement;
  * final box query and debug drawing;
  * text metrics query once implemented.
* Do not recreate stale popup/modal/slider/window demos until the primitive or
  engine-manager layer actually supports those concepts.

## 8. Engine-Side Context To Preserve

Do not implement this in the current primitive pass. Keep these notes for the
later engine subsystem review:

* `eng.Engine` may later own an optional UI manager built on `Panel`.
* The manager should own panel lifetime or panel registration, not redefine
  widgets.
* The manager should sort panels by layer/z.
* The manager should route input front-to-back into shared mouse/pointer state.
* The manager should own global capture, focus, modal blocking, and close
  policy.
* The manager should drain panel-local events and expose engine-facing events.
* Game-owned panels must remain valid for simple/manual use.

## 9. Deferred Features

Do not pull these into the next slice unless the reference or roadmap is updated:

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
* global engine event integration.
