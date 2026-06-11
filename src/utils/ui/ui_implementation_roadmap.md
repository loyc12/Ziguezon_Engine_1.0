# UI Implementation Roadmap

Roadmap for the retained imperative UI primitive toolkit and the engine-side
manager that orchestrates it.

`ui_implementation_reference.md` is the architecture authority. This roadmap is
the phase-order authority: it records what has been proven, what comes next, and
what remains deferred.

## 0. Direction

Keep these two paths working together:

```text
src/utils/ui
  Panel
  Widget
  configs/defaults
  stable handles
  center-defined Box2 geometry
  pointer/mouse state
  simple layout
  dirty flags
  hit-test helpers
  draw helpers
  query/introspection APIs
```

```text
src/engine/ui
  UiManager
  panel registration
  layers and z-order
  input routing
  capture
  event forwarding
  draw-all orchestration
  debug queries
```

The manager must use the same `Panel` primitives that direct game-owned UI uses.
It should add orchestration without making the simple direct-panel path
mandatory.

## 1. Completed - Primitive Data Model

Goal: create the smallest useful retained object model.

Implemented:

* `UiKey`;
* `UiHandle`;
* `Panel`;
* `Widget`;
* `PanelConfig`;
* `WidgetConfig`;
* `WidgetKind`;
* `WidgetState`;
* `UiPointerState`;
* `UiPointerButton`;
* `UiDirtyFlags`;
* `UiEvent`;
* labels;
* buttons;
* checkboxes;
* spacers;
* containers;
* `customDraw` placeholder kind.

Still deferred from the reference:

* image/sprite widget, unless it becomes trivial in a focused pass;
* domain-specific widgets, which should stay in game code.

## 2. Completed - Geometry And Layout

Goal: make static panels easy to build and inspect.

Implemented:

* requested `Box2`, using center + half-size;
* computed `Box2`, using center + half-size;
* visual offset;
* final `Box2`, using center + half-size;
* absolute, row, column, and stack layout;
* parent-center-relative absolute child boxes;
* manual `panel.updateLayout()`;
* mutation-driven layout/render/hit invalidation;
* panel and widget box queries;
* parent/child count and ordered child queries.

Later:

* flexible spacer growth;
* grid;
* scroll region;
* anchoring helpers;
* splitter;
* docking only if a real use case appears.

## 3. Completed - Rendering

Goal: draw useful static panels with minimal boilerplate.

Implemented:

* panel/background boxes;
* labels;
* button surfaces;
* checkbox surface;
* debug bounds option;
* immediate drawing through existing screen draw helpers;
* render dirty flag.

Deferred:

* render command extraction/cache;
* `interface2D.zig` integration;
* theme-file system.

## 4. Completed - Hit Testing And Local Events

Goal: make the primitive layer interactive without needing the engine manager.

Implemented:

* front-to-back hit testing within one panel;
* centralized mouse/pointer state;
* hovered widget state;
* pressed/captured widget per mouse button;
* pointer position, movement, button transitions, click duration, and hover
  duration;
* clicked events for buttons;
* changed events for checkboxes;
* panel-local event queue;
* hit result and pointer-state queries.

Deferred:

* keyboard focus;
* keyboard/gamepad navigation;
* modal blocking;
* close policy;
* text input.

## 5. Completed - Mutation And Dirty Tracking

Goal: make retained UI practical after creation.

Implemented:

* set text;
* set visibility;
* set enabled;
* set style;
* set requested box;
* set visual offset;
* set checked state;
* add/remove widgets;
* clear panel;
* dirty-flag updates for structure, layout, text, render, and hit data.

Still worth reviewing during polish:

* whether any public mutable pointer access bypasses invalidation in real
  callers;
* whether event behavior is needed for UI-driven remove/clear operations.

## 6. Completed - Text Introspection

Goal: expose enough text state for precise custom drawing.

Implemented:

* measured text size;
* draw origin;
* line height;
* label final text box through `UiTextMetrics`.

