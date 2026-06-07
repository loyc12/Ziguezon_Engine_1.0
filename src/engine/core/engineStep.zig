const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Engine = eng.Engine;

// ================ LOOP EVENTS ================

pub fn stepEngineLoop( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    utl.log( .WARN, 0, @src(), "Cannot start the game loop in state {s}", .{ @tagName( ng.state ) });
    return;
  }

  utl.qlog( .TRACE, 0, @src(), "Starting the game loop..." );
  eng.tryHook( .OnLoopStart, ng );
  utl.qlog( .INFO, 0, @src(), "& Game loop started\n" );


  while( !utl.ray.windowShouldClose() )
  {
    ng.time.updateLoopTiming( ng.isPlaying() );

    eng.tryHook( .OnLoopUpdate, ng );

    if( ng.isOpened() )
    {
      _ = tryUpdateInputs( ng ); // Inputs and Global Flags
      _ = tryTickWorld(    ng ); // Logic and Physics
      _ = tryRenderFrame(  ng ); // Visuals and UI

    }
  }

  utl.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );
  eng.tryHook( .OnLoopEnd, ng );
  utl.qlog( .INFO, 0, @src(), "& Game loop stopped\n" );
}


// ======== INPUT UPDATING ========

inline fn tryUpdateInputs( ng : *Engine ) bool
{
  // NOTE : Inputs are polled by EndDrawing, hence tying input rate to framerate
  // TODO : see if we can split the two rates ( if that is even useful to begin with )
  if( !ng.isOpened() or !ng.time.shouldRender() ){ return false; }

  // TODO : store transient inputs into an engine owned struct to avoid unwanted input state resets
  //utl.ray.pollInputEvents(); // Resets and fills the input "buffer" with the latest inputs

  updateInputs( ng );

  return true;
}

inline fn updateInputs( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Getting inputs..." );
  {
    if( utl.ray.isWindowResized() )
    {
      utl.qlog( .TRACE, 0, @src(), "Updating camera dimensions" );
      eng.G_ENG.camera.updateView();
    }
  }

  ng.uiManager.beginFrame();
  ng.uiManager.updateLayout();
  ng.uiManager.dispatchInput();

  eng.tryHook( .OnInputUpdate, ng );
  ng.uiManager.endFrame();
}

pub inline fn forceUpdateInputs( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    utl.qlog( .WARN, 0, @src(), "@ Cannot force this step if the game is not opened yet" );
    return;
  }

  updateInputs( ng );
}


// ======== WORLD TICKING ========

inline fn tryTickWorld( ng : *Engine ) bool
{
  if( !ng.isPlaying() or !ng.time.shouldTick() ){ return false; }

  var tickCount : u8 = 0;

  while( ng.time.shouldTick() )
  {
    ng.time.consumeTick(); // Limits the number of queued ticks based on engineConfigs
    tickWorld( ng, false );
    tickCount += 1;
  }

  return tickCount > 0;
}

pub inline fn forceTickWorld( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    utl.qlog( .WARN, 0, @src(), "@ Cannot force this step if the game is not opened yet" );
    return;
  }

  ng.time.consumeForcedTick();
  tickWorld( ng, true );
}


inline fn tickWorld( ng : *Engine, isForced : bool ) void
{
  utl.qlog( .TRACE, 0, @src(), "Ticking..." );

  const tickContext : eng.TickInfo =
  .{
    .baseTickIndex = ng.time.tickCount,
    .targetDelta   = ng.time.getTargetTickDeltaTime(),
    .measuredDelta = ng.time.getMeasuredTickDeltaTime(),
    .isForced      = isForced,
  };

  // Compatibility hooks and tilemaps retain their current relative order.
  eng.tryHook( .OnTickUpdate, ng );
  {
    ng.world.tick( tickContext );
    tickTilemaps( ng );
  }
  eng.tryHook( .OffTickUpdate, ng );
}

inline fn tickTilemaps( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Tilemap game logic..." );

  ng.tilemapManager.tickActiveTilemaps( ng );
  ng.tilemapManager.deleteAllMarkedTilemaps();
}


// ======== VISUAL RENDERING ========

inline fn tryRenderFrame( ng : *Engine ) bool
{
  if( !ng.isOpened() or !ng.time.shouldRender() ){ return false; }

  ng.time.consumeFrame(); // Limits the number of queued frame to 1
  renderFrame( ng );

  return true;
}

pub inline fn forceRenderFrame( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    utl.qlog( .WARN, 0, @src(), "@ Cannot force this step if the game is not opened yet" );
    return;
  }

  ng.time.consumeForcedFrame();
  renderFrame( ng );
}

inline fn renderFrame( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Rendering..." );

  utl.ray.beginDrawing();
  defer utl.ray.endDrawing();

  // NOTE : set Graphic_Bckgrd_Colour to null in settings to skip this step
  if( eng.G_CNFGS.Graphic_Bckgrd_Colour)| col |{ utl.sDraw.clearBackground( col ); }

  eng.tryHook( .OnRenderBckgrnd, ng );


  utl.ray.beginMode2D( eng.G_ENG.camera.toRayCam() );
  {
    eng.tryHook( .OnRenderWorld, ng );

    renderTilemaps( ng );

    eng.tryHook( .OffRenderWorld, ng );
  }
  utl.ray.endMode2D();


  eng.tryHook( .OnRenderOverlay, ng );
  {
    ng.uiManager.drawScreen();

    drawDebugFpsCount( ng );
    drawDebugTpsCount( ng );
  }
}

inline fn renderTilemaps( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Tilemap visuals..." );

  ng.tilemapManager.renderActiveTilemaps( ng );

  if( eng.G_CNFGS.DebugDraw_Tilemap )
  {
    ng.tilemapManager.renderTilemapHitboxes();
  }
}


// ======== DEBUG INFO ========

inline fn drawDebugFpsCount( ng : *Engine ) void
{
  if( eng.G_CNFGS.DebugDraw_FPS and eng.G_CNFGS.Graphic_Metrics_Colour != null )
  {
    const frameTime = ng.time.smoothedFrameDelta; // Using buffered value to ensure stable displaying

    const sec : u64 = @intCast( frameTime.toSec() );
    const mic : u64 = @intCast( @rem( frameTime.toUs(), utl.TimeVal.usPerSec() ));

    utl.sDraw.textLeftFmt( "{d:.2} fps | {d}.{d:0>6} sec", .{ 1.0 / frameTime.toRayDeltaTime(), sec, mic }, .new( 16.0, 24.0 ), 16, eng.G_CNFGS.Graphic_Metrics_Colour.? );
  }
}


inline fn drawDebugTpsCount( ng : *Engine ) void
{
  if( eng.G_CNFGS.DebugDraw_FPS )
  {
    const tickTime = ng.time.smoothedTickDelta; // Using buffered value to ensure stable displaying

    const sec : u64 = @intCast( tickTime.toSec() );
    const mic : u64 = @intCast( @rem( tickTime.toUs(), utl.TimeVal.usPerSec() ));

    utl.sDraw.textLeftFmt( "{d:.2} tps | {d}.{d:0>6} sec", .{ 1.0 / tickTime.toRayDeltaTime(), sec, mic }, .new( 16.0, 56.0 ), 16, eng.G_CNFGS.Graphic_Metrics_Colour.? );
  }
}
