const std = @import( "std" );
const def = @import( "defs" );

const Engine = def.Engine;

// ================================ ENGINE STEP FUNCTIONS ================================

pub fn loopLogic( ng : *Engine ) void
{
  if( !ng.isOpened() )
  {
    def.log( .WARN, 0, @src(), "Cannot start the game loop in state {s}", .{ @tagName( ng.state ) });
    return;
  }

  def.qlog( .TRACE, 0, @src(), "Starting the game loop..." );
  def.tryHook( .OnLoopStart, ng );
  def.qlog( .INFO, 0, @src(), "& Game loop started\n" );

  // NOTE : this is a blocking loop, it will not return until the game is closed
  // TODO : multitread if this becomes a bottleneck

  while( !def.ray.windowShouldClose() )
  {
    ng.times.simTimeUpdate( ng.isPlaying() );

  //def.log_u.logLoopTime( ng.times.simDelta );
    def.tryHook( .OnLoopCycle, ng );

  //var loopTime = def.getNow();
    if( ng.isOpened() )
    {
      _ = tryUpdate( ng ); // Inputs and Global Flags
      _ = tryTick(   ng ); // Logic and Physics
      _ = tryRender( ng ); // Visuals and UI

    //def.log_u.logDeltaTime( loopTime.timeSince(), @src(), "! Loop delta time" );
    //loopTime = def.getNow();
    }
  }
  def.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );
  def.tryHook( .OnLoopEnd, ng );
  def.qlog( .INFO, 0, @src(), "& Game loop stopped\n" );
}


// ================ LOOP EVENTS ================

inline fn tryUpdate( ng : *Engine ) bool
{

  if( ng.times.shouldRender() ) // NOTE : Inputs are polled by EndDrawing, hence tying input rate to framerate
  {                          // TODO : see if we can split them ( if that is even useful to begin with )
  //const tmpTime = def.getNow();

  //def.ray.pollInputEvents(); // Resets and fills the input "buffer" with the latest inputs (???)
    updateInputs( ng );

  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "@ Input delta time" );
    return true;
  }
  return false;
}

inline fn updateInputs( ng : *Engine ) void
{

  def.qlog( .TRACE, 0, @src(), "Getting inputs..." );

  def.tryHook( .OnUpdateInputs, ng );
  {
    if( def.ray.isWindowResized() )
    {
      def.qlog( .TRACE, 0, @src(), "Updating camera dimensions" );
      ng.camera.updateView();
    }
  }
  //def.tryHook( .OffUpdateInputs, ng );
}


// ======== TICKING ========

inline fn tryTick( ng : *Engine ) bool
{
  if( ng.times.shouldTick() )
  {
    if( !ng.isPlaying() ){ return false; }

  //const tmpTime = def.getNow();
    ng.times.consumeTick();
    tickAll( ng );
  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "# Tick timelag" );

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
  def.qlog( .TRACE, 0, @src(), "Ticking..." );

  def.tryHook( .OnTickWorld, ng );
  {
    tickTilemaps( ng );
    tickBodies( ng );
  }
  def.tryHook( .OffTickWorld, ng );
}

inline fn tickTilemaps( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Tilemap game logic..." );

  ng.tilemapManager.tickActiveTilemaps( ng );
  ng.tilemapManager.deleteAllMarkedTilemaps();
}
inline
fn tickBodies( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Body game logic..." );

  ng.bodyManager.tickActiveBodies( ng );
  ng.bodyManager.deleteAllMarkedBodies();
}

// ======== RENDERING ========

inline fn tryRender( ng : *Engine ) bool
{
  if( ng.times.shouldRender() )
  {
    if( !ng.isOpened() ){ return false; }

  //const tmpTime = def.getNow();
    ng.times.consumeFrame();
    renderAll( ng );
  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "& Render timelag" );

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
  def.qlog( .TRACE, 0, @src(), "Rendering..." );

  def.ray.beginDrawing();
  defer def.ray.endDrawing();

  // NOTE : set Graphic_Bckgrd_Colour to null in settings to skip this step
  if( def.G_ST.Graphic_Bckgrd_Colour != null ){ def.drw_u.clearBackground( def.G_ST.Graphic_Bckgrd_Colour.? ); }

  def.tryHook( .OnRenderBckgrnd, ng );


  def.ray.beginMode2D( ng.camera.toRayCam() );
  {
    def.tryHook( .OnRenderWorld, ng );

    renderTilemaps( ng );
    renderBodies(   ng );

    def.tryHook( .OffRenderWorld, ng );
  }
  def.ray.endMode2D();


  def.tryHook( .OnRenderOverlay, ng );
  {
    drawDebugFpsCount( ng );
    drawDebugTpsCount( ng );
  }
  //def.tryHook( .OffRenderOverlay, ng );
}

inline fn renderTilemaps( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Tilemap visuals..." );

  ng.tilemapManager.renderActiveTilemaps( ng );

  if( def.G_ST.DebugDraw_Tilemap )
  {
    ng.tilemapManager.renderTilemapHitboxes();
  }
}

inline fn renderBodies( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Body visuals..." );

  ng.bodyManager.renderActiveBodies( ng );

  if( def.G_ST.DebugDraw_Body )
  {
    ng.bodyManager.renderBodyHitboxes();
  }
}



// ======== DEBUG INFO ========


inline fn drawDebugFpsCount( ng : *Engine ) void
{
  if( def.G_ST.DebugDraw_FPS and def.G_ST.Graphic_Metrics_Colour != null )
  {
    const frameTime = ng.times.lastFrameDelta;

    const sec : u64 = @intCast( frameTime.toSec() );
    const mic : u64 = @intCast( @rem( frameTime.toUs(), def.TimeVal.usPerSec() ));

    def.drawTextLeftFmt( "{d:.2} fps | {d}.{d:0>6} sec", .{ 1.0 / frameTime.toRayDeltaTime(), sec, mic }, 16.0, 24.0, 16, def.G_ST.Graphic_Metrics_Colour.? );
  }
}


inline fn drawDebugTpsCount( ng : *Engine ) void
{
  if( def.G_ST.DebugDraw_FPS )
  {
    const tickTime = ng.times.lastTickDelta;

    const sec : u64 = @intCast( tickTime.toSec() );
    const mic : u64 = @intCast( @rem( tickTime.toUs(), def.TimeVal.usPerSec() ));

    def.drawTextLeftFmt( "{d:.2} tps | {d}.{d:0>6} sec", .{ 1.0 / tickTime.toRayDeltaTime(), sec, mic }, 16.0, 56.0, 16, def.G_ST.Graphic_Metrics_Colour.? );
  }
}