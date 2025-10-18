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
  def.tryHook( .OnLoopStart, .{ ng });
  def.qlog( .INFO, 0, @src(), "& Game loop started\n" );

  // NOTE : this is a blocking loop, it will not return until the game is closed
  // TODO : use a thread to run this loop in the background ?

  while( !def.ray.windowShouldClose() )
  {
    ng.updateSimTime();

  //def.log_u.logLoopTime( ng.simDelta );
    def.tryHook( .OnLoopCycle, .{ ng });

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
  def.tryHook( .OnLoopEnd, .{ ng });
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

  def.tryHook( .OnUpdateInputs, .{ ng });
  {
    if( def.ray.isWindowResized() )
    {
      if( ng.isCameraInit() )
      {
        def.qlog( .TRACE, 0, @src(), "Updating camera dimensions" );
        ng.updateCameraView();
      }
      else { def.qlog( .WARN, 0, @src(), "No main camera initialized, skipping camera update" ); }
    }
  }
  //def.tryHook( .OffUpdateInputs, .{ ng });
}


// ======== TICKING ========

inline fn tryTick( ng : *Engine ) bool
{
  if( ng.shouldTickSim() )
  {
    const tmpTime = def.getNow();

    ng.tickOffset.value -= ng.targetTickTime.value;
    tickEntities( ng );

    def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "# Tick delta time" );
    return true;
  }
  return false;
}

fn tickEntities( ng : *Engine ) void    // TODO : use tick rate instead of frame time
{
  if( !ng.isPlaying() ){ return; }

  def.qlog( .TRACE, 0, @src(), "Updating game logic..." );

  if( ng.isEntityManagerInit() )
  {
    def.tryHook( .OnTickEntities, .{ ng });

    ng.tickActiveEntities();
    //ng.collideActiveEntities();
    ng.deleteAllMarkedEntities();

  def.tryHook( .OffTickEntities, .{ ng });
  }
  else { def.qlog( .WARN, 0, @src(), "Cannot tick entities: Entity manager is not initialized" ); }
}


// ======== RENDERING ========

inline fn tryRender( ng : *Engine ) bool
{
  if( ng.shouldRenderSim() )
  {
  //const tmpTime = def.getNow();

    ng.frameOffset.value -= ng.targetFrameTime.value;
    renderGraphics( ng );

  //def.log_u.logDeltaTime( tmpTime.timeSince(), @src(), "& Render delta time" );
    def.log_u.logFrameTime( @src());

    return true;
  }
  return false;
}

fn renderGraphics( ng : *Engine ) void    // TODO : use a render texture instead
{
  def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );

  def.ray.beginDrawing();
  defer def.ray.endDrawing();

  // NOTE : set Graphic_Bckgrd_Colour to null in settings to skip this step
  if( def.G_ST.Graphic_Bckgrd_Colour != null ){ def.ray.clearBackground( def.G_ST.Graphic_Bckgrd_Colour.? ); }

  def.tryHook( .OnRenderBackground, .{ ng });

  if( !ng.isCameraInit() )
  {
    def.qlog( .WARN, 0, @src(), "Cannot render graphics: Main camera is not initialized" );
    return;
  }

  if( ng.getCameraCpy() )| cam |
  {
    def.ray.beginMode2D( cam.toRayCam() );
    {
      def.tryHook( .OnRenderWorld, .{ ng });

      if( ng.isTilemapManagerInit() )
      {
        ng.renderActiveTilemaps();
        if( def.G_ST.DebugDraw_Tilemap ){ ng.renderTilemapHitboxes(); }
      }
      else { def.qlog( .WARN, 0, @src(), "Cannot render tilemaps: Tilemap manager is not initialized" ); }

      if( ng.isEntityManagerInit() )
      {
        ng.renderActiveEntities();
        if( def.G_ST.DebugDraw_Entity ){ ng.renderEntityHitboxes(); }
      }
      else { def.qlog( .WARN, 0, @src(), "Cannot redner entities: Entity manager is not initialized" ); }

      def.tryHook( .OffRenderWorld, .{ ng });
    }
    def.ray.endMode2D();
  }
  else { def.qlog( .WARN, 0, @src(), "No main camera found, skipping world rendering" ); }

  def.tryHook( .OnRenderOverlay, .{ ng });
  {
    // TODO : Render the UI elements here
  }
  //def.tryHook( .OffRenderOverlay, .{ ng });
}