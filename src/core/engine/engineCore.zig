const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const e_state = enum
{
  OFF,     // The engine is uninitialized
  STARTED, // The engine is initialized, but no window is created yet
  OPENED,  // The window is openned but game is paused ( input and render only )
  PLAYING, // The game is ticking and can be played
};

pub const engine = struct
{
  // Engine Variables
  state     : e_state = .OFF,
  timeScale : f32 = 1.0, // Used to speed up or slow down the game
  sdt       : f32 = 0.0, // Latest scaled delta time ( from last frame ) : == deltaTime * timeScale

  // Engine Components
  resourceManager : def.rsm.resourceManager = undefined,
  entityManager   : def.ntm.entityManager   = undefined,
  viewManager     : def.vwm.viewManager     = undefined,


  // ================================ HELPER FUNCTIONS ================================

  pub inline fn isStarted( ng : *const engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_state.STARTED )); }
  pub inline fn isOpened(  ng : *const engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_state.OPENED  )); }
  pub inline fn isPlaying( ng : *const engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_state.PLAYING )); }

  pub fn setTimeScale( self : *engine, newTimeScale : f32 ) void
  {
    def.qlog( .TRACE, 0, @src(), "Setting time scale to {d}", .{ newTimeScale });
    if( newTimeScale < 0 )
    {
      def.log( .WARN, 0, @src(), "Cannot set time scale to {d}: clamping to 0", .{ newTimeScale });
      self.timeScale = 0.0; // Clamping the time scale to 0
      return;
    }

    self.timeScale = newTimeScale;
    def.log( .DEBUG, 0, @src(), "Time scale set to {d}", .{ self.timeScale });
  }


  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *engine, targetState : e_state ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *engine ) void { ngnState.togglePause( self ); }

  //inline fn start( self : *engine ) void { ngnState.start( self ); }
  //inline fn open(  self : *engine ) void { ngnState.open(  self ); }
  //inline fn play(  self : *engine ) void { ngnState.play(  self ); }
//
  //inline fn pause( self : *engine ) void { ngnState.pause( self ); }
  //inline fn close( self : *engine ) void { ngnState.close( self ); }
  //inline fn stop(  self : *engine ) void { ngnState.stop(  self ); }



  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic(  self : *engine ) void { ngnStep.loopLogic( self ); }

  //inline fn updateInputs(   self : *engine ) void { ngnStep.updateInputs( self ); }
  //inline fn tickEntities(   self : *engine ) void { ngnStep.tickEntities( self ); }
  //inline fn renderGraphics( self : *engine ) void { ngnStep.renderGraphics( self ); }
};