Deferred:

* line bounds;
* character/glyph bounds;
* caret position from character index;
* character index from point.

Do not promise per-letter positioning until the text cache stores the data
needed to answer it correctly.

## 7. Completed - Menuer Primitive Sandbox

Goal: prove the primitive layer without requiring the engine manager.

Implemented in `src/games/menuer`:

* direct game-owned panel;
* labels and buttons;
* checkbox;
* row and absolute layout;
* panel rendering;
* button clicks;
* retained text mutation;
* debug boxes from final-box queries;
* text metric queries;
* visual-offset movement.

## 8. Completed - Minimal Engine-Side Manager

Goal: add the smallest engine-side orchestrator without replacing direct
game-owned panels.

Implemented:

* registered game-owned panels;
* panel handles;
* layer/z/order sorting;
* global hit-test across registered panels;
* front-to-back pointer input routing;
* captured panel per mouse button;
* panel-local event forwarding into a manager queue;
* draw-all orchestration;
* panel count/order, hovered panel, and captured panel debug queries;
* overlapping-panel proof in `src/games/menuer`.

Not implemented in this phase:

* manager-owned panel lifetime;
* focus;
* keyboard routing;
* modal blocking;
* close policy;
* persistent windows/popups/tooltips;
* global engine event integration beyond the manager-local forwarded queue.

## 9. Next - Manager Contract Hardening

Goal: make the minimal manager safe enough for later focus, modal, and close
policy work.

Required:

* registration slot reuse and stale-handle tests;
* capability flag tests for visibility, input, and draw behavior;
* routing tests when the top panel is input-disabled;
* capture cleanup when a captured panel is unregistered before release;
* documented `clear()` handle invalidation semantics;
* narrow query surface for the sandbox and tests.

Do not add focus, keyboard routing, modal blocking, or close policy in this
phase.

## 10. Next - Input Consumption Boundary

Goal: expose a small engine/game boundary for mouse consumption without implying
keyboard focus.

Required:

* manager-level mouse-consumption query based on hover, capture, and routed
  events;
* direct `Panel` consumption helper or an explicit decision to keep direct and
  manager helpers separate;
* menuer update to use the settled query surface if it simplifies current local
  helper logic;
* tests for hover, press/capture, release, and disabled-routing consumption
  state.

Keyboard capture stays deferred until focus, text input, or close policy exists.

## 11. Next - Primitive API Polish

Goal: keep the direct imperative API simple for non-frontend callers.

Required:

* review requested/computed/final box naming and aliases;
* document ownership and lifetime rules for game-facing APIs;
* keep `getWidgetPtr()` as an advanced/internal escape hatch;
* review remove/clear semantics and whether local events are useful;
* keep per-character text metrics deferred unless text wrapping or caret work
  starts.

## 12. Later - Stronger Engine UI System

Goal: implement the larger engine responsibilities from the reference only
after the manager contract is stable.

Future engine manager responsibilities:

* manager-owned panel lifetime or ownership transfer;
* focus rules;
* keyboard capture;
* modal blocking;
* close policy;
* persistent windows, popups, and tooltips;
* engine event/command forwarding if the manager-local queue is not enough;
* optional world-space UI routing.

Each item needs its own small design pass before implementation.

## 13. Deferred Widgets And Systems

Defer until the primitive and manager contracts need them:

* text input;
* keyboard navigation;
* gamepad navigation;
* scroll areas;
* dropdowns;
* menu bars;
* tabs;
* tables/lists;
* property inspectors;
* graph widgets;
* docking;
* hot reload;
* theme files;
* world-space UI anchors.

## 14. Validation Strategy

For docs-only changes, no build is required.

For primitive implementation changes:

* run `zig build`;
* run `zig build test` after utility-level changes;
* run the `src/games/menuer` build target once the sandbox is updated;
* do not run `zig fmt`.

Manual validation should focus on whether the API feels easy to use from game
code, not just whether the internals are elegant.
