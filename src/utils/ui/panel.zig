const std = @import( "std" );
const utl = @import( "utils" );

const Box2     = utl.Box2;
const Colour   = utl.Colour;
const Mouse    = utl.Mouse;
const Vec2     = utl.Vec2;


// ================================ IDENTIFIERS ================================

/// Stable user-facing identity for panels and widgets. Runtime mutation should
/// still use `UiHandle` because keys are not generation-checked.
pub const UiKey = u64;

pub fn key( str : []const u8 ) UiKey
{
  return std.hash.Wyhash.hash( 0, str );
}

/// Generation-checked runtime identity for a widget stored inside a `Panel`.
/// Handles become invalid when their slot generation no longer matches.
pub const UiHandle = struct
{
  pub const invalidIndex : u32 = std.math.maxInt( u32 );

  idx : u32 = invalidIndex,
  gen : u32 = 0,

  pub inline fn none() UiHandle { return .{}; }
  pub inline fn fromIndexGen( idx : u32, gen : u32 ) UiHandle { return .{ .idx = idx, .gen = gen }; }

  pub inline fn isValid( self : UiHandle ) bool { return self.idx < invalidIndex; }

  pub inline fn isEq( self : UiHandle, other : UiHandle ) bool
  {
    return self.idx == other.idx and self.gen == other.gen;
  }
};

pub const UiPointerState  = Mouse;
pub const UiPointerButton = utl.MouseButtonState;


// ================================ STYLE ================================

/// Small built-in layout set. `absolute` child boxes are center-defined; root
/// children use screen space while children of widgets are local to the parent.
pub const UiLayout = enum( u8 )
{
  absolute,
  column,
  row,
  stack,
};

/// Horizontal text alignment inside the widget's final box.
pub const UiTextAlign = enum( u8 )
{
  left,
  center,
};

/// Minimal visual style for primitive widgets.
pub const UiStyle = struct
{
  fillCol        : Colour = Colour.nBlack.setA( 220 ),
  fillHoverCol   : Colour = Colour.sGray.setA( 230 ),
  fillPressedCol : Colour = Colour.dGray.setA( 240 ),
  edgeCol        : Colour = Colour.mGray,
  textCol        : Colour = Colour.nWhite,
  accentCol      : Colour = Colour.pTeal,

  lineWidth : f64 = 2.0,
  fontSize  : f64 = 16.0,

  pub inline fn fillFor( self : UiStyle, isHovered : bool, isPressed : bool ) Colour
  {
    if( isPressed ){ return self.fillPressedCol; }
    if( isHovered ){ return self.fillHoverCol;   }
    return self.fillCol;
  }

  pub fn forKind( kind : WidgetKind ) UiStyle
  {
    var style : UiStyle = .{};

    switch( kind )
    {
      .label =>
      {
        style.fillCol  = Colour.transpa;
        style.edgeCol  = Colour.transpa;
        style.lineWidth = 0.0;
      },

      .button =>
      {
        style.fillCol        = Colour.sGray.setA( 230 );
        style.fillHoverCol   = Colour.lGray.setA( 240 );
        style.fillPressedCol = Colour.dGray.setA( 250 );
        style.edgeCol        = Colour.lGray;
      },

      .checkbox =>
      {
        style.fillCol        = Colour.sGray.setA( 230 );
        style.fillHoverCol   = Colour.lGray.setA( 240 );
        style.fillPressedCol = Colour.dGray.setA( 250 );
        style.edgeCol        = Colour.lGray;
        style.accentCol      = Colour.pTeal;
      },

      .spacer =>
      {
        style.fillCol   = Colour.transpa;
        style.edgeCol   = Colour.transpa;
        style.lineWidth = 0.0;
      },

      .container =>
      {
        style.fillCol   = Colour.transpa;
        style.edgeCol   = Colour.transpa;
        style.lineWidth = 0.0;
      },

      .customDraw => {},
    }

    return style;
  }
};


// ================================ CONFIGS ================================

/// Dirty flags used by retained primitives to avoid recalculating stable
/// layout, text, render, and hit data when the caller only changes one area.
pub const UiDirtyFlags = packed struct
{
  structure : bool = true,
  layout    : bool = true,
  text      : bool = true,
  render    : bool = true,
  hit       : bool = true,

  pub inline fn any( self : UiDirtyFlags ) bool
  {
    return self.structure or self.layout or self.text or self.render or self.hit;
  }

  pub inline fn clear( self : *UiDirtyFlags ) void
  {
    self.* = .{
      .structure = false,
      .layout    = false,
      .text      = false,
      .render    = false,
      .hit       = false,
    };
  }
};

/// Top-level panel configuration. A panel box is always screen-space and
/// center-defined through `Box2`.
pub const PanelConfig = struct
{
  layout  : UiLayout = .absolute,
  padding : f64      = 8.0,
  gap     : f64      = 6.0,
  style   : UiStyle  = .{},
};

/// Widget configuration applied when a primitive is created.
pub const WidgetConfig = struct
{
  layout      : UiLayout    = .absolute,
  desiredSize : Vec2        = .new( 160.0, 28.0 ),
  padding     : f64         = 6.0,
  gap         : f64         = 4.0,
  isVisible   : bool        = true,
  isEnabled   : bool        = true,
  isChecked   : bool        = false,
  textAlign   : UiTextAlign = .left,
  style       : ?UiStyle    = null,
};

