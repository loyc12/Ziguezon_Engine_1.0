const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );
const station  = @import( "stationFacts.zig" );

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
const ASTEROID_RADIUS_MIN  : f64 = 20.0;
const ASTEROID_RADIUS_MAX  : f64 = 80.0;
const ASTEROID_DRIFT_Y_MAX : f64 = 50.0;

var SHOW_OVERLAY : bool = true;
// TODO: Replace this visual-only asteroid state with world-owned asteroid facts once the asteroid slice lands.
var LAST_HARVEST_RESULT : station.ManualHarvestResult = .{};
var isShellInit         : bool = false;
var asteroids           : [ ASTEROID_COUNT ]ShellAsteroid = undefined;


// ================================ SHELL HELPERS ================================

/// Resets Drifter's current world facts and temporary visual shell.
/// Asteroids are still visual-only until the asteroid entity slice lands.
fn resetDrifter( ng : *eng.Engine ) void
{
  resetVisualShell();

  if( !station.resetStation( ng ))
  {
    utl.qlog( .ERROR, @src(), "Drifter station reset failed" );
  }
  else
  {
    LAST_HARVEST_RESULT = .{ .status = .reset, .stationId = station.getStationId() };
  }

  utl.qlog( .INFO, @src(), "Drifter reset" );
}

/// Resets only the temporary visual shell and camera.
fn resetVisualShell() void
{
  eng.G_ENG.rng.seedInit( utl.getNow().value );

  for( &asteroids )| *asteroid |{ asteroid.* = spawnShellAsteroid(); }

  eng.G_ENG.camera.setCenter( STATION_POS );

  isShellInit = true;
  utl.qlog( .INFO, @src(), "Drifter visual shell reset" );
}

/// Lazily initializes the visual shell for render paths that run before loop start.
fn ensureShellInit() void
{
  if( isShellInit ){ return; }

  resetVisualShell();
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
    .radius   = randLowBiasedF64( ASTEROID_RADIUS_MIN, ASTEROID_RADIUS_MAX ),
    .velocity = .new( randF64( 25.0, 125.0 ), randSignedLowBiasedF64( ASTEROID_DRIFT_Y_MAX )),
  };
}

inline fn randF64( scale : f32, offset : f32 ) f64
{
  return @floatCast( eng.G_ENG.rng.getScaledFloat( scale, offset ));
}

/// Returns a value in [min, max) biased toward min.
/// Squaring the uniform sample makes large visual asteroids rarer without
/// hiding them completely.
inline fn randLowBiasedF64( min : f64, max : f64 ) f64
{
  const unit = randUnitF64();
  return min + (( max - min ) * unit * unit );
}

/// Returns a signed value whose magnitude is biased toward zero.
/// Vertical shell drift is visual-only; this keeps fast upward/downward motion
/// uncommon while preserving both directions.
inline fn randSignedLowBiasedF64( maxMagnitude : f64 ) f64
{
  const sign : f64 = if( eng.G_ENG.rng.getBool() ) 1.0 else -1.0;
  return sign * randLowBiasedF64( 0.0, maxMagnitude );
}

inline fn randUnitF64() f64
{
  return @floatCast( eng.G_ENG.rng.getFloat( f32 ));
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
  resetVisualShell();
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
    resetDrifter( ng );
  }

  // Toggle the testbed overlay if the T key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.t ))
  {
    SHOW_OVERLAY = !SHOW_OVERLAY;
  }

  // Manual starter harvesting stays as a debug/player bootstrap control until
  // drones and asteroid jobs own the main harvest loop.
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.h ))
  {
    LAST_HARVEST_RESULT = station.tryManualHarvest( ng );
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

  eng.wDraw.basicCircle(STATION_POS, STATION_RADIUS, utl.Colour.mGray );

  for( asteroids )| asteroid |
  {
    eng.wDraw.basicCircle(      asteroid.pos, asteroid.radius,       utl.Colour.sGray );
    eng.wDraw.basicCirclePerim( asteroid.pos, asteroid.radius + 2.0, utl.Colour.dGray );
  }

  eng.wDraw.basicCirclePerim( STATION_POS, STATION_RADIUS + 2.0,  utl.Colour.pGray );
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
    utl.sDraw.textLeft(    "Enter/Space pause | Wheel zoom | H harvest | R reset | T overlay", .new( 16.0, 154.0 ), 18, utl.Colour.lGray );

    renderStationFactsOverlay( ng );
  }
}


