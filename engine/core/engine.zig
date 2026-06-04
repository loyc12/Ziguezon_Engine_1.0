const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;


// ================================ DEFINITIONS ================================

pub const EngineState = enum( u4 )
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
  state  : EngineState         = .OFF,
  times  : ngnTime.EngineTime = .{},
  rng    : utl.Randomiser     = .{},
  camera : eng.WorldCam       = .{},

  // Engine Managers
  resourceManager   : eng.resMgr.ResourceManager = .{},
  tilemapManager    : eng.tilemapMgr.TilemapManager  = .{},
  eventManager      : eng.eventMgr.EventManager    = .{},
  uiManager         : utl.UiManager             = .{},

  // ECS Management
  componentRegistry : eng.ComponentRegistry = .{},
  entityIdRegistry  : eng.EntityIdRegistry  = .{},



  // ================================ UTILS FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.OPENED  )); }
  pub inline fn isPaused(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) == @intFromEnum( EngineState.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.PLAYING )); }

  pub inline fn initTimers( self : *Engine ) void
  {
    self.times.init();
  }

  pub inline fn simTimeUpdate( self : *Engine ) void
  {
    self.times.updateSimTime( self.isPlaying() );
  }

  pub inline fn getTargetFrameDT( self : *Engine ) f32 { return( self.times.getTargetFrameDeltaFloat() ); }
  pub inline fn getRealFrameDT(   self : *Engine ) f32 { return( self.times.getLastFrameDeltaFloat()   ); }
  pub inline fn getTargetTickDT(  self : *Engine ) f32 { return( self.times.getTargetTickDeltaFloat()  ); }
  pub inline fn getRealTickDT(    self : *Engine ) f32 { return( self.times.getLastTickDeltaFloat()    ); }

  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : EngineState ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void {                            ngnState.togglePause( self );              }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn loopLogic( self : *Engine ) void { ngnStep.loopLogic( self ); }

//pub inline fn forceUpdateIntpus( self : *Engine ) void { ngnStep.forceUpdateInputs( self ); } // TODO : validate this works properly
  pub inline fn forceTickSim(      self : *Engine ) void { ngnStep.forceTickSim(      self ); } // TODO : validate this works properly
  pub inline fn forceRenderFrame(  self : *Engine ) void { ngnStep.forceRenderFrame(  self ); } // TODO : validate this works properly
};