/// Arguments for creating a `Panel`.
pub const PanelInit = struct
{
  key    : UiKey       = 0,
  box    : Box2        = .{},
  config : PanelConfig = .{},
};

/// Arguments for creating a widget inside a `Panel`.
pub const WidgetInit = struct
{
  key    : UiKey        = 0,
  parent : UiHandle     = .{},
  box    : Box2         = .{},
  text   : []const u8   = "",
  config : WidgetConfig = .{},
};


// ================================ EVENTS ================================

/// Panel-local UI event kind.
pub const UiEventType = enum( u8 )
{
  clicked,
  changed,
};

/// Event queued by a panel. Events stay queued until `popEvent()` or
/// `clearEvents()` removes them.
pub const UiEvent = struct
{
  eType  : UiEventType = .clicked,
  widget : UiHandle    = .{},

  pub inline fn isClicked( self : UiEvent, widget : UiHandle ) bool
  {
    return self.eType == .clicked and self.widget.isEq( widget );
  }

  pub inline fn isChanged( self : UiEvent, widget : UiHandle ) bool
  {
    return self.eType == .changed and self.widget.isEq( widget );
  }
};

pub inline fn isClicked( event : UiEvent, widget : UiHandle ) bool
{
  return event.isClicked( widget );
}

pub inline fn isChanged( event : UiEvent, widget : UiHandle ) bool
{
  return event.isChanged( widget );
}


// ================================ WIDGETS ================================

/// Primitive widget types intentionally kept small enough for direct game code.
pub const WidgetKind = enum( u8 )
{
  label,
  button,
  checkbox,
  spacer,
  container,
  customDraw,
};

/// Durable per-widget state that survives input frames and layout updates.
pub const WidgetState = struct
{
  isVisible : bool = true,
  isEnabled : bool = true,
  isChecked : bool = false,
};

const textBufLen : usize = 160;

/// Cached text measurements derived from the widget's text, final box, style,
/// and alignment. Per-character bounds are intentionally deferred.
pub const UiTextMetrics = struct
{
  measuredSize : Vec2 = .{},
  drawOrigin   : Vec2 = .{},
  lineHeight   : f64  = 0.0,
  textBox      : Box2 = .{},
};

/// Retained widget storage owned by `Panel`. Prefer handle-based panel methods
/// over direct mutation so dirty flags remain correct.
pub const Widget = struct
{
  key : UiKey    = 0,
  id  : UiHandle = .{},
  gen : u32      = 0,

  kind   : WidgetKind = .label,
  parent : UiHandle   = .{},
  order  : u32        = 0,

  requestedBox : Box2 = .{},
  computedBox  : Box2 = .{},
  finalBox     : Box2 = .{},
  visualOffset : Vec2 = .{},

  desiredSize : Vec2     = .new( 160.0, 28.0 ),
  layout      : UiLayout = .absolute,
  padding     : f64      = 6.0,
  gap         : f64      = 4.0,

  state : WidgetState = .{},
  style : UiStyle     = .{},

  text        : [ textBufLen ]u8 = [_]u8{ 0 } ** textBufLen,
  textLen     : usize            = 0,
  textMetrics : UiTextMetrics    = .{},
  textAlign   : UiTextAlign      = .left,

  isAlive : bool = false,

  pub fn init( id : UiHandle, kind : WidgetKind, opts : WidgetInit ) Widget
  {
    var widget : Widget = .{
      .key          = opts.key,
      .id           = id,
      .gen          = id.gen,
      .kind         = kind,
      .parent       = opts.parent,
      .requestedBox = opts.box,
      .computedBox  = opts.box,
      .finalBox     = opts.box,
      .desiredSize  = opts.config.desiredSize,
      .layout       = opts.config.layout,
      .padding      = opts.config.padding,
      .gap          = opts.config.gap,
      .state        = .{ .isVisible = opts.config.isVisible, .isEnabled = opts.config.isEnabled, .isChecked = opts.config.isChecked },
      .style        = if( opts.config.style )| style | style else UiStyle.forKind( kind ),
      .textAlign    = opts.config.textAlign,
      .isAlive      = true,
    };

    widget.setText( opts.text );
    return widget;
  }

  pub fn setText( self : *Widget, str : []const u8 ) void
  {
    const len = @min( str.len, self.text.len );

    if( len > 0             ){ @memcpy( self.text[ 0..len ], str[ 0..len ] ); }
    if( len < self.text.len ){ @memset( self.text[ len..  ], 0             ); }

    self.textLen = len;
  }

  pub inline fn getText( self : *const Widget ) []const u8
  {
    return self.text[ 0..self.textLen ];
  }

  pub inline fn isInteractive( self : *const Widget ) bool
  {
    return switch( self.kind )
    {
      .button, .checkbox => self.isAlive and self.state.isVisible and self.state.isEnabled,
      else               => false,
    };
  }
};


// ================================ PANEL ================================

const HitEntry = struct
{
  widget : UiHandle = .{},
  box    : Box2     = .{},
};

