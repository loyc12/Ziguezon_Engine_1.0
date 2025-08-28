const std  = @import( "std" );
const def  = @import( "defs" );

const ray    = def.ray;
const Vec2   = def.Vec2;
const Angle  = def.Angle;
const Colour = def.Colour;

const ELLIPSE_SIDE_COUNT: u8 = 32; // Number of sides for the ellipse polygon approximation

// ================ SCREEN FUNCTIONS ================

//pub inline fn isPixelInScreen( pos : Vec2 ) bool
//{
//  const screenSize = def.getScreenSize();
//  return pos.x >= 0 and pos.x <= screenSize.x and pos.y >= 0 and pos.y <= screenSize.y;
//}
//pub inline fn isPixelNearScreen( pos : Vec2, offset : Vec2 ) bool
//{
//  const screenSize = def.getScreenSize();
//  return(
//    pos.x >= -offset.x and pos.x <= offset.x + screenSize.x and
//    pos.y >= -offset.y and pos.y <= offset.y + screenSize.y
//  );
//}

pub inline fn coverScreenWith( col : Colour ) void { ray.drawRectangleV( def.zeroRayVec2, def.getScreenSize().toRayVec2(), col ); }


// ================ SIMPLE DRAWING FUNCTIONS ================

pub inline fn drawPixel( pos : Vec2, col : Colour ) void
{
  ray.drawPixelV( pos.toRayVec2(), col );
}
pub inline fn drawMacroPixel( pos : Vec2, size : f32, col : Colour ) void
{
  ray.drawRectangleV( pos.toRayVec2(), size, col );
}

pub inline fn drawLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f32 ) void
{
  ray.drawLineEx( p1.toRayVec2(), p2.toRayVec2(), width, col );
}
// pub fn drawDotedLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f32, spacinf : f32 ) void

pub inline fn drawCircle( pos : Vec2, radius : f32, col : Colour ) void
{
  ray.drawCircleV( pos.toRayVec2(), radius, col );
}
pub inline fn drawCircleLines( pos : Vec2, radius : f32, col : Colour ) void // TODO : Add line thickness
{
  ray.drawCircleLinesV( pos, radius, col );
}

pub inline fn drawSimpleEllipse( pos : Vec2, radiusX : f32, radiusY : f32, col : Colour ) void
{
  ray.drawEllipseV( pos.toRayVec2(), radiusX, radiusY, col );
}
pub inline fn drawSimpleEllipseLines( pos : Vec2, radiusX : f32, radiusY : f32, col : Colour ) void // TODO : Add line thickness
{
  ray.drawEllipseLinesV( pos.toRayVec2(), radiusX, radiusY, col );
}

pub inline fn drawSimpleRectangle( pos : Vec2, size : Vec2, col : Colour ) void
{
  ray.drawRectangleV( pos.toRayVec2(), size, col );
}
pub inline fn drawSimpleRectangleLines( pos : Vec2, size : Vec2, col : Colour, width : f32  ) void
{
  ray.drawRectangleLinesEx( ray.Rectangle{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, width, col );
}

// TODO : Add a drawSimplePolygon(Lines) function


// ================ BASIC DRAWING FUNCTIONS ================

pub inline fn drawBasicTria( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour ) void
{
  ray.drawTriangle( p1.toRayVec2(), p2.toRayVec2(), p3.toRayVec2(), col );
}
pub inline fn drawBasicTriaLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour, width : f32 ) void
{
  ray.drawLineEx( p1.toRayVec2(), p2.toRayVec2(), width, col );
  ray.drawLineEx( p2.toRayVec2(), p3.toRayVec2(), width, col );
  ray.drawLineEx( p3.toRayVec2(), p1.toRayVec2(), width, col );
}

pub inline fn drawBasicQuad( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour ) void
{
  ray.drawTriangle( p1.toRayVec2(), p2.toRayVec2(), p3.toRayVec2(), col );
  ray.drawTriangle( p3.toRayVec2(), p4.toRayVec2(), p1.toRayVec2(), col );
}
pub inline fn drawBasicQuadLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour, width : f32  ) void
{
  ray.drawLineEx( p1.toRayVec2(), p2.toRayVec2(), width, col );
  ray.drawLineEx( p2.toRayVec2(), p3.toRayVec2(), width, col );
  ray.drawLineEx( p3.toRayVec2(), p4.toRayVec2(), width, col );
  ray.drawLineEx( p4.toRayVec2(), p1.toRayVec2(), width, col );
}

