# UI Utility Reference

This reference records the current design contract for the reusable UI
primitives in `src/utils/ui` and the utility-specific expansion paths that still
look relevant.

Engine orchestration is documented separately under `src/engine/ui`.

## 1. Purpose

Provide a compact retained imperative UI primitive layer that can be used
directly from game, tool, or debug code without requiring an engine-owned UI
manager.

The utility layer is responsible for one-panel primitive behavior:

* widget storage and stable widget handles;
* center-defined `Box2` geometry;
* simple layout;
* panel-local mouse state;
* panel-local events;
* hit testing;
* text metrics;
* direct drawing through existing screen draw helpers;
* handle-based mutation and introspection.

The utility layer must remain engine-agnostic. It may expose generic data that
the engine can route or inspect, but it must not own engine policy such as
cross-panel ordering, focus, modal state, global input capture, or persistent
window management.

## 2. Direct Panel Usage

The core public path is direct ownership of a `Panel`:

```zig
var panel = try utl.Panel.init(
  alloc,
  .{
    .key    = utl.uiKey( "main_panel" ),
    .box    = box,
    .config = .{ .layout = .column },
  }
);
defer panel.deinit();

const button = try panel.addButton(
  .{
    .key  = utl.uiKey( "confirm" ),
    .text = "Confirm",
  }
);

panel.updateInput( mouse );

while( panel.popEvent() )| event |
{
  if( event.isClicked( button )){ confirm(); }
}

panel.draw();
```

Callers create panels and widgets when needed, mutate them through handles, and
let dirty flags decide which caches are refreshed. The API is retained, but it
is not a declarative rebuild-every-frame system.

## 3. Public Shape

`panel.zig` defines the current primitive surface:

* `UiKey`: stable caller-facing identity;
* `UiHandle`: generation-checked widget identity;
* `Panel`: top-level primitive container;
* `Widget`: internal retained widget storage;
* `PanelConfig` and `WidgetConfig`: sparse creation defaults;
* `WidgetKind`: label, button, checkbox, spacer, container, and custom draw;
* `WidgetState`: durable visibility, enabled, and checked state;
* `UiDirtyFlags`: structure, layout, text, render, and hit invalidation;
* `UiEvent`: panel-local clicked and changed events;
* `UiTextMetrics`: measured size, draw origin, line height, and text box.

`mouser.zig` defines the engine-agnostic mouse state used by panels:

* `Mouse`;
* `MouseButton`;
* `MouseButtonState`;
* `MouseModifier`;
* `MouseModifierState`;
* `MouseUiTarget`.

`Mouse` can carry optional world position, but utility UI only requires screen
position and button transitions.

## 4. Ownership And Lifetime

Panels are caller-owned values. `Panel.init()` creates an empty panel using the
provided allocator, and `Panel.deinit()` releases the panel's widget, hit-test,
and event storage.

Widget handles are the normal way to mutate or inspect widgets after creation.
Raw mutable widget pointer access is internal so callers cannot bypass dirty
flag maintenance. If a caller needs a new mutation path, add a narrow
handle-based setter or query instead of exposing storage internals.

`Panel.clear()` removes all widgets and queued events while retaining
allocations. `removeWidget()` removes a single widget by handle. Both operations
are caller-directed storage mutation and do not emit events.

## 5. Geometry

UI primitives use the repository's native `Box2` convention:

```zig
center : Vec2, // center position
scale  : Vec2, // half-size / side distance from center
```

Core storage, layout results, and queries should stay center-defined. Top-left
helpers are allowed as convenience constructors only.

Widgets distinguish these geometry roles:

* `requestedBox`: caller request or local absolute box;
* `computedBox`: layout result before visual offset;
* `visualOffset`: manual movement after layout;
* `finalBox`: rendered and hit-tested box.

This keeps automatic layout compatible with small animation or manual nudging.

## 6. Layout

The current layout set is intentionally small:

* `absolute`: root children are screen-space; child widgets are parent-center
  relative;
* `column`: stack children vertically;
* `row`: stack children horizontally;
* `stack`: overlay children in one region.

Layout arranges existing widgets. It should not decide whether game-specific
widgets exist. Callers should use ordinary Zig functions, branches, and loops to
create or mutate UI.

