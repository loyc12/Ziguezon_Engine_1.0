const std  = @import( "std" );
const eng  = @import( "engine" );
const utl = @import( "utils" );
const core = @import( "drawerCore.zig" );

const ray    = utl.ray;
const Vec2   = utl.Vec2;
const Font   = utl.Font;
const Colour = utl.Colour;


// ================================ SCREEN RENDERING ================================

const ScreenTransform = struct
{
  pub inline fn toRay( pos : Vec2 ) utl.RayVec2
  {
    return pos.toRayVec2();
  }
};

const Core = core.GetDrawer( ScreenTransform );


var DEFAULT_FONT   : Font = undefined;
var SPACING_FACTOR : f64  = 0.0;


// ================ SCREEN SPECIFIC FUNCTIONS ================

pub inline fn coverScreenWithCol( col : Colour ) void
{
  ray.drawRectangleV( utl.zeroRayVec2, utl.getScreenSize().toRayVec2(), col.toRayCol() );
}
pub inline fn surroundScreenWithCol( col : Colour, width : f64 ) void
{
  const o : Vec2 = .{};
  const c : Vec2 = utl.getScreenSize();

  // Offset to avoid overlapping transparency
  const l : f64  = o.x + ( width + utl.EPS );
  const r : f64  = c.x - ( width + utl.EPS );

  basicLine( .{ .x = l,   .y = o.y }, .{ .x = r,   .y = o.y }, col, width * 2.0 ); // Top
  basicLine( .{ .x = o.x, .y = o.y }, .{ .x = o.x, .y = c.y }, col, width * 2.0 ); // Left
  basicLine( .{ .x = c.x, .y = o.y }, .{ .x = c.x, .y = c.y }, col, width * 2.0 ); // Right
  basicLine( .{ .x = l,   .y = c.y }, .{ .x = r,   .y = c.y }, col, width * 2.0 ); // Bottom
}
pub inline fn clearBackground( col : Colour ) void
{
  ray.clearBackground( col.toRayCol() );
}


// ================ CORE DRAWING FUNCTIONS ================

pub const BASE_LINE_WIDTH = Core.BASE_LINE_WIDTH;

pub const pixel           = Core.pixel;
pub const macroPixel      = Core.macroPixel;

pub const basicLine       = Core.basicLine;
pub const basicCircle     = Core.basicCircle;
pub const basicCirclePerim = Core.basicCirclePerim;

pub const basicElli       = Core.basicElli;
pub const basicElliPerim  = Core.basicElliPerim;

pub const basicRect       = Core.basicRect;
pub const basicRectPerim  = Core.basicRectPerim;

pub const basicTria       = Core.basicTria;
pub const basicTriaPerim  = Core.basicTriaPerim;

pub const basicQuad       = Core.basicQuad;
pub const basicQuadPerim  = Core.basicQuadPerim;

pub const basicPoly       = Core.basicPoly;
pub const basicPolyPerim  = Core.basicPolyPerim;

pub const tria            = Core.tria;
pub const diam            = Core.diam;
pub const pent            = Core.pent;
pub const hexa            = Core.hexa;
pub const octa            = Core.octa;
pub const elli            = Core.elli;

pub const rect            = Core.rect;
pub const rectPerim       = Core.rectPerim;

pub const poly            = Core.poly;
pub const polyPerim       = Core.polyPerim;

pub const star            = Core.star;
pub const starPerim       = Core.starPerim;

pub const texture         = Core.texture;
pub const textureCentered = Core.textureCentered;
pub const texturePro      = Core.texturePro;


// ================ TEXT DRAWING FUNCTIONS ================

pub fn getDefaultFont() Font { return DEFAULT_FONT; }

pub fn setDefaultFont( fontPath : ?[:0] const u8 ) bool
{
  if( fontPath ) | path |
  {
    const result = Font.init( path );

    if( result )| font |
    {

      utl.log( .DEBUG, 0, @src(), "& Default font params : baseSize = {}, glyphCount = {}, texture id = {}", .{ font.baseSize, font.glyphCount, font.texture.id });

      if( font.isReady() )
      {
        DEFAULT_FONT = font;
        return true;
      }
      else { utl.qlog( .ERROR, 0, @src(), "Invalid font : " ); }

      if( font.glyphCount == 0 ) { utl.qlog( .CONT, 0, @src(), "( glyphCount == 0 )" ); }
      if( font.texture.id == 0 ) { utl.qlog( .CONT, 0, @src(), "( texture id == 0 )" ); }
    }
    else | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to set default font : {}", .{ err });
      utl.qlog( .CONT, 0, @src(), "Defaulting to raylib defaults" );
    }
  }

  SPACING_FACTOR = 1.0 / 8.0;
  DEFAULT_FONT = ray.getFontDefault() catch @panic( "Failed to get raylib default font" );
  return false;
}


pub inline fn text( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  ray.drawTextEx( DEFAULT_FONT, str, ScreenTransform.toRay( pos ), @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ), col.toRayCol() );
}

pub inline fn textFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  var   buf : [ 1024 ]u8 = undefined;
  const str = std.fmt.bufPrintZ( &buf, fmt, args ) catch @panic( "textCenterFmt : Formatted text too long" );

  text( str, pos, fontSize, col );
}

// Non-upper-left alignement
pub inline fn textOffset( str : [:0] const u8, pos : Vec2, factors : Vec2, fontSize : f64, col : Colour ) void
{
  const textDims     = ray.measureTextEx( DEFAULT_FONT, str, @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ) );
  const textHalfSize = factors.mul( .{ .x = textDims.x, .y = textDims.y });

  text( str, pos.sub( textHalfSize ), fontSize, col );
}

pub inline fn textOffsetFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, factors : Vec2, fontSize : f64, col : Colour ) void
{
  var   buf : [ 1024 ]u8 = undefined;
  const str = std.fmt.bufPrintZ( &buf, fmt, args ) catch @panic( "textCenterFmt : Formatted text too long" );

  const textDims     = ray.measureTextEx( DEFAULT_FONT, str, @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ));
  const textHalfSize = factors.mul( .{ .x = textDims.x, .y = textDims.y });

  text( str, pos.sub( textHalfSize ), @floatCast( fontSize ), col );
}

// Center aligned
pub inline fn textCenter( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffset( str, pos, .new( 0.5, 0.5 ), fontSize, col );
}
pub inline fn textCenterFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffsetFmt( fmt, args, pos, .new( 0.5, 0.5 ), fontSize, col );
}

// Center-right aligned
pub inline fn textRight( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffset( str, pos, .new( 1.0, 0.5 ), fontSize, col );
}
pub inline fn textRightFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffsetFmt( fmt, args, pos, .new( 1.0, 0.5 ), fontSize, col );
}

// Bottom-center aligned
pub inline fn textBottom( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffset( str, pos, .new( 0.5, 1.0 ), fontSize, col );
}
pub inline fn textBottomFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffsetFmt( fmt, args, pos, .new( 0.5, 1.0 ), fontSize, col );
}

// Center-right aligned
pub inline fn textLeft( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffset( str, pos, .new( 0.0, 0.5 ), fontSize, col );
}
pub inline fn textLeftFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffsetFmt( fmt, args, pos, .new( 0.0, 0.5 ), fontSize, col );
}

// Bottom-center aligned
pub inline fn textTop( str : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffset( str, pos, .new( 0.5, 0.0 ), fontSize, col );
}
pub inline fn textTopFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  textOffsetFmt( fmt, args, pos, .new( 0.5, 0.0 ), fontSize, col );
}
