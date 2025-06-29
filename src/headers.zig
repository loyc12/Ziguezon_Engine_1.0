pub const std = @import( "std" );
pub const rl  = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const logger = @import( "utils/logger.zig" );
pub const timer  = @import( "utils/timer.zig" );


// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;

pub const log  = logger.log;  // for argument-formatting logging
pub const qlog = logger.qlog; // for quick logging ( no args )

const engine = @import( "core/engine.zig" ).engine;
pub var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance


// ================================ INITIALIZATION ================================

pub fn initAll() void
{
  // Initialize the timer
  timer.initTimer();

  // Initialize the log file if needed
  logger.initFile();

  qlog( .INFO, 0, @src(), "Initialized all subsystems" );
}

pub fn deinitAll() void
{
  qlog( .INFO, 0, @src(), "Deinitializing all subsystems" );

  // Deinitialize the log file if present
  logger.deinitFile();
}


// ================================ MATHS ADDONS ================================
// These are additional math functions that are not part of the standard library but are useful for game development.

pub const lerp = std.math.lerp; // Shorthand for linear interpolation

pub fn med3( a : anytype, b : @TypeOf( a ), c : @TypeOf( a )) @TypeOf( a )
{
  switch( @typeInfo( @TypeOf( a )))
  {
    .Float, .comptime_float, .Int, .comptime_int =>
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
    .Float, .comptime_float, .Int, .comptime_int =>
      return if ( val < min ) min else if ( val > max ) max else val,

    else => @compileError( "clmp() only supports Int and Float types" ),
  }
}
pub fn norm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Normalizes a value to the range ( 0.0, 1.0 )
  {
    .Float, .comptime_float => return ( val - min ) / ( max - min ),
    else => @compileError( "norm() only supports Float types" ),
  }
}
pub fn denorm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Denormalizes a value from the range ( 0.0, 1.0 )
  {
    .Float, .comptime_float => return ( val * ( max - min )) + min,
    else => @compileError( "denorm() only supports Float types" ),
  }
}
pub fn renorm( val : anytype, srcMin : @TypeOf( val ), srcMax : @TypeOf( val ), dstMin : @TypeOf( val ), dstMax : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Renormalizes a value from a src range to a dst range
  {
    .Float, .comptime_float => return norm( denorm( val, srcMin, srcMax ), dstMin, dstMax ),
    else => @compileError( "renorm() only supports Float types" ),
  }
}


// ================================ GAME INJECTORS ================================
// These are the injectors that allow you to hook into the game engine's lifecycle / gameloop.

pub const OnEntityRender  = @import( "injectors/entityInjects.zig" ).OnEntityRender;
pub const OnEntityCollide = @import( "injectors/entityInjects.zig" ).OnEntityCollide;

pub const OnLoopStart = @import( "injectors/stepInjects.zig" ).OnLoopStart;
pub const OnLoopIter  = @import( "injectors/stepInjects.zig" ).OnLoopIter;
pub const OnLoopEnd   = @import( "injectors/stepInjects.zig" ).OnLoopEnd;

pub const OnUpdate = @import( "injectors/stepInjects.zig" ).OnUpdate;
pub const OnTick   = @import( "injectors/stepInjects.zig" ).OnTick;

pub const OnRenderWorld   = @import( "injectors/stepInjects.zig" ).OnRenderWorld;
pub const OnRenderOverlay = @import( "injectors/stepInjects.zig" ).OnRenderOverlay;

pub const OnStart  = @import( "injectors/stateInjects.zig" ).OnStart;
pub const OnLaunch = @import( "injectors/stateInjects.zig" ).OnLaunch;
pub const OnPlay   = @import( "injectors/stateInjects.zig" ).OnPlay;

pub const OnPause = @import( "injectors/stateInjects.zig" ).OnPause;
pub const OnStop  = @import( "injectors/stateInjects.zig" ).OnStop;
pub const OnClose = @import( "injectors/stateInjects.zig" ).OnClose;


// ================================ VECTOR ADDONS ================================
// These are additional raylib vector math functions that are useful for game development.

pub const vec2 = rl.Vector2; // Shorthand for raylib's Vector2 type

pub const DtR = std.math.degreesToRadians; // Shorthand for degrees to radians conversion
pub const RtD = std.math.radiansToDegrees; // Shorthand for radians to degrees conversion

pub fn addVec2(  a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x + b.x, .y = a.y + b.y }; }
pub fn subVec2(  a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x - b.x, .y = a.y - b.y }; }
pub fn normVec2( a : vec2 ) vec2
{
  const len = @sqrt(( a.x * a.x ) + ( a.y * a.y ));

  if( len == 0.0 ){ return vec2{ .x = 0.0, .y = 0.0 }; } // Prevent division by zero

  return vec2{ .x = a.x / len, .y = a.y / len };
}
pub fn rotVec2Rad( a : vec2, angle : f32 ) vec2 // NOTE : Angles in radians
{
  const cosAngle = @cos( angle );
  const sinAngle = @sin( angle );

  return vec2{
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
  };
}
pub fn rotVec2Deg( a : vec2, angle : f32 ) vec2 // NOTE : Angles in degrees
{
  const cosAngle = @cos( DtR( angle ));
  const sinAngle = @sin( DtR( angle ));

  return vec2{
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
  };
}

// ================================ RAYLIB ADDONS ================================

pub fn getScreenWidth()  f32 { return @floatFromInt( rl.getScreenWidth()  ); }
pub fn getScreenHeight() f32 { return @floatFromInt( rl.getScreenHeight() ); }
pub fn getScreenSize() vec2  { return vec2{ .x = getScreenWidth(), .y = getScreenHeight(), }; }
