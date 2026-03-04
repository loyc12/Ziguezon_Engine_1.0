const std = @import( "std" );
const def = @import( "defs" );

const TimeVal = def.TimeVal;

pub const EngineTime = struct
{
  simEpoch : TimeVal = .{}, // Time since last simTime update occured
  simDelta : TimeVal = .{}, // How far appart the last two simTime updates were
  simScale : f32     = 1.0, // Used to speed up or slow down the game globally ( ticks AND frames )
  simCount : u128    = 0,   // Number of simTime updates since launch

  targetTickDelta : TimeVal = .{}, // How far appart should each tick update be
  lastTickDelta   : TimeVal = .{}, // How far appart the last two tick updates were
  tickOffset      : TimeVal = .{}, // Time since the last tick update occured
  tickEpoch       : TimeVal = .{}, // simTime at which the last tick occured
  tickCount       : u128    = 0,   // Number of tick updates since launch

  targetFrameDelta : TimeVal = .{}, // How far appart should each frame update be
  lastFrameDelta   : TimeVal = .{}, // How far appart the last two frame updates were
  frameOffset      : TimeVal = .{}, // Time since last frame update occured
  frameEpoch       : TimeVal = .{}, // simTime at which the last frame update occured
  frameCount       : u128    = 0,   // Number of frame updates since launch

  isInit : bool = false,


  pub inline fn init( self : *EngineTime ) void
  {
    const spt : f32 = @floatFromInt( def.G_ST.Startup_Target_TickRate );
    const spf : f32 = @floatFromInt( def.G_ST.Startup_Target_FrameRate );

    self.targetTickDelta  = .fromRayDeltaTime( 1.0 / spt );
    self.targetFrameDelta = .fromRayDeltaTime( 1.0 / spf );

    self.simEpoch = .newNow();

    self.simTimeUpdate( def.G_NG.isPlaying() );

    self.isInit = true;
  }


  // ================ QUERY METHODS ================

  pub inline fn shouldTick( self: *const EngineTime ) bool
  {
    return self.getTickOffsetTime().value >= self.getTargetTickDeltaTime().value;
  }

  pub inline fn shouldRender( self: *const EngineTime ) bool
  {
    return self.getFrameOffsetTime().value >= self.getTargetFrameDeltaTime().value;
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
      self.simDelta = now.timeDiff( self.simEpoch ).scaleByFloat( self.simScale );
    }
    else
    {
      self.simDelta = .{};
      def.qlog( .WARN, 0, @src(), "# EngineTime.simEpoch was not set");
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
    const tickLagLimit : i128 = 5 * self.targetTickDelta.value;
    const now : def.TimeVal   = .newNow();

    self.tickOffset.value -= self.targetTickDelta.value;

    if( self.tickOffset.value > tickLagLimit ) // Clamping lag to N ticks or less
    {
      self.tickOffset.value = tickLagLimit;
    }

    if( self.tickEpoch.isSet() )
    {
      self.lastTickDelta = now.timeDiff( self.tickEpoch );
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
    const frameLagLimit : i128 = 5 * self.targetFrameDelta.value;
    const now : def.TimeVal    = .newNow();

    self.frameOffset.value -= self.targetFrameDelta.value;

    if( self.frameOffset.value > frameLagLimit ) // Clamping lag to N frames or less
    {
      self.frameOffset.value = frameLagLimit;
    }

    if( self.frameEpoch.isSet() )
    {
      self.lastFrameDelta = now.timeDiff( self.frameEpoch );
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

    self.targetTickDelta = TimeVal.fromTimeRate( @floatFromInt( newTickRate ));
  }

  pub inline fn setTargetFrameRate( self: *EngineTime, newFrameRate : u16 ) void
  {
    def.log( .TRACE, 0, @src(), "Setting frame rate to to {}", .{ newFrameRate });

    self.targetFrameDelta = TimeVal.fromTimeRate( @floatFromInt( newFrameRate ));
  }


  // ================ GETTER METHODS ================

  pub inline fn getTickOffsetTime(       self : *const EngineTime ) TimeVal { return self.tickOffset; }
  pub inline fn getFrameOffsetTime(      self : *const EngineTime ) TimeVal { return self.frameOffset; }

  pub inline fn getLastTickDeltaTime(    self : *const EngineTime ) TimeVal { return self.lastTickDelta; }
  pub inline fn getLastFrameDeltaTime(   self : *const EngineTime ) TimeVal { return self.lastFrameDelta; }

  pub inline fn getTargetTickDeltaTime(  self : *const EngineTime ) TimeVal { return self.targetTickDelta; }
  pub inline fn getTargetFrameDeltaTime( self : *const EngineTime ) TimeVal { return self.targetFrameDelta; }


  pub inline fn getTickOffsetFloat(       self : *const EngineTime ) f32 { return self.tickOffset.toRayDeltaTime(); }
  pub inline fn getFrameOffsetFloat(      self : *const EngineTime ) f32 { return self.frameOffset.toRayDeltaTime(); }

  pub inline fn getLastTickDeltaFloat(    self : *const EngineTime ) f32 { return self.lastTickDelta.toRayDeltaTime(); }
  pub inline fn getLastFrameDeltaFloat(   self : *const EngineTime ) f32 { return self.lastFrameDelta.toRayDeltaTime(); }

  pub inline fn getTargetTickDeltaFloat(  self : *const EngineTime ) f32 { return self.targetTickDelta.toRayDeltaTime(); }
  pub inline fn getTargetFrameDeltaFloat( self : *const EngineTime ) f32 { return self.targetFrameDelta.toRayDeltaTime(); }


  pub inline fn getScaledTickOffsetTime(       self : *const EngineTime ) TimeVal { return self.tickOffset.scaleByFloat( self.simScale ); }
  pub inline fn getScaledFrameOffsetTime(      self : *const EngineTime ) TimeVal { return self.frameOffset.scaleByFloat( self.simScale ); }

  pub inline fn getScaledLastTickDeltaTime(    self : *const EngineTime ) TimeVal { return self.lastTickDelta.scaleByFloat( self.simScale ); }
  pub inline fn getScaledLastFrameDeltaTime(   self : *const EngineTime ) TimeVal { return self.lastFrameDelta.scaleByFloat( self.simScale ); }

  pub inline fn getScaledTargetTickDeltaTime(  self : *const EngineTime ) TimeVal { return self.targetTickDelta.scaleByFloat( self.simScale ); }
  pub inline fn getScaledTargetFrameDeltaTime( self : *const EngineTime ) TimeVal { return self.targetFrameDelta.scaleByFloat( self.simScale ); }


  pub inline fn getScaledTickOffsetFloat(       self : *const EngineTime ) f32 { return self.simScale * self.tickOffset.toRayDeltaTime(); }
  pub inline fn getScaledFrameOffsetFloat(      self : *const EngineTime ) f32 { return self.simScale * self.frameOffset.toRayDeltaTime(); }

  pub inline fn getScaledLastTickDeltaFloat(    self : *const EngineTime ) f32 { return self.simScale * self.lastTickDelta.toRayDeltaTime(); }
  pub inline fn getScaledLastFrameDeltaFloat(   self : *const EngineTime ) f32 { return self.simScale * self.lastFrameDelta.toRayDeltaTime(); }

  pub inline fn getScaledTargetTickDeltaFloat(  self : *const EngineTime ) f32 { return self.simScale * self.targetTickDelta.toRayDeltaTime(); }
  pub inline fn getScaledTargetFrameDeltaFloat( self : *const EngineTime ) f32 { return self.simScale * self.targetFrameDelta.toRayDeltaTime(); }
};