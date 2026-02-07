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
    ng.simTimeUpdate();

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

  if( ng.shouldRenderSim() ) // NOTE : Inputs are polled by EndDrawing, hence tying input rate to framerate
  {                          // TODO : see if we can split them ( if that is even useful to begin with )
  //const tmpTime = def.getNow();

  //def.ray.pollInputEvents(); // Resets and fills the input "buffer" with the latest inputs (???)
    updateInputs( ng );

  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "@ Input delta time" );
    return true;
  }
  return false;
}

fn updateInputs( ng : *Engine ) void
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
  if( ng.shouldTickSim() )
  {
    if( !ng.isPlaying() ){ return false; }

  //const tmpTime = def.getNow();

    ng.times.tickOffset.value -= ng.times.targetTickDelta.value; // TODO : ensure this doesn't create a giant backlog of tick events during lag

    def.tryHook( .OnTickWorld, ng );
    {
      tickTilemaps( ng );
      tickBodies( ng );
    }
    def.tryHook( .OffTickWorld, ng );

  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "# Tick delta time" );
    return true;
  }
  return false;
}

fn tickTilemaps( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Tilemap game logic..." );

  ng.tilemapManager.tickActiveTilemaps( ng );
  ng.tilemapManager.deleteAllMarkedTilemaps();
}

fn tickBodies( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Body game logic..." );

  ng.bodyManager.tickActiveBodies( ng );
  ng.bodyManager.deleteAllMarkedBodies();
}


// ======== RENDERING ========

inline fn tryRender( ng : *Engine ) bool
{
  if( ng.shouldRenderSim() )
  {
    if( !ng.isOpened() ){ return false; }

  //const tmpTime = def.getNow();

    ng.times.frameOffset.value -= ng.times.targetFrameDelta.value; // TODO : ensure this doesn't create a giant backlog of frame events during lag
    renderGraphics( ng );

  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "& Render delta time" );
  //def.log_u.logFrameTime( @src());

    return true;
  }
  return false;
}

fn renderGraphics( ng : *Engine ) void    // TODO : use render textures instead
{
  def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );

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

  drawDebugFpsCount( ng );
//drawDebugTpsCount( ng );

  def.tryHook( .OnRenderOverlay, ng );
  {
    // TODO : Render the UI elements here
  }
  //def.tryHook( .OffRenderOverlay, ng );
}

fn renderTilemaps( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Tilemap visuals..." );

  ng.tilemapManager.renderActiveTilemaps( ng );

  if( def.G_ST.DebugDraw_Tilemap )
  {
    ng.tilemapManager.renderTilemapHitboxes();
  }
}

fn renderBodies( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Updating Body visuals..." );

  ng.bodyManager.renderActiveBodies( ng );

  if( def.G_ST.DebugDraw_Body )
  {
    ng.bodyManager.renderBodyHitboxes();
  }
}


// ======== DEBUG INFO ========

// TODO : Implement ng.times.frameEpoch and frameDelta

fn drawDebugFpsCount( ng : *Engine ) void
{
  _ = ng;

  if( def.G_ST.DebugDraw_FPS and def.G_ST.Graphic_Metrics_Colour != null )
  {
    const frameTime = def.TimeVal.fromRayDeltaTime( def.ray.getFrameTime() ); // ng.times.frameDelta );

    const sec : u64 = @intCast( frameTime.toSec() );
    const mic : u64 = @intCast( @rem( frameTime.toUs(), def.TimeVal.usPerSec() ));

    def.drawTextFmt( "{d:.2} fps | {d}.{d:0>6} sec", .{ 1.0 / frameTime.toRayDeltaTime(), sec, mic }, 16, 16, 24, def.G_ST.Graphic_Metrics_Colour.? );
  }
}

// TODO : Implement ng.times.tickEpoch and tickDelta

//fn drawDebugTpsCount( ng : *Engine ) void
//{
//  _ = ng;
//
//  if( def.G_ST.DebugDraw_FPS )
//  {
//    const frameTime = def.TimeVal.fromRayDeltaTime( ng.times.tickDelta );
//
//    const sec : u64 = @intCast( frameTime.toSec() );
//    const mic : u64 = @intCast( @rem( frameTime.toUs(), def.TimeVal.usPerSec() ));
//
//    def.drawTextFmt( "{d:.2} tps | {d}.{d:0>6} sec", .{ 1.0 / frameTime.toRayDeltaTime(), sec, mic }, 48, 16, 32, def.Colour.Graphic_Metrics_Colour );
//  }
//}