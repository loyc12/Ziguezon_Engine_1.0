const utl = @import( "utils" );

const Vec2 = utl.Vec2;



// ================================ SCREEN HELPERS ================================

// Centralized screen-space facade. This keeps raylib calls out of higher-level
// camera and UI code while still exposing plain engine math types.

pub inline fn getScreenWidth()  f64 { return @floatFromInt( utl.ray.getScreenWidth()  ); }
pub inline fn getScreenHeight() f64 { return @floatFromInt( utl.ray.getScreenHeight() ); }
pub inline fn getScreenSize()  Vec2
{
  return Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), };
}

pub inline fn getHalfScreenWidth()  f64 { return getScreenWidth()  * 0.5; }
pub inline fn getHalfScreenHeight() f64 { return getScreenHeight() * 0.5; }
pub inline fn getHalfScreenSize()  Vec2
{
  return Vec2{ .x = getHalfScreenWidth(), .y = getHalfScreenHeight(), };
}

pub inline fn getMouseScreenPos() Vec2 { return .fromRayVec2( utl.ray.getMousePosition() ); }

pub inline fn getViewFromZoom( zoom : f64  ) Vec2 { return getHalfScreenSize().mulVal( 1.0 / zoom ); }
pub inline fn getZoomFromView( view : Vec2 ) f64  { return getHalfScreenWidth() / ( view.x ); }