Layout mutation should mark layout, render, and hit caches dirty. Structural
mutation should also mark text state dirty when parent/child order or visibility
can affect cached text layout.

## 7. Input And Events

`Panel.updateInput()` consumes an engine-agnostic `Mouse` snapshot and updates
panel-local pointer state:

* hovered widget;
* per-button pressed widget;
* hover duration;
* button press/release transitions.

Buttons emit `clicked` when press and release happen over the same button.
Checkboxes toggle durable checked state and emit `changed` on release over the
same checkbox.

Events stay in the panel-local queue until `popEvent()` or `clearEvents()`
removes them. Direct panel users should prefer the local event queue. Engine
code may drain it into a manager-level queue, but that forwarding policy is not
owned by the utility layer.

`Panel.wantsMouse()` reports primitive local mouse consumption from hovered or
pressed widget state. It does not imply engine focus, keyboard capture, modal
state, or hotkey suppression.

## 8. Rendering

The current renderer draws immediately through existing screen draw helpers:

* panel background;
* labels;
* button surfaces and text;
* checkbox surfaces, marks, and text;
* optional debug bounds.

Rendering should remain simple until a concrete utility caller needs more.
Render command extraction or stronger render caches are utility features only if
they improve direct primitive use; engine layering alone belongs in
`src/engine/ui`.

## 9. Introspection

The utility API should keep primitive state observable through narrow
handle-based queries:

* panel box;
* widget kind;
* widget text;
* requested, computed, and final widget boxes;
* text metrics;
* hovered and pressed widget handles;
* pointer state;
* hit-test result at a point;
* parent/child relation and child order;
* dirty/debug state;
* local event count.

Do not promise per-character text metrics until the text cache stores enough
data to answer them correctly.

## 10. Future Expansion

No immediate utility-side implementation work is planned. Future work should
come from a concrete direct-panel caller or from engine-side experience that
exposes a primitive-only API gap.

Relevant utility-specific avenues:

* richer text metrics, such as line bounds, glyph bounds, caret lookup, and
  point-to-character lookup;
* primitive text wrapping and clipping for bounded labels;
* flexible layout helpers, such as growable spacers, min/max desired sizes,
  simple anchors, or a small grid;
* primitive scroll-region data and hit testing before any engine-level scroll
  policy is added;
* optional render-command extraction if immediate drawing becomes limiting for
  direct utility callers;
* image or sprite widgets if they can stay thin wrappers around existing render
  primitives;
* narrow handle-based setters and queries when real callers need mutation that
  would otherwise require raw widget access;
* local remove/clear events only if utility UI itself starts removing widgets in
  response to user actions.

Keep these expansions engine-agnostic, handle-based, and compatible with direct
game-owned `Panel` usage.

## 11. Engine Boundary

Engine-side UI can use these primitives, but should own orchestration:

* panel registration and `UiPanelHandle` lifetime;
* layer/z ordering across panels;
* cross-panel pointer routing;
* captured panel cleanup;
* manager-level event forwarding;
* manager debug panels and readouts;
* global input consumption policy;
* focus, modal, close-policy, and persistent-window planning.

If engine work suggests a better primitive API, document the engine-side need
first and move only the engine-agnostic part into `src/utils/ui`.

## 12. Non-Goals

Do not turn `src/utils/ui` into a full UI framework without a concrete utility
caller. In particular, avoid adding:

* engine panel registration;
* global input policy;
* focus rules;
* keyboard capture;
* keyboard/gamepad navigation;
* modal blocking;
* close policy;
* persistent windows, popups, or tooltips;
* dropdowns and menu bars;
* tables, lists, or property inspectors;
* docking;
* hot reload;
* theme files;
* domain-specific widgets.

Do not depend on `interface2D.zig` unless that visual experiment is explicitly
reopened.

## 13. Validation

Docs-only changes need no build.

Utility implementation changes should run:

```sh
zig build
zig build test
```

If a utility change also alters the visible `menuer` proof surface, also run:

```sh
zig build -Dengine_adapter_path=src/games/menuer/engineAdapter.zig -Dexecutable_name=ui_menuer_test
```

Do not run formatting passes such as `zig fmt`.
