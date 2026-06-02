const std = @import( "std" );
const def = @import( "defs" );

// ================================ UI IDENTIFIERS ================================

pub const UiId = struct
{
  /// Sentinel index for "no node"; real nodes use direct zero-based array indices.
  pub const invalidIndex : u32 = std.math.maxInt( u32 );

  idx : u32 = invalidIndex,
  gen : u32 = 0,

  pub inline fn none() UiId { return .{}; }
  pub inline fn fromIndexGen( idx : u32, gen : u32 ) UiId { return .{ .idx = idx, .gen = gen }; }

  pub inline fn isValid( self : UiId ) bool { return self.idx < invalidIndex; }

  pub inline fn isEq( self : UiId, other : UiId ) bool
  {
    return self.idx == other.idx and self.gen == other.gen;
  }
};


// ================================ NODE TYPES ================================

pub const UiNodeKind = enum( u8 )
{
  /// Top-level layout holder, usually for HUD-space UI.
  root,

  /// Generic rectangular menu/container for debug panels and grouped controls.
  panel,

  /// Non-interactive text widget; it draws text but does not capture pointer input.
  label,

  /// Action widget; emits a clicked event on press-release over the same node.
  button,

  /// Boolean widget; toggles valueBool and emits a changed event when clicked.
  checkbox,

  /// Temporary menu/container styled and layered above normal panels.
  popup,

  /// Independent menu/container styled as a window; optional flags define closability or movement.
  window,

  /// Container that clips child rendering and offsets vertical child layout by scrollY.
  scrollArea,

  /// Horizontal numeric widget; dragging updates valueFlt and emits changed events.
  slider,
};

/// Layer is the shared draw/input priority band. Higher layers draw later and hit-test first.
pub const UiLayer = enum( u8 )
{
  /// Background UI/HUD layer.
  hud,

  /// Normal panel/window/widget layer.
  panel,

  /// Transient menu layer above normal panels.
  popup,

  /// Blocking menu layer; modal nodes suppress unrelated lower UI interaction.
  modal,

  /// Top visual-only layer for tooltip drawing; it never receives input.
  tooltip,

  pub const count = @typeInfo( UiLayer ).@"enum".fields.len;

  pub inline fn fromIndex( i : usize ) UiLayer
  {
    return @enumFromInt( @as( u8, @intCast( i )));
  }

  pub inline fn defaultFor( kind : UiNodeKind, isModal : bool ) UiLayer
  {
    if( isModal ){ return .modal; }

    return switch( kind )
    {
      .popup       => .popup,
      .root        => .hud,
      .panel,
      .label,
      .button,
      .checkbox,
      .window,
      .scrollArea,
      .slider      => .panel,
    };
  }

  pub inline fn isInputLayer( self : UiLayer ) bool
  {
    return self != .tooltip;
  }
};

pub const UiLayout = enum( u8 )
{
  /// Children use local Box2 positions relative to the parent's top-left corner.
  absolute,

  /// Children stack top-to-bottom with padding and gap.
  vertical,

  /// Children stack left-to-right with padding and gap.
  horizontal,

  /// Currently equivalent to absolute; reserved for free-positioned child surfaces.
  floating,
};

pub const UiEventType = enum( u8 )
{
  clicked,
  changed,
  closed,
};

pub const UiEvent = struct
{
  eType     : UiEventType = .clicked,
  node      : UiId        = .{},
  valueBool : bool        = false,
  valueFlt  : f64         = 0.0,
};


// ================================ STYLE DATA ================================

