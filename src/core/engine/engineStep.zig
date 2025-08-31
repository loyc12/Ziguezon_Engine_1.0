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
    def.tryHook( .OnLoopCycle, .{ ng });

    // Debug logging the frame time
    //if( comptime def.log_u.SHOW_LAPTIME ){ def.qlog( .DEBUG, 0, @src(), "! Looping" ); }
    //else { def.log_u.logLapTime(); }

    if( ng.isOpened() )
    {
      updateInputs(   ng ); // Inputs and Global Flags
      tickEntities(   ng ); // Logic and Physics
      renderGraphics( ng ); // Visuals and UI
    }
  }
  def.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );
  def.tryHook( .OnLoopEnd, .{ ng });
  def.qlog( .INFO, 0, @src(), "& Game loop stopped\n" );
}


// ================ LOOP EVENTS ================

pub fn updateInputs( ng : *Engine ) void
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


pub fn tickEntities( ng : *Engine ) void    // TODO : use tick rate instead of frame time
{
  if( !ng.isPlaying() ){ return; }


  def.qlog( .TRACE, 0, @src(), "Updating game logic..." );

  ng.sdt = def.ray.getFrameTime() * ng.timeScale;

  if( ng.isEntityManagerInit() )
  {
    def.tryHook( .OnTickEntities, .{ ng });

    ng.tickActiveEntities( ng.sdt );
    //ng.collideActiveEntities( ng.sdt );
    ng.deleteAllMarkedEntities();

  def.tryHook( .OffTickEntities, .{ ng });
  }
  else { def.qlog( .WARN, 0, @src(), "Cannot tick entities: Entity manager is not initialized" ); }
}


pub fn renderGraphics( ng : *Engine ) void    // TODO : use a render texture instead
{
  def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );

  def.ray.beginDrawing();
  defer def.ray.endDrawing();

  def.tryHook( .OnRenderBackground, .{ ng });
  {
    // TODO : Render the backgrounds here
  }
  //def.tryHook( .OffRenderBackground, .{ ng });

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
        if( def.DRAW_HITBOXES ){ ng.renderTilemapHitboxes(); }
      }
      else { def.qlog( .WARN, 0, @src(), "Cannot render tilemaps: Tilemap manager is not initialized" ); }

      if( ng.isEntityManagerInit() )
      {
        ng.renderActiveEntities();
        if( def.DRAW_HITBOXES ){ ng.renderEntityHitboxes(); }
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