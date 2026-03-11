const std  = @import( "std" );
const def  = @import( "defs" );

const ray     = def.ray;
const Vec2    = def.Vec2;
const Font    = def.Font;
const Angle   = def.Angle;
const Colour  = def.Colour;
const RayRect = def.RayRect;


pub const BASE_LINE_WIDTH : f64 = 2.0; // TODO : Move to engine settings


var DEFAULT_FONT   : Font = undefined;
var SPACING_FACTOR : f64  = 0.0;


// ================================ SCREEN RENDERING ================================

// Used in world render to cancel-out camera position
inline fn toRay( pos : Vec2 ) def.RayVec2
{
  return pos.toRayVec2();
}


// ================ SIMPLE DRAWING FUNCTIONS ================

pub inline fn coverScreenWithCol( col : Colour ) void
{
  ray.drawRectangleV( def.zeroRayVec2, def.getScreenSize().toRayVec2(), col.toRayCol() );
}
pub inline fn clearBackground( col : Colour ) void
{
  ray.clearBackground( col.toRayCol() );
}


pub inline fn drawScreenPixel( pos : Vec2, col : Colour ) void
{
  ray.drawPixelV( toRay( pos ), col.toRayCol() );
}
pub inline fn drawMacroPixel( pos : Vec2, size : f64, col : Colour ) void
{
  ray.drawRectangleV( toRay( pos ), @floatCast( size ), col.toRayCol() );
}

pub inline fn drawLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f64 ) void
{
  ray.drawLineEx( toRay( p1 ), toRay( p2 ), @floatCast( width ), col.toRayCol() );
}
// pub fn drawDotedLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f64, spacinf : f64 ) void

pub inline fn drawCircle( pos : Vec2, radius : f64, col : Colour ) void
{
  ray.drawCircleV( toRay( pos ), @floatCast( radius), col.toRayCol() );
}
pub inline fn drawCircleLines( pos : Vec2, radius : f64, col : Colour ) void // TODO : Add line thickness
{
  ray.drawCircleLinesV( pos, @floatCast( radius ), col.toRayCol() );
}

pub inline fn drawSimpleEllipse( pos : Vec2, radii : Vec2, col : Colour ) void
{
  ray.drawEllipseV( toRay( pos ), @floatCast( radii.x ), @floatCast( radii.y ), col.toRayCol() );
}
pub inline fn drawSimpleEllipseLines( pos : Vec2, radii : Vec2, col : Colour ) void // TODO : Add line thickness
{
  ray.drawEllipseLinesV( toRay( pos ), @floatCast( radii.x ), @floatCast( radii.y ), col.toRayCol() );
}

pub inline fn drawSimpleRectangle( pos : Vec2, size : Vec2, col : Colour ) void
{
  ray.drawRectangleV( toRay( pos ), size.toRayVec2(), col.toRayCol() );
}
pub inline fn drawSimpleRectangleLines( pos : Vec2, size : Vec2, col : Colour, width : f64  ) void
{
  ray.drawRectangleLinesEx(
    RayRect
    {
      .x      = @floatCast( pos.x ),
      .y      = @floatCast( pos.y ),
      .width  = @floatCast( size.x ),
      .height = @floatCast( size.y )
    },
    @floatCast( width ),
    col.toRayCol()
  );
}

// TODO : Add a drawSimplePolygon( Lines ) function


// ================ BASIC DRAWING FUNCTIONS ================

pub inline fn drawBasicTria( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour ) void
{
  ray.drawTriangle( toRay( p1 ), toRay( p2 ), toRay( p3 ), col.toRayCol() );
}
pub inline fn drawBasicTriaLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour, width : f32 ) void
{
  ray.drawLineEx( toRay( p1 ), toRay( p2 ), width, col.toRayCol() );
  ray.drawLineEx( toRay( p2 ), toRay( p3 ), width, col.toRayCol() );
  ray.drawLineEx( toRay( p3 ), toRay( p1 ), width, col.toRayCol() );
}

pub inline fn drawBasicQuad( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour ) void
{
  ray.drawTriangle( toRay( p1 ), toRay( p2 ), toRay( p3 ), col.toRayCol() );
  ray.drawTriangle( toRay( p3 ), toRay( p4 ), toRay( p1 ), col.toRayCol() );
}
pub inline fn drawBasicQuadLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour, width : f32  ) void
{
  ray.drawLineEx( toRay( p1 ), toRay( p2 ), width, col.toRayCol() );
  ray.drawLineEx( toRay( p2 ), toRay( p3 ), width, col.toRayCol() );
  ray.drawLineEx( toRay( p3 ), toRay( p4 ), width, col.toRayCol() );
  ray.drawLineEx( toRay( p4 ), toRay( p1 ), width, col.toRayCol() );
}

pub inline fn drawBasicPoly( pos : Vec2, radius : f64, a : Angle, col : Colour, sides : u16 ) void
{
  ray.drawPoly( toRay( pos ), @intCast( sides ), @floatCast( radius ), def.RtD( a ), col.toRayCol() );
}
pub inline fn drawBasicPolyLines( pos : Vec2, radius : f64, a : Angle, col : Colour, width : f64, sides : u16  ) void // TODO : Add line thickness
{
  ray.drawPolyLinesEx( toRay( pos ), @intCast( sides ), @floatCast( radius ), def.RtD( a ), @floatCast( width ), col.toRayCol() );
}


