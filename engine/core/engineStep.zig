const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Engine = eng.Engine;

// ================================ ENGINE STEP FUNCTIONS ================================

pub fn loopLogic( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    utl.log( .WARN, 0, @src(), "Cannot start the game loop in state {s}", .{ @tagName( ng.state ) });
    return;
  }

  utl.qlog( .TRACE, 0, @src(), "Starting the game loop..." );
  eng.tryHook( .OnLoopStart, ng );
  utl.qlog( .INFO, 0, @src(), "& Game loop started\n" );

  // NOTE : this is a blocking loop, it will not return until the game is closed
  // TODO : multitread if this becomes a bottleneck

  while( !utl.ray.windowShouldClose() )
  {
    ng.times.simTimeUpdate( ng.isPlaying() );

  //utl.log_u.logLoopTime( ng.times.simDelta );
    eng.tryHook( .OnLoopCycle, ng );

  //var loopTime = utl.getNow();
    if( ng.isOpened() )
    {
      _ = tryUpdate( ng ); // Inputs and Global Flags
      _ = tryTick(   ng ); // Logic and Physics
      _ = tryRender( ng ); // Visuals and UI

    //utl.log_u.logDeltaTime( loopTime.timeSince(), @src(), "! Loop delta time" );
    //loopTime = utl.getNow();
    }
  }
  utl.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );
  eng.tryHook( .OnLoopEnd, ng );
  utl.qlog( .INFO, 0, @src(), "& Game loop stopped\n" );
}


// ================ LOOP EVENTS ================

inline fn tryUpdate( ng : *Engine ) bool
{

  if( ng.times.shouldRender() ) // NOTE : Inputs are polled by EndDrawing, hence tying input rate to framerate
  {                          // TODO : see if we can split them ( if that is even useful to begin with )
  //const tmpTime = utl.getNow();

  //utl.ray.pollInputEvents(); // Resets and fills the input "buffer" with the latest inputs (???)
    updateFrame( ng );

  //utl.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "@ Input delta time" );
    return true;
  }
  return false;
}

inline fn updateFrame( ng : *Engine ) void
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

  eng.tryHook( .OnFrameUpdate, ng );
  ng.uiManager.endFrame();
  //eng.tryHook( .OffFrameUpdate, ng );
}


// ======== TICKING ========

inline fn tryTick( ng : *Engine ) bool
{
  if( ng.times.shouldTick() )
  {
    if( !ng.isPlaying() ){ return false; }

  //const tmpTime = utl.getNow();
    ng.times.consumeTick();
    tickAll( ng );
  //utl.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "# Tick timelag" );

    return true;
  }
  return false;
}

pub inline fn forceTick( ng : *Engine ) void
{
  ng.times.tickOffset.value += ng.times.targetTickDelta.value;

  ng.times.consumeTick();
  tickAll( ng );
}


inline fn tickAll( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Ticking..." );

  eng.tryHook( .OnTickUpdate, ng );
  {
    tickTilemaps( ng );
    tickBodies( ng );
  }
  eng.tryHook( .OffTickUpdate, ng );
}

inline fn tickTilemaps( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Tilemap game logic..." );

  ng.tilemapManager.tickActiveTilemaps( ng );
  ng.tilemapManager.deleteAllMarkedTilemaps();
}
inline
fn tickBodies( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Body game logic..." );

  ng.bodyManager.tickActiveBodies( ng );
  ng.bodyManager.deleteAllMarkedBodies();
}

// ======== RENDERING ========

inline fn tryRender( ng : *Engine ) bool
{
  if( ng.times.shouldRender() )
  {
    if( !ng.isOpened() ){ return false; }

  //const tmpTime = utl.getNow();
    ng.times.consumeFrame();
    renderAll( ng );
  //utl.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "& Render timelag" );

    return true;
  }
  return false;
}

pub inline fn forceRender( ng : *Engine ) void
{
  ng.times.frameOffset.value += ng.times.targetFrameDelta.value;

  ng.times.consumeFrame();
  renderAll( ng );
}

inline fn renderAll( ng : *Engine ) void    // TODO : use render textures instead
{
  utl.qlog( .TRACE, 0, @src(), "Rendering..." );

  utl.ray.beginDrawing();
  defer utl.ray.endDrawing();

  // NOTE : set Graphic_Bckgrd_Colour to null in settings to skip this step
  if( eng.CNFGS.Graphic_Bckgrd_Colour != null ){ utl.sDraw.clearBackground( eng.CNFGS.Graphic_Bckgrd_Colour.? ); }

  eng.tryHook( .OnRenderBckgrnd, ng );


  utl.ray.beginMode2D( eng.G_ENG.camera.toRayCam() );
  {
    eng.tryHook( .OnRenderWorld, ng );

    renderTilemaps( ng );
    renderBodies(   ng );

    eng.tryHook( .OffRenderWorld, ng );
  }
  utl.ray.endMode2D();


  eng.tryHook( .OnRenderOverlay, ng );
  {
    ng.uiManager.drawScreen();

    drawDebugFpsCount( ng );
    drawDebugTpsCount( ng );
  }
  //eng.tryHook( .OffRenderOverlay, ng );
}

inline fn renderTilemaps( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Tilemap visuals..." );

  ng.tilemapManager.renderActiveTilemaps( ng );

  if( eng.CNFGS.DebugDraw_Tilemap )
  {
    ng.tilemapManager.renderTilemapHitboxes();
  }
}

inline fn renderBodies( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Updating Body visuals..." );

  ng.bodyManager.renderActiveBodies( ng );

  if( eng.CNFGS.DebugDraw_Body )
  {
    ng.bodyManager.renderBodyHitboxes();
  }
}



// ======== DEBUG INFO ========


inline fn drawDebugFpsCount( ng : *Engine ) void
{
  if( eng.CNFGS.DebugDraw_FPS and eng.CNFGS.Graphic_Metrics_Colour != null )
  {
    const frameTime = ng.times.buffFrameDelta; // Using buffered value to ensure stable displaying

    const sec : u64 = @intCast( frameTime.toSec() );
    const mic : u64 = @intCast( @rem( frameTime.toUs(), utl.TimeVal.usPerSec() ));

    utl.sDraw.textLeftFmt( "{d:.2} fps | {d}.{d:0>6} sec", .{ 1.0 / frameTime.toRayDeltaTime(), sec, mic }, .new( 16.0, 24.0 ), 16, eng.CNFGS.Graphic_Metrics_Colour.? );
  }
}


inline fn drawDebugTpsCount( ng : *Engine ) void
{
  if( eng.CNFGS.DebugDraw_FPS )
  {
    const tickTime = ng.times.buffTickDelta; // Using buffered value to ensure stable displaying

    const sec : u64 = @intCast( tickTime.toSec() );
    const mic : u64 = @intCast( @rem( tickTime.toUs(), utl.TimeVal.usPerSec() ));

    utl.sDraw.textLeftFmt( "{d:.2} tps | {d}.{d:0>6} sec", .{ 1.0 / tickTime.toRayDeltaTime(), sec, mic }, .new( 16.0, 56.0 ), 16, eng.CNFGS.Graphic_Metrics_Colour.? );
  }
}
