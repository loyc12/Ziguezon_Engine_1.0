# UI Implementation Reference - Retained Imperative Primitives

This reference replaces the previous retained-manager-first UI plan. The old
prototype remains useful as evidence for layout, hit testing, input capture, and
rendering behavior, but it is no longer the target architecture.

The new target is a small retained imperative UI primitive toolkit for a 2D game
engine and its utils library.

## 1. Target

Build UI from explicit objects:

```zig
const panelCfg : ui.PanelConfig = .{
  .layout = .absolute,
};

var panel = try ui.Panel.init(
  alloc,
  .{
    .key    = ui.key( "main_panel" ),
    .box    = box,
    .config = panelCfg,
  }
);

const buyBtn = try panel.addButton(
  .{
    .key    = ui.key( "buy" ),
    .box    = buyBox,
    .text   = "Buy",
    .config = .{},
  }
);

try ng.ui.addPanel( panel, .{ .layer = .panel } );
```

The same primitive should also work without the engine manager:

```zig
panel.updateInput( input );
panel.updateLayout();
panel.draw();

if( panel.wasClicked( buyBtn ) )
{
  buyGoods();
}
```

This is retained UI, but not a React-style rebuild-every-frame system. The game
or engine creates panels and widgets when needed, mutates them through handles,
and lets dirty flags decide what must be recomputed.

## 2. Primary Goals

- Simple and direct for non-frontend developers.
- Imperative creation and mutation through ordinary Zig code.
- Sparse config structs with sensible defaults.
- Stable handles for later mutation and state queries.
- Panels/widgets can be game-owned or engine-owned.
- UI geometry is center-defined through `Box2`, not top-left rectangle data.
- No mandatory global UI manager for simple cases.
- Engine manager can later orchestrate the same primitives.
- Layout, render, text, and hit-test state are inspectable.
- Stable state is cached and only recalculated when dirty.
- Game logic stays in userland; the UI layer does not become a scripting
  language.
- The first useful version should build static panels with clickable widgets.

## 3. Non-Goals

- Do not build a new layout programming language.
- Do not require declarative panel definitions.
- Do not require rebuilding every UI tree every frame.
- Do not force all UI through an engine-owned singleton.
- Do not create domain-specific core widgets such as inventory panels or quest
  panels.
- Do not integrate `raygui`.
- Do not depend on the old `interface2D.zig` visual experiment unless explicitly
  revisited.
- Do not start with text input, keyboard navigation, docking, hot reload,
  accessibility, or full modal/window management.

## 4. Ownership Boundary

### 4.1 Utils Layer

`src/utils/ui` should own reusable primitive data and behavior:

- `UiKey`, `UiHandle`, and generation-safe identity helpers.
- `Panel`, `Widget`, and child storage.
- `PanelConfig` and `WidgetConfig` with defaults.
- layout inputs and computed layout outputs.
- dirty flags.
- pointer/mouse interaction state structs that do not require `eng.Engine`.
- text metrics and text draw data.
- render caches or render command generation.
- hit-test lists.
- primitive input update helpers.
- primitive draw helpers backed by existing 2D drawing utilities.

The utils layer should not require `eng.Engine`.

### 4.2 Engine Layer

Engine-side UI should be built later on top of the same primitives. It should
own orchestration, not the primitive definitions:

- global/layered UI manager;
- panel lifetime and ownership transfer;
- ordered layers and z-index;
- frame input routing;
- focus, hover, press, and capture rules;
- modal blocking and close policies;
- engine event/command output;
- render ordering;
- debug inspection;
- optional world-space UI routing.

Engine goals should be stored, but implemented separately after the primitive
layer proves itself.

### 4.3 Game-Owned UI

Games should be able to instantiate and own panels directly when that is easier:

- debug overlays;
- one-off menus;
- in-world labels;
- isolated minigame tools;
- custom UI experiments.

The engine manager should add convenience, ordering, and shared input policy; it
should not be required for every UI use.

