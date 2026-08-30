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
  const tmng = @import( "engineTiming.zig" );

  // Engine Variables
  state  : EngineState       = .OFF,
  time   : tmng.EngineTiming = .{},
  camera : eng.WorldCam      = .{},
  mouse  : utl.Mouse         = .{},
  rng         : utl.Randomiser = .{},
  randomSeed  : i128           = 0,
  isSeedFixed : bool           = false,

  // Engine Managers
  worldManager    : eng.WorldManager           = .{},
  resourceManager : eng.resMgr.ResourceManager = .{},
  uiManager       : eng.UiManager              = .{},



  // ================================ UTILS FUNCTIONS ================================

  pub inline fn isStarted( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.STARTED )); }
  pub inline fn isOpened(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.OPENED  )); }
  pub inline fn isPaused(  ng : *const Engine ) bool { return( @intFromEnum( ng.state ) == @intFromEnum( EngineState.OPENED  )); }
  pub inline fn isPlaying( ng : *const Engine ) bool { return( @intFromEnum( ng.state ) >= @intFromEnum( EngineState.PLAYING )); }

  pub inline fn initTimers( self : *Engine ) void
  {
    self.time.init();
  }

  pub inline fn updateLoopTiming( self : *Engine ) void
  {
    self.time.updateLoopTiming( self.isPlaying() );
  }

  pub inline fn getTargetTickDelta(  self : *Engine ) f32 { return( self.time.getTargetTickDeltaFlt()    ); }
  pub inline fn getTargetFrameDelta( self : *Engine ) f32 { return( self.time.getTargetFrameDeltaFlt()   ); }
  pub inline fn getRealTickDelta(    self : *Engine ) f32 { return( self.time.getMeasuredTickDeltaFlt()  ); }
  pub inline fn getRealFrameDelta(   self : *Engine ) f32 { return( self.time.getMeasuredFrameDeltaFlt() ); }

  /// Reinitializes the engine RNG, replacing an automatic seed only when requested.
  pub fn resetRandomiser( self : *Engine, refreshAutomaticSeed : bool ) void
  {
    if( refreshAutomaticSeed and !self.isSeedFixed )
    {
      const nextSeed = utl.getNow().value;
      self.randomSeed = if( nextSeed == self.randomSeed ) nextSeed +| 1 else nextSeed;
    }

    self.rng.seedInit( self.randomSeed );
  }

  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : EngineState ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void {                            ngnState.togglePause( self );              }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn runGameLoop(      self : *Engine ) void { ngnStep.runGameLoop(      self ); }
  pub inline fn forceUpdateInputs( self : *Engine ) void { ngnStep.forceUpdateInputs( self ); }
  pub inline fn forceTickWorld(    self : *Engine ) void { ngnStep.forceTickWorld(    self ); }
  pub inline fn forceRenderFrame(  self : *Engine ) void { ngnStep.forceRenderFrame(  self ); }
};
