const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const e_ng_state = enum
{
  OFF,     // The engine is uninitialized
  STARTED, // The engine is initialized, but no window is created yet
  OPENED,  // The window is openned but game is paused ( input and render only )
  PLAYING, // The game is ticking and can be played
};

pub const Engine = struct
{
  // Engine Variables
  state     : e_ng_state = .OFF,
  timeScale : f32 = 1.0, // Used to speed up or slow down the game
  sdt       : f32 = 0.0, // Latest scaled delta time ( from last frame ) : == deltaTime * timeScale

  // Engine Components
  resourceManager : ?def.res_m.ResourceManager = null,
  entityManager   : ?def.ntt_m.EntityManager   = null,
  tilemapManager  : ?def.tlm_m.TilemapManager  = null,
  viewManager     : ?def.scr_m.ViewManager     = null,


  // ================================ HELPER FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.PLAYING )); }

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


  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : e_ng_state ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void { ngnState.togglePause( self ); }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic(  self : *Engine ) void { ngnStep.loopLogic( self ); }


  // ================================ MANAGER SHORTHAND FUNCTIONS ================================

  pub inline fn isResourceManagerInit( ng : *const Engine ) bool { if( ng.resourceManager )| *m |{ return m.isInit; } else { return false; }}
  pub inline fn isEntityManagerInit(   ng : *const Engine ) bool { if( ng.entityManager   )| *m |{ return m.isInit; } else { return false; }}
  pub inline fn isTilemapManagerInit(  ng : *const Engine ) bool { if( ng.tilemapManager  )| *m |{ return m.isInit; } else { return false; }}
  pub inline fn isViewManagerInit(     ng : *const Engine ) bool { if( ng.viewManager     )| *m |{ return m.isInit; } else { return false; }}

  pub inline fn getResourceManager( ng : *Engine ) !*def.res_m.ResourceManager { if( ng.resourceManager )| *m |{ return m; } else { return error.NullManager; }}
  pub inline fn getEntityManager(   ng : *Engine ) !*def.ntt_m.EntityManager   { if( ng.entityManager   )| *m |{ return m; } else { return error.NullManager; }}
  pub inline fn getTilemapManager(  ng : *Engine ) !*def.tlm_m.TilemapManager  { if( ng.tilemapManager  )| *m |{ return m; } else { return error.NullManager; }}
  pub inline fn getViewManager(     ng : *Engine ) !*def.scr_m.ViewManager     { if( ng.viewManager     )| *m |{ return m; } else { return error.NullManager; }}

};