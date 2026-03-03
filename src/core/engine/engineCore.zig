const std = @import( "std" );
const def = @import( "defs" );

const Cam2D = def.Cam2D;
const Box2  = def.Box2;
const Vec2  = def.Vec2;
const VecA  = def.VecA;
const Angle = def.Angle;


// ================================ DEFINITIONS ================================

pub const e_ng_state = enum
{
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

  // Engine Substructures
  camera : Cam2D = .{},

  resourceManager   : def.res_m.ResourceManager = .{},
  bodyManager       : def.bdy_m.BodyManager     = .{},
  tilemapManager    : def.tlm_m.TilemapManager  = .{},
  eventManager      : def.vnt_m.EventManager    = .{},

  // ECS Management
  componentRegistry : def.ComponentRegistry     = .{},
  entityIdRegistry  : def.EntityIdRegistry      = .{},



  // ================================ UTILS FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPaused(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) == @intFromEnum( e_ng_state.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( e_ng_state.PLAYING )); }



  pub fn simTimeUpdate( self : *Engine ) void
  {
    self.times.updateSimTime( self.isPlaying() );
  }


  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : e_ng_state ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void {                           ngnState.togglePause( self );              }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic(  self : *Engine ) void { ngnStep.loopLogic( self ); }
};