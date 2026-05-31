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
  text   : []const u8 = "",

  padding : f64 = 8.0,
  gap     : f64 = 6.0,

  isVisible      : bool = true,
  isEnabled      : bool = true,
  isModal        : bool = false,
  isDetachedRoot : bool = false,

  closeOnOutside : bool = false,
  closeOnEscape  : bool = false,

  valueBool : bool     = false,
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
