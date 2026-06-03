const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;


// ================================ DEFINITIONS ================================

pub const e_ng_state = enum( u4 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  OFF,     // The engine is uninitialized
  STARTED, // The engine is initialized, but no window is created yet
  OPENED,  // The window is opened but game is paused ( input and render only )
  PLAYING, // The game logic is ticking and can be played
};


pub const Engine = struct
{
  const ngnTime = @import( "engineTime.zig" );

  // Engine Variables
  state : e_ng_state         = .OFF,
  times : ngnTime.EngineTime = .{},

  // Engine Managers
  resourceManager   : eng.res_m.ResourceManager = .{},
  bodyManager       : eng.bdy_m.BodyManager     = .{},
  tilemapManager    : eng.tlm_m.TilemapManager  = .{},
  eventManager      : eng.vnt_m.EventManager    = .{},
  uiManager         : utl.UiManager             = .{},

  // ECS Management
  componentRegistry : eng.ComponentRegistry = .{},
  entityIdRegistry  : eng.EntityIdRegistry  = .{},



  // ================================ UTILS FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPaused(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) == @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.PLAYING )); }

  pub inline fn initTimers( self : *Engine ) void
  {
    self.times.init();
  }

  pub inline fn simTimeUpdate( self : *Engine ) void
  {
    self.times.updateSimTime( self.isPlaying() );
  }

  pub inline fn getTargetFrameSDT( self : *Engine ) f32 { return( self.times.getScaledTargetFrameDeltaFloat() ); }
  pub inline fn getRealFrameSDT(   self : *Engine ) f32 { return( self.times.getScaledLastFrameDeltaFloat()   ); }
  pub inline fn getTargetTickSDT(  self : *Engine ) f32 { return( self.times.getScaledTargetTickDeltaFloat()  ); }
  pub inline fn getRealTickSDT(    self : *Engine ) f32 { return( self.times.getScaledLastTickDeltaFloat()    ); }

  pub inline fn getCamera( self : *Engine ) *utl.Cam2D { _ = self; return eng.G_CAM; } // Shortcut


  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : e_ng_state ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void {                           ngnState.togglePause( self );              }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic(  self : *Engine ) void { ngnStep.loopLogic(   self ); }
  pub inline fn forceTick(  self : *Engine ) void { ngnStep.forceTick(   self ); }
  pub inline fn forceFrame( self : *Engine ) void { ngnStep.forceRender( self ); }
};
