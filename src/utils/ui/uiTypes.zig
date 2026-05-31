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
  root,
  panel,
  label,
  button,
  checkbox,
  popup,
  window,
  scrollArea,
  slider,
};

pub const UiLayer = enum( u8 )
{
  hud,
  panel,
  popup,
  modal,
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
  absolute,
  vertical,
  horizontal,
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
  parent    : ?UiId = null,
  dependsOn : ?UiId = null,

  box         : def.Box2 = .{},
  desiredSize : def.Vec2 = .new( 160.0, 32.0 ),

  layout : UiLayout = .absolute,
  layer  : ?UiLayer = null,
  text   : []const u8 = "",
  tooltip : []const u8 = "",

  padding : f64 = 8.0,
  gap     : f64 = 6.0,

  isVisible      : bool = true,
  isEnabled      : bool = true,
  isModal        : bool = false,
  isDetachedRoot : bool = false,

  closeOnOutside : bool = false,
  closeOnEscape  : bool = false,

  valueBool : bool     = false,
  valueFlt  : f64      = 0.0,

  sliderMin  : f64 = 0.0,
  sliderMax  : f64 = 1.0,
  sliderStep : f64 = 0.0,

  scrollY : f64 = 0.0,

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
