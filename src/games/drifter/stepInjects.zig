const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );
const harvest  = @import( "harvestFacts.zig" );
const station  = @import( "stationFacts.zig" );

const Vec2 = utl.Vec2;

// ================================ GLOBAL GAME VARIABLES ================================

const PROCESS_TICK_INTERVAL : u128 = 60;

var SHOW_OVERLAY : bool = true;
var LAST_HARVEST_RESULT    : station.ManualHarvestResult = .{};
var LAST_PROCESSING_RESULT : station.ProcessingResult     = .{};
var LAST_DRONE_RESULT      : harvest.HarvestLoopResult    = .{};


// ================================ DRIFTER HELPERS ================================

/// Resets Drifter's current world facts and camera-centered debug view.
fn resetDrifter( ng : *eng.Engine ) void
{
  resetDrifterView();

  if( !station.resetStation( ng ))
  {
    utl.qlog( .ERROR, @src(), "Drifter station reset failed" );
  }
  else
  {
    LAST_HARVEST_RESULT    = .{ .status = .reset, .stationId = station.getStationId() };
    LAST_PROCESSING_RESULT = .{ .status = .reset, .stationId = station.getStationId() };
  }

  if( harvest.resetHarvestFacts( ng ))
  {
    LAST_DRONE_RESULT = .{ .status = .reset };
  }

  utl.qlog( .INFO, @src(), "Drifter reset" );
}

/// Resets only the camera/debug-view placement.
fn resetDrifterView() void
{
  eng.G_ENG.camera.setCenter( harvest.STATION_POS );
  utl.qlog( .INFO, @src(), "Drifter view reset" );
}

/// Runs the temporary fixed-cadence processing pass until engine scheduler
/// support owns repeated production cadence.
fn tickStationProcessing( ng : *eng.Engine ) void
{
  if( ng.time.tickCount % PROCESS_TICK_INTERVAL != 0 ){ return; }

  LAST_PROCESSING_RESULT = station.tryProcessStation( ng );
}


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
  resetDrifterView();
}

pub fn OnLoopEnd( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
}

pub fn OnLoopUpdate( ng : *eng.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng;
}


pub fn OnUpdateInputs( ng : *eng.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  // Toggle pause if the Space key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.space )){ ng.togglePause(); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }

  // Reset Drifter's world facts and camera when R is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    resetDrifter( ng );
  }

  // Toggle the testbed overlay if the T key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.t ))
  {
    SHOW_OVERLAY = !SHOW_OVERLAY;
  }

  // Manual starter harvesting stays as a debug/player bootstrap fallback when
  // autonomous drone harvesting is blocked.
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.h ))
  {
    LAST_HARVEST_RESULT = station.tryManualHarvest( ng );
  }
}


pub fn OnTickWorld( ng : *eng.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  LAST_DRONE_RESULT = harvest.tickHarvestLoop( ng, @floatCast( ng.time.getTargetTickDeltaFlt() ));
  tickStationProcessing( ng );
}

pub fn OffTickWorld( ng : *eng.Engine ) void // Called by engine.tryTick() after OnTickWorld
{
  _ = ng;
}



pub fn OnRenderBckgrnd( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng;
}


pub fn OnRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  eng.wDraw.basicCircle( harvest.STATION_POS, harvest.STATION_RADIUS, utl.Colour.mGray );

  harvest.renderHarvestWorld( ng );

  eng.wDraw.basicCirclePerim( harvest.STATION_POS, harvest.STATION_RADIUS + 2.0,  utl.Colour.pGray );
}


