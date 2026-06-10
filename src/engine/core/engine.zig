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
  rng    : utl.Randomiser    = .{},

  // Engine Managers
  world           : eng.World                     = .{},
  uiManager       : utl.UiManager                 = .{},
  tilemapManager  : eng.tilemapMgr.TilemapManager = .{}, // NOTE : will be move to World eventually
  resourceManager : eng.resMgr.ResourceManager    = .{},



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

  // ================================ ENGINE STATE FUNCTIONS ================================

  const ngnState = @import( "engineState.zig" );

  pub inline fn changeState( self : *Engine, targetState : EngineState ) void { ngnState.changeState( self, targetState ); }
  pub inline fn togglePause( self : *Engine ) void {                            ngnState.togglePause( self );              }


  // ================================ ENGINE STEP FUNCTIONS ================================

  const ngnStep = @import( "engineStep.zig" );

  pub inline fn stepEngineLoop(    self : *Engine ) void { ngnStep.stepEngineLoop(    self ); }
  pub inline fn forceUpdateInputs( self : *Engine ) void { ngnStep.forceUpdateInputs( self ); }
  pub inline fn forceTickWorld(    self : *Engine ) void { ngnStep.forceTickWorld(    self ); }
  pub inline fn forceRenderFrame(  self : *Engine ) void { ngnStep.forceRenderFrame(  self ); }
};
