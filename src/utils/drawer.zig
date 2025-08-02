const std = @import( "std" );
const def  = @import( "defs" );
const ray  = def.ray;
const Vec2 = def.Vec2;

const ELLIPSE_SIDE_COUNT: u8 = 32; // Number of sides for the ellipse polygon approximation


// ================================ HELPER FUNCTIONS ================================

pub fn getScreenWidth()  f32 { return @floatFromInt( ray.getScreenWidth()  ); }
pub fn getScreenHeight() f32 { return @floatFromInt( ray.getScreenHeight() ); }
pub fn getScreenSize()  Vec2 { return Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), }; }

pub fn coverScreenWith( color : ray.Color ) void
{
  const screenSize = getScreenSize();
  ray.drawRectangleV( Vec2{ .x = 0, .y = 0 }, screenSize, color );
}


// ================================ SHAPE DRAWING FUNCTIONS ================================

// ================ SIMPLE DRAWING FUNCTIONS ================

pub fn drawPixel( pos : Vec2, color : ray.Color ) void
{
  ray.drawPixelV( pos, color );
}
pub fn drawMacroPixel( pos : Vec2, size : f32, color : ray.Color ) void
{
  ray.drawRectangleV( pos, size, color );
}

pub fn drawLine( p1 : Vec2, p2 : Vec2, color : ray.Color, width : f32 ) void
{
  ray.drawLineEx( ray.Vector2{ .x = p1.x, .y = p1.y }, ray.Vector2{ .x = p2.x, .y = p2.y }, width, color );
}
// pub fn drawDotedLine( p1 : Vec2, p2 : Vec2, color : ray.Color, width : f32, spacinf : f32 ) void

pub fn drawCircle( pos : Vec2, radius : f32, color : ray.Color ) void
{
  ray.drawCircleV( pos, radius, color );
}
pub fn drawCircleLines( pos : Vec2, radius : f32, color : ray.Color ) void // TODO : Add line thickness
{
  ray.drawCircleLinesV( pos, radius, color );
}

pub fn drawSimpleEllipse( pos : Vec2, radiusX : f32, radiusY : f32, color : ray.Color ) void
{
  ray.drawEllipseV( pos, radiusX, radiusY, color );
}
pub fn drawSimpleEllipseLines( pos : Vec2, radiusX : f32, radiusY : f32, color : ray.Color ) void // TODO : Add line thickness
{
  ray.drawEllipseLinesV( pos, radiusX, radiusY, color );
}

pub fn drawSimpleRectangle( pos : Vec2, size : Vec2, color : ray.Color ) void
{
  ray.drawRectangleV( pos, size, color );
}
pub fn drawSimpleRectangleLines( pos : Vec2, size : Vec2, color : ray.Color, width : f32  ) void
{
  ray.drawRectangleLinesEx( ray.Rectangle{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, width, color );
}


// ================ BASIC DRAWING FUNCTIONS ================

pub fn drawBasicTria( p1 : Vec2, p2 : Vec2, p3 : Vec2, color : ray.Color ) void
{
  ray.drawTriangle( p1, p2, p3, color );
}
pub fn drawBasicTriaLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, color : ray.Color, width : f32 ) void
{
  ray.drawLineEx( p1, p2, width, color );
  ray.drawLineEx( p2, p3, width, color );
  ray.drawLineEx( p3, p1, width, color );
}

pub fn drawBasicQuad( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, color : ray.Color ) void
{
  ray.drawTriangle( p1, p2, p3, color );
  ray.drawTriangle( p3, p4, p1, color );
}
pub fn drawBasicQuadLines( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, color : ray.Color, width : f32  ) void
{
  ray.drawLineEx( p1, p2, width, color );
  ray.drawLineEx( p2, p3, width, color );
  ray.drawLineEx( p3, p4, width, color );
  ray.drawLineEx( p4, p1, width, color );
}

pub fn drawBasicPoly( pos : Vec2, radius : f32, rotation : f32, color : ray.Color, sides : u8 ) void
{
  ray.drawPoly( pos, @intCast( sides ), radius, rotation, color );
}
pub fn drawBasicPolyLines( pos : Vec2, radius : f32, rotation : f32, color : ray.Color, width : f32, sides : u8  ) void // TODO : Add line thickness
{
  ray.drawPolyLinesEx( pos, @intCast( sides ), radius, rotation, width, color );
}


