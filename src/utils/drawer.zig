const std = @import( "std" );
const def  = @import( "defs" );
const ray  = def.ray;
const Vec2 = def.Vec2;

pub fn getScreenWidth()  f32 { return @floatFromInt( ray.getScreenWidth()  ); }
pub fn getScreenHeight() f32 { return @floatFromInt( ray.getScreenHeight() ); }
pub fn getScreenSize()  Vec2 { return Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), }; }

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
