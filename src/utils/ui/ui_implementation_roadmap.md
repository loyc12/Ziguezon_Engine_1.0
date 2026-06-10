# UI Implementation Roadmap

Roadmap for replacing the previous retained-manager-first UI plan with a
retained imperative primitive toolkit.

The immediate target is not a full engine UI manager. The immediate target is a
small, reusable primitive layer that can be owned directly by a game or later
orchestrated by an engine-side UI subsystem.

## 0. Direction

Build this first:

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

Build this later:

```text
src/engine/...
  UI manager
  layers
  input routing
  focus/capture
  modal/close policy
  engine event forwarding
  panel lifetime orchestration
```

The current `UiContext` implementation may be mined for behavior, but it should
not constrain the new shape.

## 1. Phase One - Primitive Data Model

Goal: create the smallest useful retained object model.

Required pieces:

- `UiKey` for stable user-provided identity.
- `UiHandle` as index + generation or equivalent.
- `Panel`.
- `Widget`.
- `PanelConfig`.
- `WidgetConfig`.
- `WidgetKind`.
- `WidgetState`.
- `UiPointerState`.
- `UiPointerButton`.
- `UiDirtyFlags`.
- `UiEvent`.

Initial widget kinds:

- label;
- button;
- checkbox only if cheap;
- spacer;
- container;
- custom draw placeholder if it does not complicate storage.

Expected API shape:

```zig
var panel = try ui.Panel.init( alloc, .{
  .key    = ui.key( "main" ),
  .box    = box,
  .config = .{},
});

const title = try panel.addLabel( .{
  .key  = ui.key( "title" ),
  .text = "Market",
});

const buy = try panel.addButton( .{
  .key  = ui.key( "buy" ),
  .box  = buyBox,
  .text = "Buy",
});
```

Do not add engine ownership in this phase.

## 2. Phase Two - Geometry And Layout

Goal: make static panels easy to build and inspect.

Required geometry:

- requested `Box2`, using center + half-size;
- computed `Box2`, using center + half-size;
- visual offset;
- final `Box2`, using center + half-size;
- parent/child local coordinate rules.

Do not make top-left + width/height the primary primitive representation.
Convenience helpers are fine, but the primitive storage and API should match
`Box2`.

Required layouts:

- absolute;
- row;
- column;
- stack;
- spacer support if straightforward.

Required queries:

- `panel.getBox()`;
- `panel.getWidgetBox( handle )`;
- `panel.getWidgetFinalBox( handle )`;
- `panel.getParent( handle )`;
- `panel.getChildren( handle )` or iterator equivalent.

Layout should be manually callable:

```zig
panel.updateLayout();
```

Mutations should mark layout dirty automatically, so the caller does not need to
track invalidation details.

## 3. Phase Three - Rendering

Goal: draw useful static panels with minimal boilerplate.

Required drawing:

- panel/background boxes;
- labels;
- button surfaces;
- checkbox surface if implemented;
- debug bounds option.

Rendering can initially draw immediately through existing `sDraw` helpers. A
render command cache can wait until it is needed.

Required render optimization:

- `renderDirty` flag;
- text cache or measured text data;
- no recomputation of stable geometry/text unless dirty.

Do not integrate `interface2D.zig` yet.

## 4. Phase Four - Hit Testing And Local Events

Goal: make the primitive layer interactive without needing the engine manager.

Required behavior:

- hit-test front-to-back within one panel;
- centralized pointer/mouse state;
- hovered panel/widget handles on pointer state;
- pressed/captured widget handle per mouse button on pointer state;
- pointer position, movement delta, button transitions, click durations, and
  hover duration on pointer state;
- clicked event for buttons;
- changed event for checkbox if implemented;
- primitive event queue on the panel.

Expected manual usage:

```zig
panel.updateInput( uiInput );

while( panel.popEvent() )| event |
{
  if( event.isClicked( buy ) ){ buyGoods(); }
}
```

This phase should also expose:

- hit result at point;
- pointer state;
- hovered handles;
- pressed/captured handles;
- simple event count/debug queries.

Widgets should not individually track hover/click timers. Durable widget state,
such as checked value, slider value, text, visibility, configs, and caches,
still belongs on widgets. Focus, keyboard navigation, modal blocking, and
layered routing remain engine-side goals.

## 5. Phase Five - Mutation And Dirty Tracking

Goal: make retained UI practical after creation.

Required mutation helpers:

- set text;
- set visibility;
- set style/config fields that are safe to mutate;
- set requested box;
- set visual offset;
- set checked/value state if relevant;
- add/remove widgets;
- clear panel.

Dirty rules:

- setters mark the right dirty flags;
- layout/render/hit caches update only when needed;
- direct access to internal arrays should not bypass invalidation.

This phase is what makes simple animation possible:

```zig
panel.setVisualOffset( buy, offset );
```

## 6. Phase Six - Text Introspection

Goal: expose enough text state for precise custom drawing.

Required first:

- measured text size;
- text baseline or draw origin;
- line height;
- label final text box.

Later:

- line bounds;
- character/glyph bounds;
- point-to-character lookup.

Do not promise per-letter positioning until the text cache stores the data
needed to answer it correctly.

## 7. Phase Seven - Menuer Primitive Sandbox

Goal: prove the primitive layer without the engine manager.

Use `src/games/menuer` or a small new route in it to demonstrate:

- create a panel directly;
- add labels/buttons;
- row/column/absolute layout;
- render panel;
- click buttons;
- update text after a click;
- query and draw debug boxes from widget final boxes;
- move one widget via visual offset.

This validates the desired backend-dev-friendly use before adding a global
manager.

## 8. Phase Eight - Engine-Side Manager Design

Goal: store the engine-side implementation context for later review.

Do not implement this until the primitive layer is usable.

Future engine manager should provide:

- ownership of many panels;
- panel add/remove/transfer APIs;
- layer and z-order sorting;
- global hit-test across panels;
- input routing into shared pointer/mouse state;
- capture and modal rules;
- close policy;
- engine event forwarding;
- draw-all orchestration;
- debug overlay/inspection.

The engine manager should use the same `Panel` primitives that game-owned UI
uses directly.

## 9. Deferred Features

Defer until the primitive layer is proven:

- text input;
- keyboard navigation;
- gamepad navigation;
- scroll areas;
- dropdowns;
- menu bars;
- tabs;
- tables/lists;
- property inspectors;
- graph widgets;
- docking;
- hot reload;
- theme files;
- world-space UI anchors;
- global engine event integration.

## 10. Validation Strategy

For docs-only changes, no build is required.

For primitive implementation changes:

- run `zig build`;
- run `zig build test` after utility-level changes;
- run the `src/games/menuer` build target once the sandbox is updated;
- do not run `zig fmt`.

Manual validation should focus on whether the API feels easy to use from game
code, not just whether the internals are elegant.
