pub const std = @import( "std" );
pub const ray  = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const logger = @import( "utils/logger.zig" );
pub const timer  = @import( "utils/timer.zig" );
pub const rng    = @import( "utils/rng.zig" );


// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;

pub const log  = logger.log;  // for argument-formatting logging
pub const qlog = logger.qlog; // for quick logging ( no args )

//pub const tryCall = misc.tryCall; // For calling functions that may not exist

pub const rsm = @import( "core/resourceManager.zig" );

pub const ghm = @import( "core/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // Global game hooks instance
pub fn initHooks( module : anytype ) void { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }

pub const eng = @import( "core/engine.zig" );
pub var G_NG : eng.engine = .{}; // Global game engine instance

pub const ntm = @import( "core/entity/entityManager.zig" );
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


// ================================ VECTOR ADDONS ================================
// These are additional raylib vector math functions that are useful for game development.

pub const vec2 = ray.Vector2; // Shorthand for raylib's Vector2 type

pub const DtR = std.math.degreesToRadians; // Shorthand for degrees to radians conversion
pub const RtD = std.math.radiansToDegrees; // Shorthand for radians to degrees conversion

pub fn addVec2(  a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x + b.x, .y = a.y + b.y }; }
pub fn subVec2(  a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x - b.x, .y = a.y - b.y }; }
pub fn mulVec2(  a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x * b.x, .y = a.y * b.y }; }
pub fn divVec2(  a : vec2, b : vec2 ) ?vec2
{
  if( b.x == 0.0 or b.y == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec2()" );
    return null; // Return null if division by zero is attempted
  }
  return vec2{ .x = a.x / b.x, .y = a.y / b.y };
}

pub fn normVec2( a : vec2 ) ?vec2
{
  const len = @sqrt(( a.x * a.x ) + ( a.y * a.y ));

  if( len == 0.0 )
  {
    return null;
  }
  return vec2{ .x = a.x / len, .y = a.y / len };
}
pub fn rotVec2Rad( a : vec2, angleRad : f32 ) vec2
{
  const cosAngle = @cos( angleRad );
  const sinAngle = @sin( angleRad );

  return vec2
  {
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
  };
}
pub fn getScaledVec2FromAngleDeg( angleDeg : f32, scale : vec2 ) vec2
{
  return vec2{ .x = @cos( DtR( angleDeg )) * scale.x, .y = @sin( DtR( angleDeg )) * scale.y };
}

// Do not forget to dealloc the returned array !
pub fn getScaledPolyVertexs( scale : vec2, sides : u32 ) ?[]vec2
{
  if( sides < 3 )
  {
    log( .ERROR, 0, @src(), "getScaledPolyVertexs() requires at least 3 sides, got {d}", .{ sides } );
    return null;
  }

  var points = std.ArrayList( vec2 ).init( alloc );

  for( 0..sides )| i |
  {
    const angle = @as( f32, @floatFromInt( i )) * ( std.math.tau / @as( f32, @floatFromInt( sides ))); // 2*PI / sides
    points.append( vec2{ .x = @cos( angle ) * scale.x, .y = @sin( angle ) * scale.y }) catch | err |
    {
      log( .ERROR, 0, @src(), "Failed to append polygon vertex {d} : {}", .{ i, err } );
    };
  }
  if( points.items.len < sides )
  {
    log( .ERROR, 0, @src(), "Failed to generate polygon vertexs, got only {d} out of {d}", .{ points.items.len, sides } );
    alloc.free( points.items );
    return null;
  }
  return points.items;
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