/// Game-owned retained primitive UI surface. Child order is stable and local to
/// each parent: earlier siblings draw first and later siblings hit first.
pub const Panel = struct
{
  alloc : std.mem.Allocator = undefined,

  key : UiKey = 0,
  box : Box2  = .{},

  config : PanelConfig = .{},
  dirty  : UiDirtyFlags = .{},

  widgets : std.ArrayList( Widget  ) = .empty,
  hits    : std.ArrayList( HitEntry ) = .empty,
  events  : std.ArrayList( UiEvent  ) = .empty,

  pointer : UiPointerState = .{},

  debugDrawBounds : bool = false,
  isInit          : bool = false,


  // ================================ LIFETIME ================================

  pub fn init( alloc : std.mem.Allocator, opts : PanelInit ) !Panel
  {
    return .{
      .alloc  = alloc,
      .key    = opts.key,
      .box    = opts.box,
      .config = opts.config,
      .dirty  = .{},
      .isInit = true,
    };
  }

  pub fn deinit( self : *Panel ) void
  {
    if( !self.isInit ){ return; }

    self.events.deinit(  self.alloc );
    self.hits.deinit(    self.alloc );
    self.widgets.deinit( self.alloc );

    self.* = .{};
  }

  pub fn clear( self : *Panel ) void
  {
    self.events.clearRetainingCapacity();
    self.hits.clearRetainingCapacity();
    self.widgets.clearRetainingCapacity();
    self.markStructureDirty();
  }


  // ================================ CREATION ================================

  fn createWidget( self : *Panel, kind : WidgetKind, opts : WidgetInit ) !UiHandle
  {
    var fixedOpts = opts;
    if( fixedOpts.key == 0 ){ fixedOpts.key = @as( UiKey, @intFromEnum( kind )) + @as( UiKey, self.widgets.items.len ) + 1; }

    const order = self.getNextChildOrder( fixedOpts.parent );

    for( self.widgets.items, 0.. )| *slot, i |
    {
      if( slot.isAlive ){ continue; }

      var gen = slot.gen +% 1;
      if( gen == 0 ){ gen = 1; }

      const id = UiHandle.fromIndexGen( @intCast( i ), gen );
      slot.* = Widget.init( id, kind, fixedOpts );
      slot.order = order;
      self.markStructureDirty();
      return id;
    }

    if( self.widgets.items.len >= @as( usize, UiHandle.invalidIndex ))
    {
      return error.UiWidgetLimitReached;
    }

    const id = UiHandle.fromIndexGen( @intCast( self.widgets.items.len ), 1 );
    try self.widgets.append( self.alloc, Widget.init( id, kind, fixedOpts ) );
    self.widgets.items[ self.widgets.items.len - 1 ].order = order;

    self.markStructureDirty();
    return id;
  }

  /// Adds a non-interactive text primitive.
  pub inline fn addLabel( self : *Panel, opts : WidgetInit ) !UiHandle { return self.createWidget( .label, opts ); }

  /// Adds a clickable button. Press and release must happen on the same button
  /// for a `clicked` event to be queued.
  pub inline fn addButton( self : *Panel, opts : WidgetInit ) !UiHandle { return self.createWidget( .button, opts ); }

  /// Adds a persistent two-state checkbox that emits `changed` after toggling.
  pub inline fn addCheckbox( self : *Panel, opts : WidgetInit ) !UiHandle { return self.createWidget( .checkbox, opts ); }

  /// Adds empty layout space.
  pub inline fn addSpacer( self : *Panel, opts : WidgetInit ) !UiHandle { return self.createWidget( .spacer, opts ); }

  /// Adds a child container whose own `layout`, `padding`, and `gap` arrange
  /// descendants.
  pub inline fn addContainer( self : *Panel, opts : WidgetInit ) !UiHandle { return self.createWidget( .container, opts ); }


  // ================================ CHILD ORDER ================================

  fn getNextChildOrder( self : *const Panel, parent : UiHandle ) u32
  {
    var maxOrder : u32 = 0;

    for( self.widgets.items )| *widget |
    {
      if( widget.isAlive and widget.parent.isEq( parent )){ maxOrder = @max( maxOrder, widget.order +% 1 ); }
    }

    return maxOrder;
  }

  fn getNextChildIndex( self : *const Panel, parent : UiHandle, afterOrder : ?u32 ) ?usize
  {
    var bestIdx   : ?usize = null;
    var bestOrder : u32    = std.math.maxInt( u32 );

    for( self.widgets.items, 0.. )| *widget, i |
    {
      if( !widget.isAlive or !widget.parent.isEq( parent )){ continue; }
      if( afterOrder )| order |{ if( widget.order <= order ){ continue; } }
      if( widget.order >= bestOrder ){ continue; }

      bestIdx   = i;
      bestOrder = widget.order;
    }

    return bestIdx;
  }

  fn appendOrderedChildren( self : *const Panel, parent : UiHandle, out : *std.ArrayList( UiHandle ) ) !void
  {
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      try out.append( self.alloc, widget.id );
      cursor = widget.order;
    }
  }

  fn getSiblingIndex( self : *const Panel, id : UiHandle ) ?usize
  {
    const widget = self.getWidget( id ) orelse return null;
    var cursor   : ?u32  = null;
    var outIndex : usize = 0;

    while( self.getNextChildIndex( widget.parent, cursor ))| idx |
    {
      const child = &self.widgets.items[ idx ];
      if( child.id.isEq( id )){ return outIndex; }

      cursor = child.order;
      outIndex += 1;
    }

    return null;
  }


  // ================================ LOOKUP ================================

  /// Advanced/internal escape hatch. Normal callers should use handle-based
  /// getters and setters so layout, text, render, and hit caches stay valid.
  pub fn getWidgetPtr( self : *Panel, id : UiHandle ) ?*Widget
  {
    if( !id.isValid() ){ return null; }

    const idx : usize = @intCast( id.idx );
    if( idx >= self.widgets.items.len ){ return null; }

    const widget = &self.widgets.items[ idx ];
    if( !widget.isAlive or widget.gen != id.gen ){ return null; }

    return widget;
  }

  /// Read-only widget lookup. Prefer narrower getters when only one property is
  /// needed.
  pub fn getWidget( self : *const Panel, id : UiHandle ) ?*const Widget
  {
    if( !id.isValid() ){ return null; }

    const idx : usize = @intCast( id.idx );
    if( idx >= self.widgets.items.len ){ return null; }

    const widget = &self.widgets.items[ idx ];
    if( !widget.isAlive or widget.gen != id.gen ){ return null; }

    return widget;
  }

  pub inline fn getWidgetCount( self : *const Panel ) usize { return self.widgets.items.len; }
  pub inline fn getEventCount(  self : *const Panel ) usize { return self.events.items.len;  }

  pub inline fn peekEventCount( self : *const Panel ) usize { return self.getEventCount(); }
  pub inline fn getDebugDrawBounds( self : *const Panel ) bool { return self.debugDrawBounds; }

  pub inline fn getBox( self : *const Panel ) Box2 { return self.box; }
  pub inline fn getDirtyFlags( self : *const Panel ) UiDirtyFlags { return self.dirty; }

  pub inline fn isWidgetAlive( self : *const Panel, id : UiHandle ) bool
  {
    return self.getWidget( id ) != null;
  }

  pub inline fn isWidgetVisible( self : *const Panel, id : UiHandle ) bool
  {
    if( self.getWidget( id ))| widget |{ return widget.state.isVisible; }
    return false;
  }

  pub inline fn getWidgetKind( self : *const Panel, id : UiHandle ) ?WidgetKind
  {
    if( self.getWidget( id ))| widget |{ return widget.kind; }
    return null;
  }

  pub inline fn getParent( self : *const Panel, id : UiHandle ) UiHandle
  {
    if( self.getWidget( id ))| widget |{ return widget.parent; }
    return .{};
  }

  pub fn getChildCount( self : *const Panel, parent : UiHandle ) usize
  {
    var count : usize = 0;

    for( self.widgets.items )| *widget |
    {
      if( widget.isAlive and widget.parent.isEq( parent )){ count += 1; }
    }

    return count;
  }

  pub fn getChildAt( self : *const Panel, parent : UiHandle, childIdx : usize ) UiHandle
  {
    var cursor : ?u32  = null;
    var count  : usize = 0;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      if( count == childIdx ){ return widget.id; }

      cursor = widget.order;
      count += 1;
    }

    return .{};
  }

  /// Copies ordered child handles into `out` and returns the number copied.
  /// Children are ordered from back-to-front draw order within the parent.
  pub fn collectChildren( self : *const Panel, parent : UiHandle, out : []UiHandle ) usize
  {
    var cursor : ?u32  = null;
    var count  : usize = 0;

    while( count < out.len )
    {
      const idx = self.getNextChildIndex( parent, cursor ) orelse break;
      const widget = &self.widgets.items[ idx ];

      out[ count ] = widget.id;
      cursor = widget.order;
      count += 1;
    }

    return count;
  }

  pub inline fn getWidgetRequestedBox( self : *const Panel, id : UiHandle ) ?Box2
  {
    if( self.getWidget( id ))| widget |{ return widget.requestedBox; }
    return null;
  }

  pub inline fn getWidgetBox( self : *const Panel, id : UiHandle ) ?Box2
  {
    if( self.getWidget( id ))| widget |{ return widget.computedBox; }
    return null;
  }

  pub inline fn getWidgetFinalBox( self : *const Panel, id : UiHandle ) ?Box2
  {
    if( self.getWidget( id ))| widget |{ return widget.finalBox; }
    return null;
  }

  pub inline fn getWidgetTextSize( self : *const Panel, id : UiHandle ) ?Vec2
  {
    if( self.getWidget( id ))| widget |{ return widget.textMetrics.measuredSize; }
    return null;
  }

  pub inline fn getWidgetTextMetrics( self : *const Panel, id : UiHandle ) ?UiTextMetrics
  {
    if( self.getWidget( id ))| widget |{ return widget.textMetrics; }
    return null;
  }

  pub inline fn getWidgetText( self : *const Panel, id : UiHandle ) ?[]const u8
  {
    if( self.getWidget( id ))| widget |{ return widget.getText(); }
    return null;
  }

  pub inline fn getChecked( self : *const Panel, id : UiHandle ) ?bool
  {
    if( self.getWidget( id ))| widget |
    {
      if( widget.kind == .checkbox ){ return widget.state.isChecked; }
    }

    return null;
  }

  pub inline fn getPointer( self : *const Panel ) UiPointerState { return self.pointer; }
  pub inline fn getHovered( self : *const Panel ) UiHandle { return handleFromTarget( self.pointer.topWidget ); }
  pub inline fn getPressed( self : *const Panel, button : utl.MouseButton ) UiHandle
  {
    return handleFromTarget( self.pointer.getButton( button ).pressedWidget );
  }


  // ================================ MUTATION ================================

  pub fn setPanelBox( self : *Panel, box : Box2 ) void
  {
    self.box = box;
    self.markLayoutDirty();
  }

  pub fn setPanelLayout( self : *Panel, layout : UiLayout ) void
  {
    self.config.layout = layout;
    self.markLayoutDirty();
  }

  pub fn removeWidget( self : *Panel, id : UiHandle ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.isAlive = false;
      widget.state.isVisible = false;
      self.markStructureDirty();
    }
  }

  pub fn clearEvents( self : *Panel ) void
  {
    self.events.clearRetainingCapacity();
  }

  pub fn setText( self : *Panel, id : UiHandle, str : []const u8 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.setText( str );
      self.markTextDirty();
    }
  }

  pub fn setTextFmt( self : *Panel, id : UiHandle, comptime fmt : []const u8, args : anytype ) void
  {
    var buf : [ textBufLen ]u8 = undefined;
    const str = std.fmt.bufPrint( &buf, fmt, args ) catch
    {
      self.setText( id, "<text too long>" );
      return;
    };

    self.setText( id, str );
  }

  pub fn setLayout( self : *Panel, id : UiHandle, layout : UiLayout ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.layout = layout;
      self.markLayoutDirty();
    }
  }

  pub fn setDesiredSize( self : *Panel, id : UiHandle, size : Vec2 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.desiredSize = size;
      self.markLayoutDirty();
    }
  }

  pub fn setPadding( self : *Panel, id : UiHandle, padding : f64 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.padding = padding;
      self.markLayoutDirty();
    }
  }

  pub fn setGap( self : *Panel, id : UiHandle, gap : f64 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.gap = gap;
      self.markLayoutDirty();
    }
  }

  pub fn setVisible( self : *Panel, id : UiHandle, isVisible : bool ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.state.isVisible = isVisible;
      self.markLayoutDirty();
    }
  }

  pub fn setEnabled( self : *Panel, id : UiHandle, isEnabled : bool ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.state.isEnabled = isEnabled;
      self.dirty.hit = true;
      self.markRenderDirty();
    }
  }

  pub fn setChecked( self : *Panel, id : UiHandle, isChecked : bool ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      if( widget.kind != .checkbox ){ return; }
      if( widget.state.isChecked == isChecked ){ return; }

      widget.state.isChecked = isChecked;
      self.markRenderDirty();
    }
  }

  pub fn setBox( self : *Panel, id : UiHandle, box : Box2 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.requestedBox = box;
      self.markLayoutDirty();
    }
  }

  pub fn setVisualOffset( self : *Panel, id : UiHandle, offset : Vec2 ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.visualOffset = offset;
      widget.finalBox     = widget.computedBox.moveCenter( widget.visualOffset );
      self.updateWidgetTextMetrics( widget );
      self.markRenderDirty();
      self.dirty.hit = true;
    }
  }

  pub fn setStyle( self : *Panel, id : UiHandle, style : UiStyle ) void
  {
    if( self.getWidgetPtr( id ))| widget |
    {
      widget.style = style;
      self.markTextDirty();
    }
  }

  pub inline fn setDebugDrawBounds( self : *Panel, enabled : bool ) void
  {
    self.debugDrawBounds = enabled;
  }

  /// Moves a widget to an explicit sibling index. Index 0 draws first; the last
  /// index draws on top and wins hit testing among overlapping siblings.
  pub fn moveWidgetToSiblingIndex( self : *Panel, id : UiHandle, targetIdx : usize ) void
  {
    const widget = self.getWidget( id ) orelse return;

    var children : std.ArrayList( UiHandle ) = .empty;
    defer children.deinit( self.alloc );

    self.appendOrderedChildren( widget.parent, &children ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to collect UI child order : {}", .{ err });
      return;
    };

    var nextOrder : u32   = 0;
    var outIndex  : usize = 0;
    var inserted  : bool  = false;
    const clampedIdx = @min( targetIdx, if( children.items.len == 0 ) 0 else children.items.len - 1 );

    for( children.items )| child |
    {
      if( child.isEq( id )){ continue; }

      if( !inserted and outIndex == clampedIdx )
      {
        if( self.getWidgetPtr( id ))| moved |
        {
          moved.order = nextOrder;
          nextOrder += 1;
        }
        inserted = true;
        outIndex += 1;
      }

      if( self.getWidgetPtr( child ))| ordered |
      {
        ordered.order = nextOrder;
        nextOrder += 1;
      }

      outIndex += 1;
    }

    if( !inserted )
    {
      if( self.getWidgetPtr( id ))| moved |{ moved.order = nextOrder; }
    }

    self.markStructureDirty();
  }

  pub fn bringWidgetForward( self : *Panel, id : UiHandle ) void
  {
    const idx = self.getSiblingIndex( id ) orelse return;
    self.moveWidgetToSiblingIndex( id, idx + 1 );
  }

  pub fn sendWidgetBackward( self : *Panel, id : UiHandle ) void
  {
    const idx = self.getSiblingIndex( id ) orelse return;
    if( idx == 0 ){ return; }
    self.moveWidgetToSiblingIndex( id, idx - 1 );
  }


  // ================================ DIRTY FLAGS ================================

  fn markStructureDirty( self : *Panel ) void
  {
    self.dirty.structure = true;
    self.dirty.layout    = true;
    self.dirty.text      = true;
    self.dirty.render    = true;
    self.dirty.hit       = true;
  }

  fn markLayoutDirty( self : *Panel ) void
  {
    self.dirty.layout = true;
    self.dirty.render = true;
    self.dirty.hit    = true;
  }

  fn markTextDirty( self : *Panel ) void
  {
    self.dirty.text   = true;
    self.dirty.render = true;
  }

  fn markRenderDirty( self : *Panel ) void
  {
    self.dirty.render = true;
  }


  // ================================ LAYOUT ================================

  pub fn updateLayout( self : *Panel ) void
  {
    if( self.dirty.text ){ self.updateTextCache(); }
    if( !self.dirty.layout and !self.dirty.structure ){ return; }

    self.layoutChildrenOf( .{}, self.box, self.config.layout, self.config.padding, self.config.gap );
    self.dirty.structure = false;
    self.dirty.layout    = false;
    self.dirty.render    = true;
    self.dirty.hit       = true;
  }

  fn layoutChildrenOf( self : *Panel, parent : UiHandle, parentBox : Box2, layout : UiLayout, padding : f64, gap : f64 ) void
  {
    switch( layout )
    {
      .absolute => self.layoutAbsoluteChildren( parent, parentBox ),
      .column   => self.layoutColumnChildren(   parent, parentBox, padding, gap ),
      .row      => self.layoutRowChildren(      parent, parentBox, padding, gap ),
      .stack    => self.layoutStackChildren(    parent, parentBox, padding ),
    }
  }

  fn finishWidgetLayout( self : *Panel, widget : *Widget, box : Box2 ) void
  {
    widget.computedBox = box;
    widget.finalBox    = box.moveCenter( widget.visualOffset );
    self.updateWidgetTextMetrics( widget );

    if( widget.kind == .container )
    {
      self.layoutChildrenOf( widget.id, widget.computedBox, widget.layout, widget.padding, widget.gap );
    }
  }

  fn layoutAbsoluteChildren( self : *Panel, parent : UiHandle, parentBox : Box2 ) void
  {
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !self.isLayoutChild( widget, parent )){ continue; }

      var box = widget.requestedBox;
      if( box.scale.isZero() ){ box.scale = widget.desiredSize.mulVal( 0.5 ); }
      if( parent.isValid() )
      {
        box.center = parentBox.center.add( box.center );
      }

      self.finishWidgetLayout( widget, box );
    }
  }

  fn layoutColumnChildren( self : *Panel, parent : UiHandle, parentBox : Box2, padding : f64, gap : f64 ) void
  {
    const contentWidth = @max( 0.0, parentBox.getSizeX() - ( padding * 2.0 ));
    var topLeft = parentBox.getTopLeft().add( .new( padding, padding ));
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !self.isLayoutChild( widget, parent )){ continue; }

      var size = widget.desiredSize;
      if( size.x <= 0.0 ){ size.x = contentWidth; }

      const box = boxFromTopLeft( topLeft, size );
      self.finishWidgetLayout( widget, box );

      topLeft.y += size.y + gap;
    }
  }

  fn layoutRowChildren( self : *Panel, parent : UiHandle, parentBox : Box2, padding : f64, gap : f64 ) void
  {
    const contentHeight = @max( 0.0, parentBox.getSizeY() - ( padding * 2.0 ));
    var topLeft = parentBox.getTopLeft().add( .new( padding, padding ));
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !self.isLayoutChild( widget, parent )){ continue; }

      var size = widget.desiredSize;
      if( size.y <= 0.0 ){ size.y = contentHeight; }

      const box = boxFromTopLeft( topLeft, size );
      self.finishWidgetLayout( widget, box );

      topLeft.x += size.x + gap;
    }
  }

  fn layoutStackChildren( self : *Panel, parent : UiHandle, parentBox : Box2, padding : f64 ) void
  {
    var box = parentBox;
    box.scale.x = @max( 0.0, box.scale.x - padding );
    box.scale.y = @max( 0.0, box.scale.y - padding );

    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !self.isLayoutChild( widget, parent )){ continue; }
      self.finishWidgetLayout( widget, box );
    }
  }

  fn isLayoutChild( self : *const Panel, widget : *const Widget, parent : UiHandle ) bool
  {
    _ = self;
    if( !widget.isAlive or !widget.state.isVisible ){ return false; }
    return widget.parent.isEq( parent );
  }


  // ================================ TEXT ================================

  fn updateTextCache( self : *Panel ) void
  {
    for( self.widgets.items )| *widget |
    {
      self.updateWidgetTextMetrics( widget );
    }

    self.dirty.text = false;
  }

  fn updateWidgetTextMetrics( self : *Panel, widget : *Widget ) void
  {
    _ = self;

    if( !widget.isAlive or widget.textLen == 0 )
    {
      widget.textMetrics = .{};
      return;
    }

    const measuredSize = measureText( widget.getText(), widget.style.fontSize );
    const lineHeight   = measuredSize.y;
    const drawOrigin   = getTextDrawOrigin( widget );

    widget.textMetrics = .{
      .measuredSize = measuredSize,
      .drawOrigin   = drawOrigin,
      .lineHeight   = lineHeight,
      .textBox      = getTextBox( widget, drawOrigin, measuredSize ),
    };
  }


  // ================================ INPUT ================================

  pub fn updateInput( self : *Panel, mouse : Mouse ) void
  {
    self.updatePointer( mouse );
  }

  pub fn updatePointer( self : *Panel, mouse : Mouse ) void
  {
    self.updateLayout();
    self.updateHitMap();

    const prevPointer = self.pointer;
    self.pointer = mouse;

    for( 0..utl.MouseButton.count )| i |
    {
      self.pointer.buttons[ i ].pressedWidget = prevPointer.buttons[ i ].pressedWidget;
    }

    const hovered = self.hitTest( mouse.screenPos );
    self.pointer.setUiHoverTarget( .fromId( self.key ), targetFromHandle( hovered ), mouse.frameTime );

    inline for( .{ utl.MouseButton.left, utl.MouseButton.right, utl.MouseButton.middle } )| button |
    {
      const buttonState = mouse.getButton( button );

      if( buttonState.pressedThisFrame )
      {
        self.pointer.setPressedWidget( button, targetFromHandle( hovered ) );
      }

      if( buttonState.releasedThisFrame )
      {
        const pressedTarget = self.pointer.getButton( button ).pressedWidget;
        const pressed = handleFromTarget( pressedTarget );

        if( button == .left and pressed.isValid() and pressed.isEq( hovered ))
        {
          if( self.getWidgetPtr( hovered ))| widget |
          {
            if( widget.isInteractive() )
            {
              switch( widget.kind )
              {
                .button => self.pushEvent( .{ .eType = .clicked, .widget = hovered } ),

                .checkbox =>
                {
                  widget.state.isChecked = !widget.state.isChecked;
                  self.markRenderDirty();
                  self.pushEvent( .{ .eType = .changed, .widget = hovered } );
                },

                else => {},
              }
            }
          }
        }

        self.pointer.setPressedWidget( button, .{} );
      }
    }
  }

  pub fn hitTest( self : *Panel, point : Vec2 ) UiHandle
  {
    self.updateLayout();
    self.updateHitMap();

    var i = self.hits.items.len;
    while( i > 0 )
    {
      i -= 1;

      const hit = self.hits.items[ i ];
      if( hit.box.isOnPoint( point )){ return hit.widget; }
    }

    return .{};
  }

  fn updateHitMap( self : *Panel ) void
  {
    if( !self.dirty.hit ){ return; }

    self.hits.clearRetainingCapacity();
    self.appendHitChildrenOf( .{} );

    self.dirty.hit = false;
  }

  fn appendHitChildrenOf( self : *Panel, parent : UiHandle ) void
  {
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !widget.isAlive or !widget.state.isVisible ){ continue; }

      if( widget.isInteractive() )
      {
        self.hits.append( self.alloc, .{ .widget = widget.id, .box = widget.finalBox }) catch | err |
        {
          utl.log( .ERROR, 0, @src(), "Failed to append UI hit entry : {}", .{ err });
          return;
        };
      }

      self.appendHitChildrenOf( widget.id );
    }
  }

  fn pushEvent( self : *Panel, event : UiEvent ) void
  {
    self.events.append( self.alloc, event ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to append UI event : {}", .{ err });
      return;
    };
  }

  pub fn popEvent( self : *Panel ) ?UiEvent
  {
    if( self.events.items.len == 0 ){ return null; }
    return self.events.orderedRemove( 0 );
  }

  /// Non-consuming queue scan. This returns true while a matching clicked event
  /// is still queued, so callers that use `popEvent()` first will not see it.
  pub fn wasClicked( self : *const Panel, id : UiHandle ) bool
  {
    for( self.events.items )| event |
    {
      if( event.isClicked( id )){ return true; }
    }

    return false;
  }


  // ================================ DRAWING ================================

  pub fn draw( self : *Panel ) void
  {
    self.updateLayout();

    drawBox( self.box, self.config.style.fillCol, self.config.style.edgeCol, self.config.style.lineWidth );
    self.drawChildrenOf( .{} );

    if( self.debugDrawBounds ){ self.drawDebugBounds(); }

    self.dirty.render = false;
  }

  fn drawChildrenOf( self : *Panel, parent : UiHandle ) void
  {
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !widget.isAlive or !widget.state.isVisible ){ continue; }

      self.drawWidget( widget );
      self.drawChildrenOf( widget.id );
    }
  }

  fn drawWidget( self : *Panel, widget : *const Widget ) void
  {
    const hovered = self.pointer.topWidget.isEq( targetFromHandle( widget.id ) );
    const pressed = self.pointer.getButton( .left ).pressedWidget.isEq( targetFromHandle( widget.id ) ) and self.pointer.isDown( .left );

    switch( widget.kind )
    {
      .label =>
      {
        if( widget.textLen > 0 ){ self.drawWidgetText( widget ); }
      },

      .button =>
      {
        drawBox( widget.finalBox, widget.style.fillFor( hovered, pressed ), widget.style.edgeCol, widget.style.lineWidth );
        if( widget.textLen > 0 ){ self.drawWidgetText( widget ); }
      },

      .checkbox =>
      {
        drawBox( widget.finalBox, widget.style.fillFor( hovered, pressed ), widget.style.edgeCol, widget.style.lineWidth );

        const markSize = @max( 0.0, @min( widget.finalBox.getSizeY() - ( widget.padding * 2.0 ), 18.0 ));
        const markBox  = boxFromTopLeft( widget.finalBox.getTopLeft().add( .new( widget.padding, widget.padding )), .new( markSize, markSize ));

        drawBox( markBox, Colour.transpa, widget.style.edgeCol, widget.style.lineWidth );
        if( widget.state.isChecked )
        {
          drawBox( markBox.subScale( .new( @min( 4.0, markBox.scale.x ), @min( 4.0, markBox.scale.y ) )), widget.style.accentCol, Colour.transpa, 0.0 );
        }

        if( widget.textLen > 0 )
        {
          drawTextLeft( widget.getText(), widget.textMetrics.drawOrigin, widget.style.fontSize, widget.style.textCol );
        }
      },

      .spacer, .container =>
      {
        if( widget.style.fillCol.a > 0 or widget.style.lineWidth > 0.0 )
        {
          drawBox( widget.finalBox, widget.style.fillCol, widget.style.edgeCol, widget.style.lineWidth );
        }
      },

      .customDraw => {},
    }
  }

  fn drawWidgetText( self : *Panel, widget : *const Widget ) void
  {
    _ = self;

    switch( widget.textAlign )
    {
      .left   => drawTextLeft(   widget.getText(), widget.textMetrics.drawOrigin, widget.style.fontSize, widget.style.textCol ),
      .center => drawTextCenter( widget.getText(), widget.textMetrics.drawOrigin, widget.style.fontSize, widget.style.textCol ),
    }
  }

  fn drawDebugBounds( self : *Panel ) void
  {
    drawBox( self.box, Colour.transpa, Colour.pGold, 1.0 );

    self.drawDebugChildrenOf( .{} );
  }

  fn drawDebugChildrenOf( self : *Panel, parent : UiHandle ) void
  {
    var cursor : ?u32 = null;

    while( self.getNextChildIndex( parent, cursor ))| idx |
    {
      const widget = &self.widgets.items[ idx ];
      cursor = widget.order;

      if( !widget.isAlive or !widget.state.isVisible ){ continue; }
      drawBox( widget.finalBox, Colour.transpa, Colour.pTeal, 1.0 );
      if( widget.textLen > 0 ){ drawBox( widget.textMetrics.textBox, Colour.transpa, Colour.pGold, 1.0 ); }

      self.drawDebugChildrenOf( widget.id );
    }
  }
};


