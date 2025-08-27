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


  // ================ RESOURCE MANAGER ================

  pub inline fn addAudio( self : *Engine, name : [ :0 ]const u8, path : [ :0 ]const u8 ) void
  {
    if ( self.resourceManager )| *m |{ m.addAudio( name, path ); }
  }
  pub inline fn addAudioFromFile( self : *Engine, name : [ :0 ]const u8, path : [ :0 ]const u8 ) !void
  {
    if ( self.resourceManager )| *m |{ return m.addAudioFromFile( name, path ); } else { return error.NullManager; }
  }
  pub inline fn playAudio( self : *Engine, name : [ :0 ]const u8 ) void
  {
    if ( self.resourceManager )| *m |{ m.playAudio( name ); }
  }


  // ================ ENTITY MANAGER ================

  pub inline fn getMaxEntityID( ng : *Engine ) u32
  {
    if( ng.entityManager )| *m |{ return m.getMaxID(); } else { return 0; }
  }
  pub inline fn getEntity( ng : *Engine, id : u32 ) ?*def.Entity
  {
    if( ng.entityManager )| *m |{ return m.getEntity( id ); } else { return null; }
  }
  pub inline fn loadEntityFromParams( ng : *Engine, params : def.Entity ) ?*def.Entity
  {
    if( ng.entityManager )| *m |{ return m.loadEntityFromParams( params ); } else { return null; }
  }
  pub inline fn deleteAllMarkedEntities( ng : *Engine ) void
  {
    if( ng.entityManager )| *m |{ m.deleteAllMarkedEntities(); }
  }

  pub inline fn tickActiveEntities( ng : *Engine, sdt : f32 ) void
  {
    if( ng.entityManager )| *m |{ m.tickActiveEntities( sdt ); }
  }
  pub inline fn renderEntityHitboxes( ng : *Engine ) void
  {
    if( ng.entityManager )| *m |{ m.renderEntityHitboxes(); }
  }
  pub inline fn renderActiveEntities( ng : *Engine ) void
  {
    if( ng.entityManager )| *m |{ m.renderActiveEntities(); }
  }


  // ================ TILEMAP MANAGER ================

  pub inline fn getMaxTilemapID( ng : *Engine ) u32
  {
    if( ng.tilemapManager )| *m |{ return m.getMaxID(); } else { return 0; }
  }
  pub inline fn getTilemap( ng : *Engine, id : u32 ) ?*def.Tilemap
  {
    if( ng.tilemapManager )| *m |{ return m.getTilemap( id ); } else { return null; }
  }
  pub inline fn loadTilemapFromParams( ng : *Engine, params : def.Tilemap, fillType : ?def.tlm.e_tile_type ) ?*def.Tilemap
  {
    if( ng.tilemapManager )| *m |{ return m.loadTilemapFromParams( def.alloc, params, fillType ); } else { return null; }
  }

//pub inline fn tickActiveTilemaps( ng : *Engine, sdt : f32 ) void
//{
//  if( ng.tilemapManager )| *m |{ m.tickActiveTilemaps( sdt ); }
//}
  pub inline fn renderActiveTilemaps( ng : *Engine ) void
  {
    if( ng.tilemapManager )| *m |{ m.renderActiveTilemaps(); }
  }
  pub inline fn deleteAllMarkedTilemaps( ng : *Engine ) void
  {
    if( ng.tilemapManager )| *m |{ m.deleteAllMarkedTilemaps(); }
  }


  // ================ VIEW MANAGER ================

  pub inline fn getCameraCpy( ng : *Engine ) ?def.Camera
  {
    if( ng.viewManager )| *m |{ return m.getCameraCpy(); } else { return null; }
  }
  pub inline fn getCameraViewBox( ng : *Engine ) ?def.Box2
  {
    if( ng.viewManager )| *m |{ return m.getCameraViewBox(); } else { return null; }
  }

  pub inline fn setCameraOffset( ng : *Engine, offset : def.Vec2 ) void
  {
    if( ng.viewManager )| *m |{ m.setCameraOffset( offset ); }
  }
  pub inline fn setCameraTarget( ng : *Engine, target : def.Vec2 ) void
  {
    if( ng.viewManager )| *m |{ m.setCameraTarget( target ); }
  }
  pub inline fn setCameraRotation( ng : *Engine, a : def.Angle ) void
  {
    if( ng.viewManager )| *m |{ m.setCameraRotation( a ); }
  }
  pub inline fn setCameraZoom( ng : *Engine, zoom : f32 ) void
  {
    if( ng.viewManager )| *m |{ m.setCameraZoom( zoom ); }
  }

  pub inline fn moveCameraBy( ng : *Engine, offset : def.Vec2 ) void
  {
    if( ng.viewManager )| *m |{ m.moveCameraBy( offset ); }
  }
  pub inline fn zoomCameraBy( ng : *Engine, factor : f32 ) void
  {
    if( ng.viewManager )| *m |{ m.zoomCameraBy( factor ); }
  }

  pub inline fn clampCameraOnArea( ng : *Engine, area : def.Box2 ) void
  {
    if( ng.viewManager )| *m |{ m.clampCameraOnArea( area ); }
  }
  pub inline fn clampCameraInArea( ng : *Engine, area : def.Box2 ) void
  {
    if( ng.viewManager )| *m |{ m.clampCameraInArea( area ); }
  }


};