const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Duration = utl.Duration;
const Instant  = utl.Instant;

// TODO : move these constants to engine configs

const TICK_BUFF_LEN   = 8;
const FRAME_BUFF_LEN  = 16;


pub const EngineTiming = struct
{
  loopEpoch : ?Instant = null, // Wall-clock time at which the last loop timing update occured
  loopDelta : Duration = .{},  // How far appart the last two loop timing updates were
  loopCount : u128     = 0,    // Number of loop timing updates since launch

  targetTickDelta    : Duration = .{}, // How far appart should each tick update be
  measuredTickDelta  : Duration = .{}, // How far appart the last two tick updates were
  smoothedTickDelta  : Duration = .{},
  tickAccum          : Duration = .{}, // Time since the last tick update occured
  lastTickTime       : ?Instant = null, // the wall-clock time at which the last tick occured
  tickCount          : u128     = 0,   // Number of tick updates since launch

  targetFrameDelta   : Duration = .{}, // How far appart should each frame update be
  measuredFrameDelta : Duration = .{}, // How far appart the last two frame updates were
  smoothedFrameDelta : Duration = .{},
  frameAccum         : Duration = .{}, // Time since last frame update occured
  lastFrameTime      : ?Instant = null, // the wall-clock time at which the last frame update occured
  frameCount         : u128     = 0,   // Number of frame updates since launch

  isInit : bool = false,


  pub inline fn init( self : *EngineTiming ) void
  {
    const now : Instant = .now();

    self.loopEpoch     = now;
    self.lastTickTime  = now;
    self.lastFrameTime = now;


    const tps : Duration = .fromRayDeltaTime( @floatCast( utl.inv1( eng.G_CNFGS.Startup_Target_TickRate  ))); // == 1.0 / spt
    const fps : Duration = .fromRayDeltaTime( @floatCast( utl.inv1( eng.G_CNFGS.Startup_Target_FrameRate ))); // == 1.0 / spf

    self.targetTickDelta   = tps;
    self.measuredTickDelta = tps;
    self.smoothedTickDelta = tps;

    self.targetFrameDelta   = fps;
    self.measuredFrameDelta = fps;
    self.smoothedFrameDelta = fps;


    self.updateLoopTiming( eng.G_ENG.isPlaying() );

    self.isInit = true;
  }


  // ================ QUERY METHODS ================

  pub inline fn shouldTick( self: *const EngineTiming ) bool
  {
    return self.getTickAccumTime().value >= self.getTargetTickDeltaTime().value;
  }

  pub inline fn shouldRender( self: *const EngineTiming ) bool
  {
    return self.getFrameAccumTime().value >= self.getTargetFrameDeltaTime().value;
  }


  // ================ UPDATE METHODS ================

  pub fn updateLoopTiming( self: *EngineTiming, isPlaying : bool ) void
  {
    utl.qlog( .TRACE, @src(), "Updating engine time trackers" );

    if( utl.G_EPOCH == null )
    {
      utl.qlog( .WARN, @src(), "Global Epoch not set : setting it now");
      utl.G_EPOCH = utl.getNow();
    }

    const now : utl.Instant = .now();

    if( self.loopEpoch )| loopEpoch |
    {
      self.loopDelta = now.diff( loopEpoch ); //.scaleByFloat( self.simScale );
    }
    else
    {
      self.loopDelta = .{};
      utl.qlog( .WARN, @src(), "# EngineTiming.loopEpoch was not set");
    }
    self.loopEpoch  = now;
    self.loopCount += 1;

    if( isPlaying )
    {
      self.tickAccum.value += self.loopDelta.value;
    }
    self.frameAccum.value += self.loopDelta.value;
  }

  pub fn consumeTick( self: *EngineTiming ) void
  {
    const now : utl.Instant    = .now();
    const tickBuffLimit : i128 = @intCast( eng.G_CNFGS.Engine_Limit_QueuedTicks );

    if( tickBuffLimit == 0 )
    {
      self.tickAccum = .{};
    }
    else
    {
      self.tickAccum.value -= self.targetTickDelta.value;
      self.tickAccum.value =  utl.clmp( self.tickAccum.value, 0, tickBuffLimit * self.targetTickDelta.value );
    }

    if( self.lastTickTime )| lastTickTime |
    {
      self.measuredTickDelta = now.diff( lastTickTime );
    }
    else
    {
      utl.qlog( .WARN, @src(), "# EngineTiming.lastTickTime is not set");
    }

    self.lastTickTime  = now;
    self.tickCount += 1;

    // Smooth measuredTickDelta into smoothedTickDelta over TICK_BUFF_LEN samples
    const tickAlpha : f32 = 1.0 / @as( f32, @floatFromInt( TICK_BUFF_LEN ));
    const tmp       : f32 = utl.lerp( self.smoothedTickDelta.toRayDeltaTime(), self.measuredTickDelta.toRayDeltaTime(), tickAlpha );

    self.smoothedTickDelta = Duration.fromRayDeltaTime( tmp );
  }

  pub inline fn resetTickTiming( self : *EngineTiming ) void
  {
    self.tickAccum.value   = 0;
    self.measuredTickDelta = self.targetTickDelta;
    self.smoothedTickDelta = self.targetTickDelta;
    self.lastTickTime      = .now();
  }
  pub inline fn consumeForcedTick( self : *EngineTiming ) void
  {
    self.resetTickTiming();
    self.tickCount += 1;
  }


  pub fn consumeFrame( self: *EngineTiming ) void
  {
    const now : utl.Instant = .now();
    const frameBuffLimit : i128 = @intCast( eng.G_CNFGS.Engine_Limit_QueuedFrames );

    if( frameBuffLimit == 0 )
    {
      self.frameAccum = .{};
    }
    else
    {
      self.frameAccum.value -= self.targetFrameDelta.value;
      self.frameAccum.value  = utl.clmp( self.frameAccum.value, 0, self.targetFrameDelta.value );
    }

    if( self.lastFrameTime )| lastFrameTime |
    {
      self.measuredFrameDelta = now.diff( lastFrameTime );
    }
    else
    {
      utl.qlog( .WARN, @src(), "# EngineTiming.lastFrameTime is not set");
    }

    self.lastFrameTime  = now;
    self.frameCount += 1;

    // Smooth measuredFrameDelta into smoothedFrameDelta over FRAME_BUFF_LEN samples
    const frameAlpha : f32 = 1.0 / @as( f32, @floatFromInt( FRAME_BUFF_LEN ));
    const tmp        : f32 = utl.lerp( self.smoothedFrameDelta.toRayDeltaTime(), self.measuredFrameDelta.toRayDeltaTime(), frameAlpha );

    self.smoothedFrameDelta = Duration.fromRayDeltaTime( tmp );
  }

  pub inline fn resetFrameTiming( self : *EngineTiming ) void
  {
    self.frameAccum.value   = 0;
    self.measuredFrameDelta = self.targetFrameDelta;
    self.smoothedFrameDelta = self.targetFrameDelta;
    self.lastFrameTime      = .now();
  }
  pub inline fn consumeForcedFrame( self : *EngineTiming ) void
  {
    self.resetFrameTiming();
    self.frameCount += 1;
  }


  // ================ SETTER METHODS ================

  pub inline fn setTargetTickRate( self: *EngineTiming, newTickRate : u16 ) void
  {
    utl.log( .TRACE, @src(), "Setting tick rate to to {}", .{ newTickRate });

    self.targetTickDelta = Duration.fromTimeRate( @floatFromInt( newTickRate ));
  }

  pub inline fn setTargetFrameRate( self: *EngineTiming, newFrameRate : u16 ) void
  {
    utl.log( .TRACE, @src(), "Setting frame rate to to {}", .{ newFrameRate });

    self.targetFrameDelta = Duration.fromTimeRate( @floatFromInt( newFrameRate ));
  }


  // ================ GETTER METHODS ================

  pub inline fn getTickAccumTime(          self : *const EngineTiming ) Duration { return self.tickAccum; }
  pub inline fn getFrameAccumTime(         self : *const EngineTiming ) Duration { return self.frameAccum; }

  pub inline fn getTargetTickDeltaTime(    self : *const EngineTiming ) Duration { return self.targetTickDelta; }
  pub inline fn getTargetFrameDeltaTime(   self : *const EngineTiming ) Duration { return self.targetFrameDelta; }

  pub inline fn getMeasuredTickDeltaTime(  self : *const EngineTiming ) Duration { return self.measuredTickDelta; }
  pub inline fn getMeasuredFrameDeltaTime( self : *const EngineTiming ) Duration { return self.measuredFrameDelta; }


  pub inline fn getTickAccumFlt(           self : *const EngineTiming ) f32 { return self.tickAccum.toRayDeltaTime(); }
  pub inline fn getFrameAccumFlt(          self : *const EngineTiming ) f32 { return self.frameAccum.toRayDeltaTime(); }

  pub inline fn getTargetTickDeltaFlt(     self : *const EngineTiming ) f32 { return self.targetTickDelta.toRayDeltaTime(); }
  pub inline fn getTargetFrameDeltaFlt(    self : *const EngineTiming ) f32 { return self.targetFrameDelta.toRayDeltaTime(); }

  pub inline fn getMeasuredTickDeltaFlt(   self : *const EngineTiming ) f32 { return self.measuredTickDelta.toRayDeltaTime(); }
  pub inline fn getMeasuredFrameDeltaFlt(  self : *const EngineTiming ) f32 { return self.measuredFrameDelta.toRayDeltaTime(); }
};