// ================================ HELPERS ================================

pub inline fn boxFromTopLeft( topLeft : Vec2, size : Vec2 ) Box2
{
  return .{
    .center = topLeft.add( size.mulVal( 0.5 )),
    .scale  = size.mulVal( 0.5 ),
  };
}

fn targetFromHandle( handle : UiHandle ) utl.MouseUiTarget
{
  if( !handle.isValid() ){ return .{}; }
  return .fromId(( @as( u64, handle.gen ) << 32 ) | @as( u64, handle.idx ));
}

fn handleFromTarget( target : utl.MouseUiTarget ) UiHandle
{
  if( !target.isValid() ){ return .{}; }

  const idx : u32 = @truncate( target.id );
  const gen : u32 = @truncate( target.id >> 32 );
  if( idx == UiHandle.invalidIndex or gen == 0 ){ return .{}; }

  return .fromIndexGen( idx, gen );
}

fn getTextDrawOrigin( widget : *const Widget ) Vec2
{
  if( widget.kind == .checkbox )
  {
    const markSize = @max( 0.0, @min( widget.finalBox.getSizeY() - ( widget.padding * 2.0 ), 18.0 ));
    const markBox  = boxFromTopLeft( widget.finalBox.getTopLeft().add( .new( widget.padding, widget.padding )), .new( markSize, markSize ));

    return Vec2.new( markBox.getMaxX() + widget.padding, widget.finalBox.center.y );
  }

  return switch( widget.textAlign )
  {
    .left   => Vec2.new( widget.finalBox.getMinX() + widget.padding, widget.finalBox.center.y ),
    .center => widget.finalBox.center,
  };
}