pub const UiStyle = struct
{
  fillCol        : def.Colour = def.Colour.nBlack.setA( 230 ),
  fillHoverCol   : def.Colour = def.Colour.sGray.setA(  240 ),
  fillPressedCol : def.Colour = def.Colour.sGray.setA(  245 ),

  edgeCol        : def.Colour = def.Colour.lGray,
  edgeFocusCol   : def.Colour = def.Colour.pGold,

  textCol        : def.Colour = def.Colour.nWhite,
  mutedTextCol   : def.Colour = def.Colour.lGray,
  accentCol      : def.Colour = def.Colour.pTeal,

  lineWidth : f64  = 2.0,
  fontSize  : f64  = 16.0,

  pub inline fn fillForState( self : UiStyle, hovered : bool, pressed : bool ) def.Colour
  {
    if( pressed ){ return self.fillPressedCol; }
    if( hovered ){ return self.fillHoverCol;   }
    return self.fillCol;
  }

  pub fn forKind( kind : UiNodeKind ) UiStyle
  {
    var style : UiStyle = .{};

    switch( kind )
    {
      .root, .panel =>
      {
        style.fillCol      = def.Colour.nBlack.setA( 230 );
        style.edgeCol      = def.Colour.mGray;
        style.mutedTextCol = def.Colour.lGray;
      },

      .label =>
      {
        style.fillCol = def.Colour.transpa;
        style.edgeCol = def.Colour.transpa;
      },

      .button =>
      {
        style.fillCol        = def.Colour.sGray.setA( 240 );
        style.fillHoverCol   = def.Colour.sGray.setA( 245 );
        style.fillPressedCol = def.Colour.dGray.setA( 250 );
        style.edgeCol        = def.Colour.lGray;
      },

      .checkbox =>
      {
        style.fillCol        = def.Colour.nBlack.setA( 230 );
        style.fillHoverCol   = def.Colour.sGray.setA( 240 );
        style.fillPressedCol = def.Colour.sGray.setA( 245 );
      },

      .popup =>
      {
        style.fillCol      = def.Colour.nBlack.setA( 248 );
        style.edgeCol      = def.Colour.pGray;
        style.edgeFocusCol = def.Colour.pGold;
      },

      .window =>
      {
        style.fillCol      = def.Colour.nBlack.setA( 245 );
        style.edgeCol      = def.Colour.pOrange;
        style.edgeFocusCol = def.Colour.pGold;
      },

      .scrollArea =>
      {
        style.fillCol      = def.Colour.nBlack.setA( 210 );
        style.edgeCol      = def.Colour.sGray;
        style.edgeFocusCol = def.Colour.pGold;
      },

      .slider =>
      {
        style.fillCol        = def.Colour.nBlack.setA( 230 );
        style.fillHoverCol   = def.Colour.sGray.setA( 240 );
        style.fillPressedCol = def.Colour.sGray.setA( 245 );
        style.edgeCol        = def.Colour.lGray;
        style.accentCol      = def.Colour.pTeal;
      },
    }

    return style;
  }
};


// ================================ CREATION OPTIONS ================================

pub const UiNodeOpts = struct
{
  /// Parent owns layout lifetime; closing the parent closes this child.
  parent    : ?UiId = null,

  /// Dependency owns transient lifetime; closing the dependency closes this node.
  dependsOn : ?UiId = null,

  /// Requested local rectangle. Roots use it directly; children use it relative to their parent.
  box         : def.Box2 = .{},

  /// Preferred size used by parent layouts; <= 0 on the layout axis means fill available space.
  desiredSize : def.Vec2 = .new( 160.0, 32.0 ),

  /// Layout rule this node applies to its direct children.
  layout : UiLayout = .absolute,

  /// Optional explicit layer. Children inherit parent layer when this is omitted.
  layer  : ?UiLayer = null,

  /// Fixed-buffer node text.
  text   : []const u8 = "",

  /// Fixed-buffer hover text shown by the tooltip overlay after a short delay.
  tooltip : []const u8 = "",

  padding : f64 = 8.0,
  gap     : f64 = 6.0,

  isVisible      : bool = true,
  isEnabled      : bool = true,

  /// Modal nodes block lower/non-descendant UI and set both wantsMouse and wantsKeyboard.
  isModal        : bool = false,

  /// Movable nodes drag by mouseDelta while directly pressed.
  isMovable      : bool = false,

  /// Stored marker for independent root surfaces; no special core behavior yet.
  isDetachedRoot : bool = false,

  /// If true, clicking outside this node and its descendants closes it.
  closeOnOutside : bool = false,

  /// If true, Escape closes this node when it is the frontmost eligible transient.
  closeOnEscape  : bool = false,

  /// Boolean widget state and bool event payload.
  valueBool : bool     = false,

  /// Numeric widget state and float event payload.
  valueFlt  : f64      = 0.0,

  /// Slider minimum value.
  sliderMin  : f64 = 0.0,

  /// Slider maximum value.
  sliderMax  : f64 = 1.0,

  /// Slider step size; <= 0 means continuous.
  sliderStep : f64 = 0.0,

  /// Vertical scroll offset for scrollArea nodes.
  scrollY : f64 = 0.0,

  /// Optional style override; otherwise UiStyle.forKind(kind) is used.
  style     : ?UiStyle = null,
};


// ================================ HELPERS ================================

pub inline fn boxFromTopLeft( topLeft : def.Vec2, size : def.Vec2 ) def.Box2
{
  // UI callers usually think in top-left + size, while Box2 stores center + half-scale.
  return .{
    .center = topLeft.add( size.mulVal( 0.5 )),
    .scale  = size.mulVal( 0.5 ),
  };
}

pub inline fn boxSize( box : def.Box2 ) def.Vec2
{
  return box.getSize();
}