// ================ ADVANCED DRAWING FUNCTIONS ================

pub inline fn drawTrianglePlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 3 ); }
pub inline fn drawDiamondPlus(  pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 4 ); }
pub inline fn drawPentagonPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 5 ); }
pub inline fn drawHexagonPlus(  pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 6 ); }

// Draws a rectangle centered at a given position with specified rotation (rad), colour and size, and scaled in x/y by radii
pub inline fn drawRectanglePlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour) void
{
  drawBasicQuad(
    pos.add( Vec2.new(  radii.x,  radii.y ).rot( a )),
    pos.add( Vec2.new(  radii.x, -radii.y ).rot( a )),
    pos.add( Vec2.new( -radii.x, -radii.y ).rot( a )),
    pos.add( Vec2.new( -radii.x,  radii.y ).rot( a )),
    col
  );
}

// Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
pub fn drawPolygonPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16 ) void
{
  if( sides < 1 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with 0 sides" );
    return;
  }

  const N : f32 = @floatFromInt( sides );
  const sideStepAngle = Angle.newRad( def.TAU / N );
  const rP0 = Vec2.new( radii.x, 0.0 ).rot( a );

  if( sides < 3 ) // NOTE : only for radius or diametre lines
  {
    const rP1 = Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a );

    if( sides == 1 ){ drawLine( pos, pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
    else { drawLine( pos.add( rP1.flp() ), pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
  }
  else if( @abs( radii.x - radii.y ) > def.EPS ) // NOTE : slower, but accounts for non isoscalar polygons
  {
    var rP1 = Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a );

    for( 2..sides )| i |
    {
      const angle = sideStepAngle.mulVal( @floatFromInt( i ));
      const rP2 = Vec2.fromAngleScaled( angle, radii ).rot( a );

      drawBasicTria( pos.add( rP0 ), pos.add( rP2 ), pos.add( rP1 ), col );
      rP1 = rP2;
    }
  }
  else // NOTE : slightly faster, but requires isoscalar polygons
  {
    var rP1 = rP0.rot( sideStepAngle );

    for( 2..sides )| i |
    {
      const angle = sideStepAngle.mulVal( @floatFromInt( i ));
      const rP2 = rP0.rot( angle );

      drawBasicTria( pos.add( rP0 ), pos.add( rP2 ), pos.add( rP1 ), col );
      rP1 = rP2;
    }
  }
}

pub fn drawStarPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, skipFactor : u16 ) void
{
  if( sides < 5 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot draw a star with fewer than 5 vertices" );
    return;
  }

  if( skipFactor == 1 )
  {
    def.qlog( .WARN, 0, @src(), "Not a star : drawing a polygon instead" );
    drawPolygonPlus( pos, radii, a, col, sides );
    return;
  }

  const N : f32 = @floatFromInt( sides );
  const sideStepAngle : Angle = Angle.newRad( def.TAU / N );

  // Precompute all vertex positions
  var verts : [ 32 ]Vec2 = undefined; // 32 is enough for all defined star shapes FOR NOW

  if( @abs( radii.x - radii.y ) > def.EPS ) // NOTE : slower, but accounts for non isoscalar polygons
  {
    for( 0..sides )| i |
    {
      const angle = sideStepAngle.mulVal( @floatFromInt( i ));
      verts[ i ]  = Vec2.fromAngleScaled( angle, radii ).rot( a );
    }
  }
  else // NOTE : slightly faster, but requires isoscalar polygons
  {
    for( 0..sides )| i |
    {
      const angle = sideStepAngle.mulVal( @floatFromInt( i ));
      verts[ i ]  = Vec2.new( radii.x, 0.0 ).rot( a.add( angle ));
    }
  }

  // Connect vertices by skipFactor step, drawing lines between them
  // NOTE : We need to traverse enough steps to close all sub-paths

  const gcdenom = def.gcd( @as( u32, sides ), @as( u32, skipFactor )); // TODO : Implement me
  const pathLen = @divFloor( sides, gcdenom ); // Number of vertices per sub-path

  for( 0..gcdenom )| startIdx |
  {
    var idx1 : usize = startIdx;

    for( 0..pathLen )| _ |
    {
      const idx2 = ( idx1 + skipFactor ) % sides;
      drawBasicTria( pos, pos.add( verts[ idx2 ]), pos.add( verts[ idx1 ] ), col );
      idx1 = idx2;
    }
  }
}


// ================ TEXT DRAWING FUNCTIONS ================

pub fn getDefaultFont() Font { return DEFAULT_FONT; }

pub fn setDefaultFont( fontPath : ?[:0] const u8 ) bool
{
  if( fontPath ) | path |
  {
    const result = Font.init( path );

    if( result )| font |
    {

      def.log( .DEBUG, 0, @src(), "Default font params : baseSize = {}, glyphCount = {}, texture id = {}", .{ font.baseSize, font.glyphCount, font.texture.id });

      if( font.isReady() )
      {
        DEFAULT_FONT = font;
        return true;
      }
      else { def.qlog( .ERROR, 0, @src(), "Invalid font : " ); }

      if( font.glyphCount == 0 ) { def.qlog( .CONT, 0, @src(), "( glyphCount == 0 )" ); }
      if( font.texture.id == 0 ) { def.qlog( .CONT, 0, @src(), "( texture id == 0 )" ); }
    }
    else | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to set default font : {}", .{ err });
      def.qlog( .CONT, 0, @src(), "Defaulting to raylib defaults" );
    }
  }

  SPACING_FACTOR = 1.0 / 8.0;
  DEFAULT_FONT = ray.getFontDefault() catch @panic( "Failed to get raylib default font" );
  return false;
}