// ================================ OVERLAY HELPERS ================================

fn renderStationFactsOverlay( ng : *eng.Engine ) void
{
  const facts = station.getStationFactView( ng ) orelse
  {
    const stationId = station.getStationId();

    if( stationId == 0 )
    {
      utl.sDraw.textLeft( "station facts: unavailable", .new( 16.0, 190.0 ), 18, utl.Colour.red );
    }
    else
    {
      utl.sDraw.textLeftFmt( "station facts: missing rows or dead entity | id: {d}", .{ stationId }, .new( 16.0, 190.0 ), 18, utl.Colour.red );
    }
    return;
  };

  const res = facts.resources;
  const rsv = facts.reserves;
  const cap = facts.capacities;
  const storageUsed = station.getStoredCargoUsed( res );

  utl.sDraw.textLeftFmt( "station id: {d}", .{ facts.stationId }, .new( 16.0, 190.0 ), 18, utl.Colour.pGreen );
  utl.sDraw.textLeftFmt( "raw: regolith {d:.0} | ice {d:.0} | ore {d:.0}", .{ res.regolith, res.ice, res.ore }, .new( 16.0, 216.0 ), 18, utl.Colour.nWhite );
  utl.sDraw.textLeftFmt( "stock: oxygen {d:.0} | fuel {d:.0} | water {d:.0} | food {d:.0} | power {d:.0}", .{ res.oxygen, res.fuel, res.water, res.food, res.power }, .new( 16.0, 242.0 ), 18, utl.Colour.nWhite );
  utl.sDraw.textLeftFmt( "built: concrete {d:.0} | metals {d:.0} | electronics {d:.0} | credits {d:.0} | pop {d:.0}", .{ res.concrete, res.metals, res.electronics, res.credits, res.population }, .new( 16.0, 268.0 ), 18, utl.Colour.nWhite );
  utl.sDraw.textLeftFmt( "reserves: regolith {d:.0} | ice {d:.0} | ore {d:.0}", .{ rsv.regolith, rsv.ice, rsv.ore }, .new( 16.0, 294.0 ), 18, utl.Colour.lGray );
  utl.sDraw.textLeftFmt( "capacity: storage {d:.0}/{d:.0} | drones {d} | process {d:.0} | power {d:.0}", .{ storageUsed, cap.storage, cap.droneSlots, cap.processingThroughput, cap.powerOutput }, .new( 16.0, 320.0 ), 18, utl.Colour.lGray );

  renderHarvestStatusOverlay( LAST_HARVEST_RESULT, .new( 16.0, 346.0 ));

  utl.sDraw.textLeftFmt( "throughput: hangar {d:.0} | market {d:.0} | construction {d:.0}", .{ cap.hangarThroughput, cap.marketThroughput, cap.constructionCapacity }, .new( 16.0, 372.0 ), 18, utl.Colour.lGray );
}

/// Draws the latest manual-harvest result without coupling overlay code to the
/// mutation rules in stationFacts.zig.
fn renderHarvestStatusOverlay( result : station.ManualHarvestResult, pos : Vec2 ) void
{
  switch( result.status )
  {
    .harvested =>
    {
      utl.sDraw.textLeftFmt( "harvest: +{d:.1} regolith | +{d:.1} ice | +{d:.1} ore | storage {d:.0}/{d:.0}", .{
        result.regolith,
        result.ice,
        result.ore,
        result.storageUsed,
        result.storageCap,
      }, pos, 18, utl.Colour.pGreen );
    },

    else =>
    {
      utl.sDraw.textLeftFmt( "harvest: {s}", .{ getHarvestStatusText( result.status )}, pos, 18, getHarvestStatusColour( result.status ));
    },
  }
}

inline fn getHarvestStatusText( status : station.ManualHarvestStatus ) [:0]const u8
{
  return switch( status )
  {
    .idle               => "idle - press H",
    .reset              => "reset restored defaults",
    .harvested          => "harvested",
    .stationUnavailable => "blocked - station unavailable",
    .missingFacts       => "blocked - station fact rows missing",
    .reservesEmpty      => "blocked - starter reserves empty",
    .storageFull        => "blocked - storage full",
  };
}

inline fn getHarvestStatusColour( status : station.ManualHarvestStatus ) utl.Colour
{
  return switch( status )
  {
    .idle, .reset => utl.Colour.lGray,
    .harvested   => utl.Colour.pGreen,
    else         => utl.Colour.red,
  };
}