// ================ ADVANCED DRAWING FUNCTIONS ================

// Draws a rectangle centered at a given position with specified rotation (rad), colour and size, and scaled in x/y by radii
pub fn drawRectanglePlus(  pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color) void
{
  ray.drawRectanglePro( ray.Rectangle{ .x = pos.x, .y = pos.y, .width = radii.x * 2, .height = radii.y * 2 }, radii, rotation, color );
}


// Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
pub fn drawPolygonPlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color, sides : u8 ) void
{
  if( sides < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with less than 3 sides" );
    return;
  }
  const sideStepAngle = 2.0 * std.math.pi / @as( f32, @floatFromInt( sides ));

  const P0 = def.addVec2( pos, def.getScaledVec2Rad( radii, rotation ));
  var   P1 = def.addVec2( pos, def.getScaledVec2Rad( radii, rotation + sideStepAngle ));

  for( 2..sides )| i |
  {
    const P2 = def.addVec2( pos, def.getScaledVec2Rad( radii, rotation + ( sideStepAngle * @as( f32, @floatFromInt( i )))));
    ray.drawTriangle( P0, P2, P1, color );
    P1 = P2;
  }
}

// Draws an ellipse centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub fn drawEllipsePlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color ) void
{
  drawPolygonPlus( pos, radii, rotation, color, ELLIPSE_SIDE_COUNT ); // Pretending ellipses are polygons
}


// Draws a triangle centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub fn drawTrianglePlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color ) void
{
  drawPolygonPlus( pos, radii, rotation, color, 3 );
}

// Draws a 6-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub fn drawHexStarPlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color ) void
{
  drawPolygonPlus( pos, radii, rotation,               color, 3 );
  drawPolygonPlus( pos, radii, rotation + std.math.pi, color, 3 );
}


// Draws a diamond centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub fn drawDiamondPlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color ) void
{
  drawPolygonPlus( pos, radii, rotation, color, 4 );
}

// Draws an 8-pointed star centered at a given position with specified rotation (rad) and colour, and scaled in x/y by radii
pub fn drawOctStarPlus( pos : Vec2, radii : Vec2, rotation : f32, color : ray.Color ) void
{
  drawPolygonPlus( pos, radii, rotation,                     color, 4 );
  drawPolygonPlus( pos, radii, rotation + std.math.pi / 2.0, color, 4 );
}


// ================ TEXT DRAWING FUNCTIONS ================

pub fn drawText( text : [:0] const u8, posX : f32, posY : f32, fontSize : f32, color : ray.Color ) void
{
  ray.drawText( text, @intFromFloat( posX ), @intFromFloat( posY ), @intFromFloat( fontSize ), color );
}

pub fn drawCenteredText( text : [:0] const u8, posX : f32, posY : f32, fontSize : f32, color : ray.Color ) void
{
  const textHalfWidth  = @as( f32, @floatFromInt( ray.measureText( text, @intFromFloat( fontSize )))) / 2.0;
  const textHalfHeight = fontSize / 2.0;
  drawText( text, posX - textHalfWidth, posY - textHalfHeight, fontSize, color );
}


// ================ TEXTURE DRAWING FUNCTIONS ================

pub fn drawTexture( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : Vec2, color : ray.Color ) void
{
  ray.drawTextureEx( image, ray.Vector2{ .x = posX, .y = posY }, rot, scale.x, color );
}

pub fn drawTextureCentered( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : Vec2, color : ray.Color ) void
{
  const halfWidth  = @as( f32, @floatFromInt( image.width  )) * scale.x / 2.0;
  const halfHeight = @as( f32, @floatFromInt( image.height )) * scale.y / 2.0;
  drawTexture( image, posX - halfWidth, posY - halfHeight, rot, scale, color );
}

pub fn drawTexturePlus( image : ray.Texture2D, source : ray.Rectangle, dest : ray.Rectangle, origin : Vec2, rotation : f32, color : ray.Color ) void
{
  ray.drawTexturePro( image, source, dest, origin, rotation, color );
}
