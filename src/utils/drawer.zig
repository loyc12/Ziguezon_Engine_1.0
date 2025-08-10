const std  = @import( "std" );
const def  = @import( "defs" );

const ray    = def.ray;
const Vec2   = def.Vec2;
const Colour = def.Colour;

const ELLIPSE_SIDE_COUNT: u8 = 32; // Number of sides for the ellipse polygon approximation

// ================================ DRAWING FUNCTIONS ================================

pub inline fn coverScreenWith( col : Colour ) void { ray.drawRectangleV( Vec2{ .x = 0, .y = 0 }, def.getScreenSize(), col ); }


// ================ SIMPLE DRAWING FUNCTIONS ================

pub inline fn drawPixel( pos : Vec2, col : Colour ) void
{
  ray.drawPixelV( pos, col );
}
pub inline fn drawMacroPixel( pos : Vec2, size : f32, col : Colour ) void
{
  ray.drawRectangleV( pos, size, col );
}

pub inline fn drawLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f32 ) void
{
  ray.drawLineEx( ray.Vector2{ .x = p1.x, .y = p1.y }, ray.Vector2{ .x = p2.x, .y = p2.y }, width, col );
}
// pub fn drawDotedLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f32, spacinf : f32 ) void

pub inline fn drawCircle( pos : Vec2, radius : f32, col : Colour ) void
{
  ray.drawCircleV( pos, radius, col );
}
pub inline fn drawCircleLines( pos : Vec2, radius : f32, col : Colour ) void // TODO : Add line thickness
{
  ray.drawCircleLinesV( pos, radius, col );
}

pub inline fn drawSimpleEllipse( pos : Vec2, radiusX : f32, radiusY : f32, col : Colour ) void
{
  ray.drawEllipseV( pos, radiusX, radiusY, col );
}
pub inline fn drawSimpleEllipseLines( pos : Vec2, radiusX : f32, radiusY : f32, col : Colour ) void // TODO : Add line thickness
{
  ray.drawEllipseLinesV( pos, radiusX, radiusY, col );
}

pub inline fn drawSimpleRectangle( pos : Vec2, size : Vec2, col : Colour ) void
{
  ray.drawRectangleV( pos, size, col );
}
pub inline fn drawSimpleRectangleLines( pos : Vec2, size : Vec2, col : Colour, width : f32  ) void
{
  ray.drawRectangleLinesEx( ray.Rectangle{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, width, col );
}


// ================ BASIC DRAWING FUNCTIONS ================

pub inline fn drawBasicTria( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour ) void
{
  ray.drawTriangle( p1, p2, p3, col );
}
pub inline fn drawBasicTriaLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour, width : f32 ) void
{
  ray.drawLineEx( p1, p2, width, col );
  ray.drawLineEx( p2, p3, width, col );
  ray.drawLineEx( p3, p1, width, col );
}

pub inline fn drawBasicQuad( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour ) void
{
  ray.drawTriangle( p1, p2, p3, col );
  ray.drawTriangle( p3, p4, p1, col );
}
pub inline fn drawBasicQuadLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour, width : f32  ) void
{
  ray.drawLineEx( p1, p2, width, col );
  ray.drawLineEx( p2, p3, width, col );
  ray.drawLineEx( p3, p4, width, col );
  ray.drawLineEx( p4, p1, width, col );
}

pub inline fn drawBasicPoly( pos : Vec2, radius : f32, rotation : f32, col : Colour, sides : u8 ) void
{
  ray.drawPoly( pos, @intCast( sides ), radius, rotation, col );
}
pub inline fn drawBasicPolyLines( pos : Vec2, radius : f32, rotation : f32, col : Colour, width : f32, sides : u8  ) void // TODO : Add line thickness
{
  ray.drawPolyLinesEx( pos, @intCast( sides ), radius, rotation, width, col );
}


// ================ ADVANCED DRAWING FUNCTIONS ================

// Draws a rectangle centered at a given position with specified rotation (rad), colour and size, and scaled in x/y by radii
pub inline fn drawRectanglePlus(  pos : Vec2, radii : Vec2, rotation : f32, col : Colour) void
{
  ray.drawRectanglePro( ray.Rectangle{ .x = pos.x, .y = pos.y, .width = radii.x * 2, .height = radii.y * 2 }, radii, rotation, col );
}

// Draws an ellipse centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawEllipsePlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour ) void
{
  drawPolygonPlus( pos, radii, rotation, col, ELLIPSE_SIDE_COUNT ); // Pretending ellipses are polygons
}

// Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
pub fn drawPolygonPlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour, sides : u8 ) void
{
  if( sides < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with less than 3 sides" );
    return;
  }
  const sideStepAngle = 2.0 * std.math.pi / @as( f32, @floatFromInt( sides ));

  const P0 = def.addVec2( pos, def.radToVec2Scaled( rotation,                 radii ));
  var   P1 = def.addVec2( pos, def.radToVec2Scaled( rotation + sideStepAngle, radii ));

  for( 2..sides )| i |
  {
    const P2 = def.addVec2( pos, def.radToVec2Scaled( rotation + ( sideStepAngle * @as( f32, @floatFromInt( i ))), radii ));
    ray.drawTriangle( P0, P2, P1, col );
    P1 = P2;
  }
}


// Draws a triangle centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawTrianglePlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour ) void
{
  drawPolygonPlus( pos, radii, rotation, col, 3 );
}

// Draws a diamond centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawDiamondPlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour ) void
{
  drawPolygonPlus( pos, radii, rotation, col, 4 );
}

// Draws a 6-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawHexStarPlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour ) void
{
  drawPolygonPlus( pos, radii, rotation,               col, 3 );
  drawPolygonPlus( pos, radii, rotation + std.math.pi, col, 3 );
}

// Draws an 8-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub inline fn drawOctStarPlus( pos : Vec2, radii : Vec2, rotation : f32, col : Colour ) void
{
  drawPolygonPlus( pos, radii, rotation,                     col, 4 );
  drawPolygonPlus( pos, radii, rotation + std.math.pi / 2.0, col, 4 );
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

pub inline fn drawTexture( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : Vec2, col : Colour ) void
{
  ray.drawTextureEx( image, ray.Vector2{ .x = posX, .y = posY }, rot, scale.x, col );
}

pub inline fn drawTextureCentered( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : Vec2, col : Colour ) void
{
  const halfWidth  = @as( f32, @floatFromInt( image.width  )) * scale.x / 2.0;
  const halfHeight = @as( f32, @floatFromInt( image.height )) * scale.y / 2.0;
  drawTexture( image, posX - halfWidth, posY - halfHeight, rot, scale, col );
}

pub inline fn drawTexturePlus( image : ray.Texture2D, source : ray.Rectangle, dest : ray.Rectangle, origin : Vec2, rotation : f32, col : Colour ) void
{
  ray.drawTexturePro( image, source, dest, origin, rotation, col );
}