pub inline fn drawText( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  ray.drawTextEx( DEFAULT_FONT, text, toRay( pos ), @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ), col.toRayCol() );
}

pub inline fn drawTextFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  var   buf : [ 1024 ]u8 = undefined;
  const text = std.fmt.bufPrintZ( &buf, fmt, args ) catch @panic( "drawTextCenterFmt : Formatted text too long" );

  drawText( text, pos, fontSize, col );
}

// Non-upper-left alignement
pub inline fn drawTextOffset( text : [:0] const u8, pos : Vec2, factors : Vec2, fontSize : f64, col : Colour ) void
{
  const textDims     = ray.measureTextEx( DEFAULT_FONT, text, @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ) );
  const textHalfSize = factors.mul( .{ .x = textDims.x, .y = textDims.y });

  drawText( text, pos.sub( textHalfSize ), fontSize, col );
}

pub inline fn drawTextOffsetFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, factors : Vec2, fontSize : f64, col : Colour ) void
{
  var   buf : [ 1024 ]u8 = undefined;
  const text = std.fmt.bufPrintZ( &buf, fmt, args ) catch @panic( "drawTextCenterFmt : Formatted text too long" );

  const textDims     = ray.measureTextEx( DEFAULT_FONT, text, @floatCast( fontSize ), @floatCast( fontSize * SPACING_FACTOR ));
  const textHalfSize = factors.mul( .{ .x = textDims.x, .y = textDims.y });

  drawText( text, pos.sub( textHalfSize ), @floatCast( fontSize ), col );
}

// Center aligned
pub inline fn drawTextCenter( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffset( text, pos, .new( 0.5, 0.5 ), fontSize, col );
}
pub inline fn drawTextCenterFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffsetFmt( fmt, args, pos, .new( 0.5, 0.5 ), fontSize, col );
}

// Center-right aligned
pub inline fn drawTextRight( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffset( text, pos, .new( 1.0, 0.5 ), fontSize, col );
}
pub inline fn drawTextRightFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffsetFmt( fmt, args, pos, .new( 1.0, 0.5 ), fontSize, col );
}

// Bottom-center aligned
pub inline fn drawTextBottom( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffset( text, pos, .new( 0.5, 1.0 ), fontSize, col );
}
pub inline fn drawTextBottomFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffsetFmt( fmt, args, pos, .new( 0.5, 1.0 ), fontSize, col );
}

// Center-right aligned
pub inline fn drawTextLeft( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffset( text, pos, .new( 0.0, 0.5 ), fontSize, col );
}
pub inline fn drawTextLeftFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffsetFmt( fmt, args, pos, .new( 0.0, 0.5 ), fontSize, col );
}

// Bottom-center aligned
pub inline fn drawTextTop( text : [:0] const u8, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffset( text, pos, .new( 0.5, 0.0 ), fontSize, col );
}
pub inline fn drawTextTopFmt( comptime fmt : [:0] const u8, args : anytype, pos : Vec2, fontSize : f64, col : Colour ) void
{
  drawTextOffsetFmt( fmt, args, pos, .new( 0.5, 0.0 ), fontSize, col );
}



// ================ TEXTURE DRAWING FUNCTIONS ================

pub inline fn drawTexture( image : ray.Texture2D, pos : Vec2, a : Angle, scale : Vec2, col : Colour ) void
{
  ray.drawTextureEx( image, toRay( pos ), a, scale.x, col.toRayCol() );
}

pub inline fn drawTextCenterure( image : ray.Texture2D, pos : Vec2, a : Angle, scale : Vec2, col : Colour ) void
{
  const halfWidth  = @as( f64, @floatFromInt( image.width  )) * scale.x / 2.0;
  const halfHeight = @as( f64, @floatFromInt( image.height )) * scale.y / 2.0;
  drawTexture( image, @floatCast( pos.x - halfWidth ), @floatCast( pos.y - halfHeight ), a, scale, col );
}

pub inline fn drawTexturePlus( image : ray.Texture2D, source : RayRect, dest : RayRect, origin : Vec2, a : Angle, col : Colour ) void
{
  ray.drawTexturePro( image, source, dest, origin, a.toDeg(), col.toRayCol() );
}