## 5. Core Object Model

### 5.1 Panel

A panel is the top-level primitive container. It owns widget storage and cached
state for one UI surface.

Expected panel data:

- stable key;
- requested root box;
- final root box;
- panel config;
- widget storage;
- child order;
- layout cache;
- text cache;
- hit map;
- render cache;
- event buffer;
- dirty flags.

Panels may contain child widgets and child containers. Whether nested panels are
represented as widgets or separate panels can be decided during implementation;
the API should make nesting easy either way.

### 5.2 Widget

A widget is a retained primitive element inside a panel.

Initial widget kinds:

- `label`;
- `button`;
- `checkbox`;
- `image` or `sprite` if trivial;
- `spacer`;
- `container`;
- `customDraw`.

Later widget kinds:

- slider;
- scroll area;
- text input;
- tabs;
- table/list;
- graph/custom plot helpers.

Avoid adding domain widgets to the primitive layer. Domain panels should be game
code that composes primitive widgets.

### 5.3 Identity

Use stable user-provided keys plus generation-safe handles.

Suggested split:

- `UiKey`: stable external identity, often a hashed string or explicit integer.
- `UiHandle`: runtime handle, probably index + generation.

The user should not need to keep raw pointers to widgets. Pointers are fragile if
widget storage reallocates. Handles also make engine ownership transfer easier.

## 6. Geometry Model

UI primitives should use the repository's native `Box2` convention directly.
`Box2` stores:

```zig
center : Vec2, // center position
scale  : Vec2, // half-size / side distance from center
```

Do not make the primitive API primarily top-left + width/height. Helpers can
exist for convenience, but the core data model, configs, layout outputs, and
queries should be center-defined.

Every widget should distinguish requested, computed, and final geometry:

```zig
requestedBox : Box2, // user request or local absolute box
computedBox  : Box2, // layout result
visualOffset : Vec2, // animation/manual movement after layout
finalBox     : Box2, // computedBox + visualOffset
```

For absolute static UI, `requestedBox` and `computedBox` are usually the same.
For row/column layout, the layout pass owns `computedBox`. For animation or
manual nudging, user code changes `visualOffset` without corrupting layout.

This keeps "move the button like an entity" compatible with automatic layout.

## 7. Layout Model

Start with a small layout set:

- `absolute`: use requested child boxes.
- `column`: stack children vertically.
- `row`: stack children horizontally.
- `stack`: overlay children in the same region.
- `spacer`: consumes explicit or flexible space.

Later:

- grid;
- scroll region;
- anchoring helpers;
- splitter;
- docking if a real use case appears.

Layout should arrange elements. It should not decide whether game-specific
elements exist. Game code should use ordinary Zig `if`, loops, and functions to
create/mutate panels.

## 8. Dirty Flags

Use dirty flags to keep the system fast without making the user manage caches by
hand.

Suggested flags:

- `structureDirty`: child added, removed, reordered, or parent changed.
- `layoutDirty`: requested boxes, layout mode, text size dependency, padding, or
  visibility changed.
- `textDirty`: text or font data changed.
- `renderDirty`: style, final geometry, text draw data, or visibility changed.
- `hitDirty`: final boxes or interactivity changed.

Mutation APIs should mark dirty state automatically.

Examples:

- `setText()` marks `textDirty`, `renderDirty`, and maybe `layoutDirty`.
- `setBox()` marks `layoutDirty`, `renderDirty`, and `hitDirty`.
- `setVisualOffset()` marks `renderDirty` and `hitDirty`.
- `setStyle()` marks `renderDirty`.
- `addWidget()` marks `structureDirty`, `layoutDirty`, `renderDirty`, and
  `hitDirty`.

## 9. Input And Events

The primitive layer should support simple input without owning the whole engine
policy.

Use a centralized pointer/mouse state instead of making every widget track its
own hover/click timing. This fits the existing camera/input direction and keeps
transient pointer facts in one place.

The primitive-level state can be panel-local at first:

