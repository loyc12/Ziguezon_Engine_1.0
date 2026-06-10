# UI TODO

First steps for the retained imperative UI primitive rewrite.

The previous retained `UiContext` work is superseded as the target plan. It may
still be used as reference material for behavior, but new work should start from
the primitive API described in `ui_implementation_reference.md`.

## 0. Current Decisions

* Target a retained imperative primitive toolkit, not a full engine UI manager
  first.
* Keep the first implementation under `src/utils/ui`.
* Primitives must be usable directly by game code without `eng.Engine`.
* A later engine-side UI manager should orchestrate the same primitives.
* Use `Box2` for requested, computed, and final widget bounds.
* Keep UI primitive geometry center-defined, matching `Box2.center` +
  `Box2.scale` half-size semantics.
* Use sparse config structs with defaults.
* Use stable handles/keys; do not expose raw widget pointers as long-term IDs.
* Use dirty flags so mutations automatically trigger only the needed
  recalculation.
* Track transient mouse hover/click timing in a centralized pointer state, not
  independently on every widget.
* Keep logic in game code. Do not add layout-level conditionals, loops,
  expression evaluators, or domain-specific panel nodes.
* Do not run formatting passes such as `zig fmt`.

## 1. Preserve Context Before Code

* Keep `ui_current_plan_summary.md` as the snapshot of the old implementation.
* Keep `ui_conversation_model_summary.md` as the design pressure that motivated
  the rewrite.
* Treat `ui_implementation_reference.md` as the current architecture reference.
* Treat this TODO as the first implementation checklist.

## 2. First Implementation Slice - Primitive Types

Create or replace the minimal type surface in `src/utils/ui`:

* `UiKey`
* `UiHandle`
* `UiDirtyFlags`
* `Panel`
* `PanelConfig`
* `Widget`
* `WidgetConfig`
* `WidgetKind`
* `WidgetState`
* `UiPointerState`
* `UiPointerButton`
* `UiEvent`

Initial widget kinds:

* label
* button
* spacer
* container if needed for row/column nesting

Hold checkbox until button/label/container behavior is clean unless it is
trivial to include.

## 3. First API Shape

Aim for calls like:

```zig
var panel = try ui.Panel.init( alloc, .{
  .key    = ui.key( "main_panel" ),
  .box    = box,
  .config = .{},
});

const title = try panel.addLabel( .{
  .key  = ui.key( "title" ),
  .text = "Main",
});

const buy = try panel.addButton( .{
  .key    = ui.key( "buy" ),
  .box    = buyBox,
  .text   = "Buy",
  .config = .{},
});
```

The first API should favor clarity over maximum compactness. After it works,
trim boilerplate.

## 4. Geometry And Layout Tasks

* Store requested, computed, visual offset, and final boxes.
* Ensure requested/computed/final boxes use center + half-size `Box2`
  semantics.
* Keep top-left/size helpers as optional convenience only, not as core storage.
* Implement absolute layout first.
* Implement column layout second.
* Implement row layout third.
* Add stack layout only if it falls out naturally.
* Add `updateLayout()` on `Panel`.
* Add `getWidgetBox()` / `getWidgetFinalBox()` queries.
* Mark layout dirty on structure, box, layout, visibility, and relevant text
  changes.

## 5. Rendering Tasks

* Draw panel background/perimeter.
* Draw labels.
* Draw button rectangles and centered/left text.
* Add a debug draw mode for widget final boxes.
* Add render dirty tracking.
* Reuse existing screen draw helpers.
* Do not integrate `interface2D.zig` yet.

## 6. Hit Test And Event Tasks

* Build or update a panel-local hit list from final boxes.
* Add `hitTest( point )`.
* Add `updatePointer( pointer )` or `updateInput( input )` around a centralized
  pointer/mouse state.
* Track hovered panel/widget handles on pointer state.
* Track pressed/captured widget handles per mouse button on pointer state.
* Track pointer position, movement delta, button transitions, click duration,
  and hover duration on pointer state.
* Emit clicked events for buttons.
* Add `popEvent()`.
* Mark hit dirty when final boxes or interactivity change.
* Do not store hover/click timers on each widget.

## 7. Mutation Tasks

* Add `setText()`.
* Add `setVisible()`.
* Add `setBox()`.
* Add `setVisualOffset()`.
* Add `setStyle()` only if style is included in the first slice.
* Make every setter mark dirty flags automatically.
* Avoid exposing direct mutable access that bypasses invalidation.

## 8. Introspection Tasks

* Expose panel/widget counts.
* Expose widget kind.
* Expose parent/child relation or child iteration.
* Expose requested/computed/final boxes.
* Expose pointer/mouse state.
* Expose hovered/pressed handles through pointer state.
* Expose dirty/debug state.
* Add text size query once text measurement exists.
* Defer per-character/glyph positions until the text cache can answer them
  accurately.

## 9. Sandbox Tasks

After the primitive layer compiles:

* Update `src/games/menuer` or add a small path in it to build one game-owned
  primitive panel.
* Demonstrate label + button.
* Demonstrate row or column layout.
* Demonstrate click event handling.
* Demonstrate `setText()` after click.
* Demonstrate direct widget movement with `setVisualOffset()`.
* Demonstrate querying widget final boxes and drawing debug bounds.

## 10. Engine-Side Context To Review Later

Do not implement yet. Keep these goals for the next design pass:

* `eng.Engine` owns an optional UI manager built on primitive `Panel`.
* Manager can add/remove/own panels.
* Manager sorts panels by layer/z.
* Manager routes input front-to-back into shared pointer/mouse state.
* Manager owns focus/capture/modal/close policy.
* Manager drains panel-local events and exposes engine-facing events.
* Manager draws all registered panels.
* Game-owned panels remain valid for simple/manual use.

## 11. Validation

For the first primitive implementation:

* `zig build`
* `zig build test` if utility tests are added or changed
* later, the `src/games/menuer` build target once the sandbox is updated

Never run `zig fmt`.
