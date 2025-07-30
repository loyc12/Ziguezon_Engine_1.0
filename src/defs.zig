pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const logger = @import( "utils/logger.zig" );
pub const rng    = @import( "utils/rng.zig" );
pub const timer  = @import( "utils/timer.zig" );
pub const vector = @import( "utils/vector.zig" );


// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;

pub const log  = logger.log;  // for argument-formatting logging
pub const qlog = logger.qlog; // for quick logging ( no args )


// =============== VECTOR SHORTHANDS ===============

pub const vec2 = ray.Vector2;

pub const addValToVec2 = vector.addValToVec2;
pub const subValToVec2 = vector.subValToVec2;
pub const mulVec2ByVal = vector.mulVec2ByVal;
pub const divVec2ByVal = vector.divVec2ByVal;
pub const normVec2Unit  = vector.normVec2;
pub const normVec2Len  = vector.normVec2Len;

pub const addVec2 = vector.addVec2;
pub const subVec2 = vector.subVec2;
pub const mulVec2 = vector.mulVec2;
pub const divVec2 = vector.divVec2;

pub const rotVec2Deg        = vector.rotVec2Deg;
pub const rotVec2Rad        = vector.rotVec2Rad;
pub const getAngleToVec2Deg = vector.getAngleToVec2Deg;
pub const getAngleToVec2Rad = vector.getAngleToVec2Rad;
pub const getAngDistDeg     = vector.getAngDistDeg;
pub const getAngDistRad     = vector.getAngDistRad;

pub const getDistX    = vector.getDistX;
pub const getDistY    = vector.getDistY;
pub const getCartDist = vector.getCartDist;
pub const getDistance = vector.getDistance;
pub const getSqrDist  = vector.getSqrDist;

pub const getScaledVec2FromDeg = vector.getScaledVec2FromDeg;
pub const getScaledVec2FromRad = vector.getScaledVec2FromRad;
pub const getScaledPolyVerts  = vector.getScaledPolyVerts;


// ================================ CORE ENGINE MODULES ================================

// ================ GAME HOOK SYSTEM ================
pub const ghm = @import( "core/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // Global gameHooks struct instance

pub fn initHooks( module : anytype ) void { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }

// ================ ENGINE & MANAGERS ================
pub const eng = @import( "core/engine.zig" );
pub var G_NG : eng.engine = .{}; // Global game engine instance

pub const rsm = @import( "core/resourceManager.zig" );
pub const ntm = @import( "core/entityManager.zig" );

// ================ ENTITY SYSTEM ================
pub const ntt = @import( "core/entity/entityCore.zig" );


// ================================ MATHS ADDONS ================================
// These are additional math functions that are not part of the standard library but are useful for game development.

pub const lerp = std.math.lerp; // Shorthand for linear interpolation

pub fn med3( a : anytype, b : @TypeOf( a ), c : @TypeOf( a )) @TypeOf( a )
{
  switch( @typeInfo( @TypeOf( a )))
  {
    .float, .comptime_float, .int, .comptime_int =>
    {
      if( a < b )
      {
        if(      b < c ){ return b; } // a <  b <  c
        else if( a < c ){ return c; } // a <  c <= b
        else            { return a; } // c <= a <  b
      }
      else
      {
        if(      a < c ){ return a; } // b <  a <  c
        else if( b < c ){ return c; } // b <  c <= a
        else            { return b; } // c <= b <  a
      }
    },
    else => @compileError( "med3() only supports Int and Float types" ),
  }
}

pub fn clmp( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val )))
  {
    .float, .comptime_float, .int, .comptime_int =>
      return if ( val < min ) min else if ( val > max ) max else val,

    else => @compileError( "clmp() only supports Int and Float types" ),
  }
}
pub fn norm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Normalizes a value to the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return ( val - min ) / ( max - min ),
    else => @compileError( "norm() only supports Float types" ),
  }
}
pub fn denorm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Denormalizes a value from the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return ( val * ( max - min )) + min,
    else => @compileError( "denorm() only supports Float types" ),
  }
}
pub fn renorm( val : anytype, srcMin : @TypeOf( val ), srcMax : @TypeOf( val ), dstMin : @TypeOf( val ), dstMax : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Renormalizes a value from a src range to a dst range
  {
    .float, .comptime_float => return norm( denorm( val, srcMin, srcMax ), dstMin, dstMax ),
    else => @compileError( "renorm() only supports Float types" ),
  }
}

// ================================ RAYLIB ADDONS ================================

pub fn getScreenWidth()  f32 { return @floatFromInt( ray.getScreenWidth()  ); }
pub fn getScreenHeight() f32 { return @floatFromInt( ray.getScreenHeight() ); }
pub fn getScreenSize()  vec2 { return vec2{ .x = getScreenWidth(), .y = getScreenHeight(), }; }

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

pub fn drawTexture( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : vec2, color : ray.Color ) void
{
  ray.drawTextureEx( image, ray.Vector2{ .x = posX, .y = posY }, rot, scale.x, color );
}
pub fn drawTextureCentered( image : ray.Texture2D, posX : f32, posY : f32, rot : f32, scale : vec2, color : ray.Color ) void
{
  const halfWidth  = @as( f32, @floatFromInt( image.width  )) * scale.x / 2.0;
  const halfHeight = @as( f32, @floatFromInt( image.height )) * scale.y / 2.0;

  drawTexture( image, posX - halfWidth, posY - halfHeight, rot, scale, color );
}