fn getTextBox( widget : *const Widget, drawOrigin : Vec2, measuredSize : Vec2 ) Box2
{
  const halfSize = measuredSize.mulVal( 0.5 );

  if( widget.kind == .checkbox )
  {
    return .{ .center = drawOrigin.add( .new( halfSize.x, 0.0 )), .scale = halfSize };
  }

  return switch( widget.textAlign )
  {
    .left   => .{ .center = drawOrigin.add( .new( halfSize.x, 0.0 )), .scale = halfSize },
    .center => .{ .center = drawOrigin,                               .scale = halfSize },
  };
}

fn measureText( str : []const u8, fontSize : f64 ) Vec2
{
  var buf : [ textBufLen ]u8 = undefined;
  const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return .{};
  return Vec2.fromRayVec2( utl.ray.measureTextEx( utl.sDraw.getDefaultFont(), zStr, @floatCast( fontSize ), @floatCast( fontSize * 0.125 ) ));
}

fn drawBox( box : Box2, fillCol : Colour, edgeCol : Colour, lineWidth : f64 ) void
{
  const topLeft = box.getTopLeft();
  const size    = box.getSize();

  utl.sDraw.basicRect( topLeft, size, fillCol );
  if( lineWidth > 0.0 ){ utl.sDraw.basicRectPerim( topLeft, size, edgeCol, lineWidth ); }
}

fn drawTextLeft( str : []const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  var buf : [ textBufLen ]u8 = undefined;
  const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

  utl.sDraw.textLeft( zStr, pos, fontSize, col );
}

fn drawTextCenter( str : []const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  var buf : [ textBufLen ]u8 = undefined;
  const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

  utl.sDraw.textCenter( zStr, pos, fontSize, col );
}
