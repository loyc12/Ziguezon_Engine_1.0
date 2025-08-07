const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const SCREEN_DIMS  = def.Vec2{ .x = 2048, .y = 1024 };
pub const TARGET_FPS   = 120; // Default target FPS for the game

//pub const TARGET_TPS = 30;  // Default tick rate for the game ( in seconds ) // TODO : USE ME

// ================================ HELPER FUNCTIONS ================================

pub inline fn getScreenWidth()  f32 { return @floatFromInt( def.ray.getScreenWidth()  ); }
pub inline fn getScreenHeight() f32 { return @floatFromInt( def.ray.getScreenHeight() ); }
pub inline fn getScreenSize() def.Vec2
{
  return def.Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), };
}

pub inline fn getHalfScreenWidth()  f32 { return getScreenWidth()  / 2.0; }
pub inline fn getHalfScreenHeight() f32 { return getScreenHeight() / 2.0; }
pub inline fn getHalfScreenSize() def.Vec2
{
  return def.Vec2{ .x = getHalfScreenWidth(), .y = getHalfScreenHeight(), };
}

pub inline fn getMouseScreenPos() def.Vec2 { return def.ray.getMousePosition(); }
pub inline fn getMouseWorldPos()  def.Vec2
{
  return def.ray.getScreenToWorld2D( getMouseScreenPos(), def.ngn.mainCamera );
}