pub inline fn drawBasicPoly( pos : Vec2, radius : f32, a : Angle, col : Colour, sides : u8 ) void
{
  ray.drawPoly( pos.toRayVec2(), @intCast( sides ), radius, def.RtD( a ), col );
}
pub inline fn drawBasicPolyLines( pos : Vec2, radius : f32, a : Angle, col : Colour, width : f32, sides : u8  ) void // TODO : Add line thickness
{
  ray.drawPolyLinesEx( pos.toRayVec2(), @intCast( sides ), radius, def.RtD( a ), width, col );
}


// ================ ADVANCED DRAWING FUNCTIONS ================

pub inline fn drawTrianglePlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 3 ); }
pub inline fn drawDiamondPlus(  pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 4 ); }
pub inline fn drawPentagonPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 5 ); }
pub inline fn drawHexagonPlus(  pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { drawPolygonPlus( pos, radii, a, col, 6 ); }

// Draws a rectangle centered at a given position with specified rotation (rad), colour and size, and scaled in x/y by radii
pub inline fn drawRectanglePlus(  pos : Vec2, radii : Vec2, a : Angle, col : Colour) void
{
  drawBasicQuad(
    pos.add( Vec2.new(  radii.x,  radii.y ).rot( a )),
    pos.add( Vec2.new(  radii.x, -radii.y ).rot( a )),
    pos.add( Vec2.new( -radii.x, -radii.y ).rot( a )),
    pos.add( Vec2.new( -radii.x,  radii.y ).rot( a )),
    col
  );
}

// Draws an ellipse centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawEllipsePlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void
{
  drawPolygonPlus( pos, radii, a, col, ELLIPSE_SIDE_COUNT ); // Pretending ellipses are polygons
}

// Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
pub fn drawPolygonPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u8 ) void
{
  if( sides < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with less than 3 sides" );
    return;
  }
  const sideStepAngle = Angle.newRad( 2.0 * def.PI / @as( f32, @floatFromInt( sides )));

  const P0 = pos.add( Vec2.fromAngleScaled( .{},  radii ).rot( a ));
  var   P1 = pos.add( Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a ));

  for( 2..sides )| i |
  {
    var P2 = pos.add( Vec2.fromAngleScaled( sideStepAngle.mulVal( @floatFromInt( i )), radii ).rot( a ));
    ray.drawTriangle( P0.toRayVec2(), P2.toRayVec2(), P1.toRayVec2(), col );
    P1 = P2;
  }
}


// Draws a 6-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawHexStarPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void
{
  drawPolygonPlus( pos, radii, a,                         col, 3 );
  drawPolygonPlus( pos, radii, a.rotRad( def.PI / 3.0 ), col, 3 );
}

// Draws an 8-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawOctStarPlus( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void
{
  drawPolygonPlus( pos, radii, a,                          col, 4 );
  drawPolygonPlus( pos, radii, a.rotRad( def.PI / 4.0 ), col, 4 );
}


// ================ TEXT DRAWING FUNCTIONS ================

pub inline fn drawText( text : [:0] const u8, posX : f32, posY : f32, fontSize : f32, col : Colour ) void
{
  ray.drawText( text, @intFromFloat( posX ), @intFromFloat( posY ), @intFromFloat( fontSize ), col );
}

pub inline fn drawCenteredText( text : [:0] const u8, posX : f32, posY : f32, fontSize : f32, col : Colour ) void
{
  const textHalfWidth  = @as( f32, @floatFromInt( ray.measureText( text, @intFromFloat( fontSize )))) / 2.0;
  const textHalfHeight = fontSize / 2.0;
  drawText( text, posX - textHalfWidth, posY - textHalfHeight, fontSize, col );
}


// ================ TEXTURE DRAWING FUNCTIONS ================

pub inline fn drawTexture( image : ray.Texture2D, posX : f32, posY : f32, a : Angle, scale : Vec2, col : Colour ) void
{
  ray.drawTextureEx( image, ray.Vector2{ .x = posX, .y = posY }, a, scale.x, col );
}

pub inline fn drawCenteredTexture( image : ray.Texture2D, posX : f32, posY : f32, a : Angle, scale : Vec2, col : Colour ) void
{
  const halfWidth  = @as( f32, @floatFromInt( image.width  )) * scale.x / 2.0;
  const halfHeight = @as( f32, @floatFromInt( image.height )) * scale.y / 2.0;
  drawTexture( image, posX - halfWidth, posY - halfHeight, a, scale, col );
}

pub inline fn drawTexturePlus( image : ray.Texture2D, source : ray.Rectangle, dest : ray.Rectangle, origin : Vec2, a : Angle, col : Colour ) void
{
  ray.drawTexturePro( image, source, dest, origin, def.RtD( a ), col );
}
