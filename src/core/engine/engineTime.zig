const std = @import( "std" );
const def = @import( "defs" );

const TimeVal = def.TimeVal;

pub const EngineTime = struct
{
  simScale   : f32     = 1.0, // Used to speed up or slow down the game without changing the tickrate
  simEpoch   : TimeVal = .{}, // Time since def.GLOBAL_EPOCH
  simDelta   : TimeVal = .{}, // How far appart the last two simTime updates were
  simCount   : u128    = 0,   // Number of simTime updates

  tickEpoch  : TimeVal = .{}, // simTime at which the last tick occured
  tickDelta  : TimeVal = .{}, // How far appart the last two tick updates were
  tickCount  : u128    = 0,   // Number of tick updates

  frameEpoch : TimeVal = .{}, // simeTime at which the last frame occured
  frameDelta : TimeVal = .{}, // How far appart the last two frame updates were
  frameCount : u128    = 0,   // Number of frame updates

  targetTickDelta  : TimeVal = undefined,
  tickOffset       : TimeVal = .{}, // Time since the last tick occured

  targetFrameDelta : TimeVal = undefined,
  frameOffset      : TimeVal = .{}, // Time since last frame update

  isInit : bool = false,


  pub inline fn init( self : *EngineTime ) void
  {
    const spt : f32 = @floatFromInt( def.G_ST.Startup_Target_TickRate );
    const spf : f32 = @floatFromInt( def.G_ST.Startup_Target_FrameRate );

    self.targetTickDelta  = .fromRayDeltaTime( 1.0 / spt );
    self.targetFrameDelta = .fromRayDeltaTime( 1.0 / spf );

  //self.simEpoch = def.GLOBAL_EPOCH.timeSince();
    self.simEpoch = .newNow();

    self.simTimeUpdate( def.G_NG.isPlaying() );

    self.isInit = true;
  }


  // ================ QUERY METHODS ================

  pub inline fn shouldTick( self: *const EngineTime ) bool
  {
    const offset_f64   : f128 = @floatFromInt( self.tickOffset.value );
    const scaledOffset : i128 = @intFromFloat( @floor( self.simScale * offset_f64 ));

    return scaledOffset >= self.targetTickDelta.value;
  }

  pub inline fn shouldRender( self: *const EngineTime ) bool
  {
    const offset_f64   : f128 = @floatFromInt( self.frameOffset.value );
    const scaledOffset : i128 = @intFromFloat( @floor( self.simScale * offset_f64 ));

    return scaledOffset >= self.targetFrameDelta.value;
  }


  // ================ UPDATE METHODS ================

  pub fn simTimeUpdate( self: *EngineTime, isPlaying : bool ) void
  {
    def.qlog( .TRACE, 0, @src(), "Updating engine time trackers" );

    if( !def.GLOBAL_EPOCH.isSet() )
    {
      def.qlog( .WARN, 0, @src(), "Global Epoch not set, aborting simTimeUpdate");
      return;
    }

    const now : def.TimeVal = .newNow();

    if( self.simEpoch.isSet() )
    {
      self.simDelta = now.timeDiff( self.simEpoch );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "# EngineTime.simEpoch is not set");
    }
    self.simEpoch  = now;
    self.simCount += 1;

    if( isPlaying )
    {
      self.tickOffset.value += self.simDelta.value;
    }
    self.frameOffset.value += self.simDelta.value;
  }

  pub fn consumeTick( self: *EngineTime ) void
  {
    self.tickOffset.value -= self.targetTickDelta.value;

    const now : def.TimeVal = .newNow();

    if( self.tickEpoch.isSet() )
    {
      self.tickDelta = now.timeDiff( self.tickEpoch );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "# EngineTime.tickEpoch is not set");
    }
    self.tickEpoch  = now;
    self.tickCount += 1;
  }

  pub fn consumeFrame( self: *EngineTime ) void
  {
    self.frameOffset.value -= self.targetFrameDelta.value;

    const now : def.TimeVal = .newNow();

    if( self.frameEpoch.isSet() )
    {
      self.frameDelta = now.timeDiff( self.frameEpoch );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "# EngineTime.frameEpoch is not set");
    }
    self.frameEpoch  = now;
    self.frameCount += 1;
  }


  // ================ SETTER METHODS ================

  pub fn setTimeScale( self: *EngineTime, newTimeScale : f32 ) void
  {
    def.qlog( .TRACE, 0, @src(), "Setting time scale to {d}", .{ newTimeScale });
    if( newTimeScale < 0 )
    {
      def.log( .WARN, 0, @src(), "Cannot set time scale to {d}: clamping to 0", .{ newTimeScale });
      self.simScale = 0.0;
      return;
    }
    self.simScale = newTimeScale;
    def.log( .DEBUG, 0, @src(), "Time scale set to {d}", .{ self.simScale });
  }

  pub inline fn setTargetTickRate( self: *EngineTime, newTickRate : u16 ) void
  {
    def.log( .TRACE, 0, @src(), "Setting tick rate to to {}", .{ newTickRate });

    self.targetTickDelta  = TimeVal.fromTimeRate( @floatFromInt( newTickRate ));
  }

  pub inline fn setTargetFrameRate( self: *EngineTime, newFrameRate : u16 ) void
  {
    def.log( .TRACE, 0, @src(), "Setting frame rate to to {}", .{ newFrameRate });

    self.targetFrameDelta = TimeVal.fromTimeRate( @floatFromInt( newFrameRate ));
  }


  // ================ GETTER METHODS ================

  pub inline fn getScaledTickDeltaFloat( self : *const EngineTime ) f32
  {
    return self.simScale * self.tickDelta.toRayDeltaTime();
  }
  pub inline fn getScaledFrameDeltaFloat( self : *const EngineTime ) f32
  {
    return self.simScale * self.frameDelta.toRayDeltaTime();
  }

  pub inline fn getScaledTargetTickDeltaFloat( self : *const EngineTime ) f32
  {
    return self.simScale * self.targetTickDelta.toRayDeltaTime();
  }
  pub inline fn getScaledTargetFrameDeltaFloat( self : *const EngineTime ) f32
  {
    return self.simScale * self.targetFrameDelta.toRayDeltaTime();
  }
};