```zig
const UiPointerState = struct
{
  screenPos       : Vec2,
  worldPos        : Vec2, // optional when supplied by engine/camera code
  delta           : Vec2,
  hoveredPanel    : UiHandle,
  hoveredWidget   : UiHandle,
  pressedWidget   : [ 3 ]UiHandle,
  buttonState     : [ 3 ]UiPointerButton,
  hoverDuration   : Duration,
};

const UiPointerButton = struct
{
  isDown            : bool,
  pressedThisFrame  : bool,
  releasedThisFrame : bool,
  downDuration      : Duration,
  dragDelta         : Vec2,
};
```

Exact field names can change during implementation. The important rule is that
the pointer state owns transient interaction facts: topmost hovered target,
pressed/captured target per button, position, movement, button transitions,
click duration, and hover duration.

Widgets should still own durable widget state, such as checkbox value, slider
value, text, visibility, configs, dirty flags, and layout/render caches. A
button should not need to store "hovered for 0.4 seconds"; it can derive its
visual state from the current `UiPointerState`.

Initial input behavior:

- update hover from mouse position;
- update pointer state from hit-test results and button transitions;
- emit clicked event on press/release over the same widget;
- return hit-test results for custom handling.

Initial events:

- `clicked`;
- `changed`;
- `closed` only if panels support local close/destruction.

The engine manager can later add:

- focus;
- keyboard capture;
- modal blocking;
- close policy;
- layer-aware routing;
- global event forwarding.

## 10. Introspection

The UI should expose its own current state. This is a first-class goal, not a
debug-only afterthought.

Required query surfaces:

- get panel box;
- get widget requested/computed/final box;
- get widget kind;
- get widget text;
- get text metrics;
- get hit-test result at point;
- get current pointer/mouse state;
- get hovered/pressed panel and widget handles from pointer state;
- get child count/order;
- get parent/child relation;
- get dirty/debug state.

Text-specific queries should eventually include:

- line bounds;
- glyph/character bounds;
- caret position from character index;
- character index from point.

The exact character query depends on how text measurement is implemented. The
primitive layer should not pretend it can provide per-letter positions until the
text cache actually stores enough data.

## 11. Rendering

Rendering should be optimized but simple:

- layout produces final boxes;
- text measurement produces text draw data;
- render update produces cached draw commands or directly draws from caches;
- draw walks widgets in panel order.

The first renderer can draw immediately through existing screen draw helpers.
Render command extraction can be added only when it removes real complexity or
helps engine-side layering/debugging.

Do not require `interface2D.zig` for v1. Simple rectangles and text are enough
to validate the primitive API.

## 12. Defaults And Configs

Configs should be sparse:

```zig
const cfg : ui.WidgetConfig = .{
  .style = .warning,
};
```

Everything else should default sensibly.

Separate config from mutable state:

- config/defaults describe initial behavior and style;
- widget state stores durable values such as checked value, text, visibility,
  dirty flags, and caches.
- transient hover/press/click timing lives in centralized pointer state.

## 13. Stronger Engine System Later

The primitive toolkit is intended to support a stronger engine-owned UI system.
The engine manager should not replace the primitive API; it should orchestrate
it.

Future engine manager responsibilities:

- own many panels;
- sort by layer and z-index;
- route input front-to-back;
- centralize capture and modal behavior;
- expose UI events to game hooks;
- draw all registered panels;
- provide debug views over panel/widget state;
- support persistent windows/popups/tooltips.

If this split works, engine-owned UI and game-owned UI use the same primitives.
That keeps the simple path simple while allowing stronger engine behavior later.

## 14. First Useful Milestone

The first successful version is not a full windowing system. It is:

- create a panel;
- add labels and buttons;
- layout with absolute/row/column;
- draw the panel;
- hit-test buttons;
- emit clicked events;
- mutate text/boxes after creation;
- query final boxes;
- recalculate only dirty state.

Use `src/games/menuer` as the proof surface once the primitive API exists.