pub fn OnRenderOverlay( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 ));
  }

  if( SHOW_OVERLAY )
  {
    const status : [:0]const u8 = if( ng.isPaused() ) "paused" else "running";
    const summary = harvest.getHarvestSummary( ng );

    utl.sDraw.textLeft(    "DRIFTER", .new( 16.0,  96.0 ), 24, utl.Colour.pGreen );
    utl.sDraw.textLeftFmt( "state: {s} | zoom: {d:.2} | asteroids: {d} | chunks: {d} | drones: {d}", .{ status, eng.G_ENG.camera.getZoom(), summary.asteroidCount, summary.chunkCount, summary.droneCount }, .new( 16.0, 128.0 ), 18, utl.Colour.nWhite );
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
  renderProcessingStatusOverlay( LAST_PROCESSING_RESULT, .new( 16.0, 372.0 ));
  renderDroneHarvestOverlay( LAST_DRONE_RESULT, .new( 16.0, 398.0 ));

  utl.sDraw.textLeftFmt( "throughput: hangar {d:.0} | market {d:.0} | construction {d:.0}", .{ cap.hangarThroughput, cap.marketThroughput, cap.constructionCapacity }, .new( 16.0, 424.0 ), 18, utl.Colour.lGray );
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

/// Draws the latest processing result as a compact production ledger.
fn renderProcessingStatusOverlay( result : station.ProcessingResult, pos : Vec2 ) void
{
  switch( result.status )
  {
    .processed =>
    {
      if( result.blockedRecipe.len > 0 )
      {
        utl.sDraw.textLeftFmt( "process: {d} rules | +W {d:.1} +O2 {d:.1} +F {d:.1} +Food {d:.1} +C {d:.1} +M {d:.1} +E {d:.1} | blocked {s}: {s}", .{
          result.recipeCount,
          result.waterProduced,
          result.oxygenProduced,
          result.fuelProduced,
          result.foodProduced,
          result.concrete,
          result.metals,
          result.electronics,
          result.blockedRecipe,
          result.blockedNeed,
        }, pos, 18, utl.Colour.yellow );
      }
      else
      {
        utl.sDraw.textLeftFmt( "process: {d} rules | +W {d:.1} +O2 {d:.1} +F {d:.1} +Food {d:.1} +C {d:.1} +M {d:.1} +E {d:.1}", .{
          result.recipeCount,
          result.waterProduced,
          result.oxygenProduced,
          result.fuelProduced,
          result.foodProduced,
          result.concrete,
          result.metals,
          result.electronics,
        }, pos, 18, utl.Colour.pGreen );
      }
    },

    else =>
    {
      utl.sDraw.textLeftFmt( "process: {s}", .{ getProcessingStatusText( result )}, pos, 18, getProcessingStatusColour( result.status ));
    },
  }
}

inline fn getProcessingStatusText( result : station.ProcessingResult ) [ :0 ] const u8
{
  return switch( result.status )
  {
    .idle               => "idle - waiting for processing tick",
    .reset              => "reset restored defaults",
    .processed          => "processed",
    .stationUnavailable => "blocked - station unavailable",
    .missingFacts       => "blocked - station fact rows missing",
    .invalidStorage     => "blocked - invalid storage state",
    .storageFull        => "blocked - storage full",
    .shortage           => if( result.blockedNeed.len > 0 ) "blocked - shortage" else "blocked - no inputs",
  };
}

inline fn getProcessingStatusColour( status : station.ProcessingStatus ) utl.Colour
{
  return switch( status )
  {
    .idle, .reset => utl.Colour.lGray,
    .processed    => utl.Colour.pGreen,
    else          => utl.Colour.red,
  };
}

/// Draws the autonomous drone harvest state without depending on mutation code.
fn renderDroneHarvestOverlay( result : harvest.HarvestLoopResult, pos : Vec2 ) void
{
  switch( result.status )
  {
    .unloaded =>
    {
      utl.sDraw.textLeftFmt( "drones: returned +{d:.1} regolith | +{d:.1} ice | +{d:.1} ore | storage {d:.0}/{d:.0}", .{
        result.returned.regolith,
        result.returned.ice,
        result.returned.ore,
        result.storageUsed,
        result.storageCap,
      }, pos, 18, harvest.getHarvestStatusColour( result.status ));
    },

    .assigned, .chunkCreated, .harvested =>
    {
      utl.sDraw.textLeftFmt( "drones: {s} | drone {d} | chunk {d} | idle {d} busy {d}", .{
        harvest.getHarvestStatusText( result.status ),
        result.droneId,
        result.targetChunkId,
        result.idleDrones,
        result.busyDrones,
      }, pos, 18, harvest.getHarvestStatusColour( result.status ));
    },

    else =>
    {
      utl.sDraw.textLeftFmt( "drones: {s} | idle {d} busy {d} | chunks {d}", .{
        harvest.getHarvestStatusText( result.status ),
        result.idleDrones,
        result.busyDrones,
        result.chunkCount,
      }, pos, 18, harvest.getHarvestStatusColour( result.status ));
    },
  }
}
