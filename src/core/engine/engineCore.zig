const std = @import( "std" );
const def = @import( "defs" );

const Cam2D      = def.Cam2D;
const Box2       = def.Box2;
const Vec2       = def.Vec2;
const VecA       = def.VecA;
const Angle      = def.Angle;
const TimeVal    = def.TimeVal;


// ================================ DEFINITIONS ================================

pub const e_ng_state = enum
{
  OFF,     // The engine is uninitialized
  STARTED, // The engine is initialized, but no window is created yet
  OPENED,  // The window is opened but game is paused ( input and render only )
  PLAYING, // The game logic is ticking and can be played
};

pub const EngineTime = struct
{
  simScale : f32 = 1.0, // Used to speed up or slow down the game without changing the tickrate

  simEpoch : TimeVal = .{}, // Time since def.GLOBAL_EPOCH
  simDelta : TimeVal = .{}, // delta from latest simTimeUpdate

//tickEpoch        : TimeVal = .{}  // simeTime at which the last tick occured         // TODO : USE US
//tickDelta        : TimeVal = .{}, // How far appart the last two tick updates were   // TODO : USE US

  targetTickDelta  : TimeVal = .{}, // How far appart tick updates should be
  tickOffset       : TimeVal = .{}, // Time since the last tick occured

//frameEpoch       : TimeVal = .{}  // simeTime at which the last frame occured        // TODO : USE US
//frameDelta       : TimeVal = .{}, // How far appart the last two frame updates were  // TODO : USE US

  targetFrameDelta : TimeVal = .{}, // How far appart frame updates should be
  frameOffset      : TimeVal = .{}, // Time since last frame update
};


pub const Engine = struct
{
  // Engine Variables
  state : e_ng_state = .OFF,
  times : EngineTime = .{},

  // Engine Substructures
  camera            : Cam2D                     = .{},

  resourceManager   : def.res_m.ResourceManager = .{},
  bodyManager       : def.bdy_m.BodyManager     = .{},
  tilemapManager    : def.tlm_m.TilemapManager  = .{},

  // ECS Management
  componentRegistry : def.ComponentRegistry     = .{},
  entityIdRegistry  : def.EntityIdRegistry      = .{},



  // ================================ HELPER FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPaused(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) == @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.PLAYING )); }

  pub fn simTimeUpdate( self : *Engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Updating engine time trackers" );

    if( !def.GLOBAL_EPOCH.isSet() )
    {
      def.qlog( .WARN, 0, @src(), "Global Epoch not set, aborting simTimeUpdate");
      return;
    }
    const lastSimEpoch   = self.times.simEpoch;
    self.times.simEpoch  = def.GLOBAL_EPOCH.timeSince();
    self.times.simDelta  = self.times.simEpoch.timeDiff( lastSimEpoch );

    if( self.isPlaying() )
    {
      self.times.tickOffset.value = self.times.tickOffset.value + self.times.simDelta.value;
    }
    self.times.frameOffset.value = self.times.frameOffset.value + self.times.simDelta.value;

  }

  pub inline fn setTargetTickRate( self : *Engine, newTickRate : u16 ) void
  {
    def.log( .TRACE, 0, @src(), "Setting tick rate to to {}", .{ newTickRate });

    self.times.targetTickDelta  = TimeVal.fromTimeRate( @floatFromInt( def.G_ST.Startup_Target_TickRate ));
  }

  pub inline fn setTargetFrameRate( self : *Engine, newFrameRate : u16 ) void
  {
    def.log( .TRACE, 0, @src(), "Setting frame rate to to {}", .{ newFrameRate });

    self.times.targetFrameDelta = TimeVal.fromTimeRate( @floatFromInt( def.G_ST.Startup_Target_FrameRate ));
  }

  pub inline fn shouldTickSim(   self : *Engine ) bool { return ( self.times.tickOffset.value  >= self.times.targetTickDelta.value  ); }
  pub inline fn shouldRenderSim( self : *Engine ) bool { return ( self.times.frameOffset.value >= self.times.targetFrameDelta.value ); }

  pub fn setTimeScale( self : *Engine, newTimeScale : f32 ) void
  {
    def.qlog( .TRACE, 0, @src(), "Setting time scale to {d}", .{ newTimeScale });
    if( newTimeScale < 0 )
    {
      def.log( .WARN, 0, @src(), "Cannot set time scale to {d}: clamping to 0", .{ newTimeScale });
      self.timeScale = 0.0;
      return;
    }
    self.timeScale = newTimeScale;
    def.log( .DEBUG, 0, @src(), "Time scale set to {d}", .{ self.timeScale });
  }

  pub inline fn getScaledTargetTickDelta(  self : *Engine ) f32 { return self.times.simScale * self.times.targetTickDelta.toRayDeltaTime();  }
  pub inline fn getScaledTargetFrameDelta( self : *Engine ) f32 { return self.times.simScale * self.times.targetFrameDelta.toRayDeltaTime(); }


  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : e_ng_state ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void { ngnState.togglePause( self ); }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic(  self : *Engine ) void { ngnStep.loopLogic( self ); }
};