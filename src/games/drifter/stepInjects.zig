const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );

const Vec2 = utl.Vec2;

// ================================ GLOBAL GAME VARIABLES ================================

const STATION_POS    : Vec2  = .{};
const STATION_RADIUS : f64   = 96.0;
const ASTEROID_COUNT : usize = 16;

/// Temporary visual-only asteroid marker used before asteroids become World facts.
const ShellAsteroid = struct
{
  pos      : Vec2,
  radius   : f64,
  velocity : Vec2,
};

const ASTEROID_WRAP_HEIGHT : f64 = 1024.0;
const ASTEROID_WRAP_WIDTH  : f64 = ASTEROID_WRAP_HEIGHT * 2.0;
const ASTEROID_SAFE_RADIUS : f64 = STATION_RADIUS + 160.0;

var SHOW_OVERLAY : bool = true;
// TODO: Replace this visual-only asteroid state with world-owned asteroid facts once the asteroid slice lands.
var isShellInit  : bool = false;
var asteroids    : [ ASTEROID_COUNT ]ShellAsteroid = undefined;


// ================================ SHELL HELPERS ================================

/// Resets the temporary visual shell. Later slices should replace this with
/// world-owned station and asteroid facts instead of extending this state model.
fn resetShell() void
{
  eng.G_ENG.rng.seedInit( utl.getNow().value );

  for( &asteroids )| *asteroid |{ asteroid.* = spawnShellAsteroid(); }

  eng.G_ENG.camera.setCenter( STATION_POS );
  eng.G_ENG.camera.setZoom(   1.0 );

  isShellInit = true;
  utl.qlog( .INFO, @src(), "Drifter shell reset" );
}

/// Lazily initializes the visual shell for render paths that run before loop start.
fn ensureShellInit() void
{
  if( !isShellInit ){ resetShell(); }
}

/// Creates one temporary asteroid in the current visual shell bounds.
fn spawnShellAsteroid() ShellAsteroid
{
  var pos = Vec2.new(
    randF64( @floatCast( ASTEROID_WRAP_WIDTH  ), 0.0 ),
    randF64( @floatCast( ASTEROID_WRAP_HEIGHT ), 0.0 ),
  );

  // Keep the first visual field readable around the station.
  if( pos.sub( STATION_POS ).len() < ASTEROID_SAFE_RADIUS )
  {
    pos.x += if( pos.x >= STATION_POS.x ) ASTEROID_SAFE_RADIUS else -ASTEROID_SAFE_RADIUS;
  }

  return .{
    .pos      = pos,
    .radius   = randF64( 23.0, 45.0 ),
    .velocity = .new( randF64( 25.0, 135.0 ), randF64( 60.0, 0.0 )),
  };
}

inline fn randF64( scale : f32, offset : f32 ) f64
{
  return @floatCast( eng.G_ENG.rng.getScaledFloat( scale, offset ));
}

/// Advances visual-only asteroid drift. This is not simulation scheduling.
fn tickShellVisuals( deltaTime : f64 ) void
{
  ensureShellInit();

  for( &asteroids )| *asteroid |
  {
    asteroid.pos = asteroid.pos.add( asteroid.velocity.mulVal( deltaTime ));

    // TODO: Replace wrapping with world-owned asteroid spawn/despawn behavior.
    if( asteroid.pos.x >  ASTEROID_WRAP_WIDTH  ){ asteroid.pos.x = -ASTEROID_WRAP_WIDTH;  }
    if( asteroid.pos.x < -ASTEROID_WRAP_WIDTH  ){ asteroid.pos.x =  ASTEROID_WRAP_WIDTH;  }
    if( asteroid.pos.y >  ASTEROID_WRAP_HEIGHT ){ asteroid.pos.y = -ASTEROID_WRAP_HEIGHT; }
    if( asteroid.pos.y < -ASTEROID_WRAP_HEIGHT ){ asteroid.pos.y =  ASTEROID_WRAP_HEIGHT; }
  }
}


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
  resetShell();
}

pub fn OnLoopEnd( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
}

pub fn OnLoopUpdate( ng : *eng.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng;
}


pub fn OnInputUpdate( ng : *eng.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  // Toggle pause if the Space key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.space )){ ng.togglePause(); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }

  // Reset the shell and camera when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    resetShell();
  }

  // Toggle the testbed overlay if the T key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.t ))
  {
    SHOW_OVERLAY = !SHOW_OVERLAY;
    utl.log( .DEBUG, @src(), "Drifter overlay is now: {s}", .{ if( SHOW_OVERLAY ) "true" else "false" });
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  tickShellVisuals( @floatCast( ng.time.getTargetTickDeltaFlt() ));
}

pub fn OffTickUpdate( ng : *eng.Engine ) void // Called by engine.tryTick() after OnTickUpdate
{
  _ = ng;
}



pub fn OnRenderBckgrnd( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng;
}


pub fn OnRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng;
  ensureShellInit();

  eng.wDraw.basicCircle(      STATION_POS, STATION_RADIUS,        utl.Colour.mGray );
  eng.wDraw.basicCirclePerim( STATION_POS, STATION_RADIUS + 4.0,  utl.Colour.pGray );

  for( asteroids )| asteroid |
  {
    eng.wDraw.basicCircle(      asteroid.pos, asteroid.radius,       utl.Colour.sGray );
    eng.wDraw.basicCirclePerim( asteroid.pos, asteroid.radius + 2.0, utl.Colour.dGray );
  }
}


pub fn OnRenderOverlay( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  ensureShellInit();

  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 ));
  }

  if( SHOW_OVERLAY )
  {
    const status : [:0]const u8 = if( ng.isPaused() ) "paused" else "running";

    utl.sDraw.textLeft(    "DRIFTER SHELL", .new( 16.0,  96.0 ), 24, utl.Colour.pGreen );
    utl.sDraw.textLeftFmt( "state: {s} | zoom: {d:.2} | asteroids: {d}", .{ status, eng.G_ENG.camera.getZoom(), asteroids.len }, .new( 16.0, 128.0 ), 18, utl.Colour.nWhite );
    utl.sDraw.textLeft(    "Enter/Space pause | Wheel zoom | R reset | T overlay", .new( 16.0, 154.0 ), 18, utl.Colour.lGray   );
  }
}
