const std = @import( "std" );
const def = @import( "defs" );

const engine = def.ngn.engine;

// ================================ ENGINE STEP FUNCTIONS ================================

pub fn loopLogic( ng : *engine ) void
{
  if( !ng.isOpened() )
  {
    def.log( .WARN, 0, @src(), "Cannot start the game loop in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Starting the game loop..." ); }

  def.tryHook( .OnLoopStart, .{ ng });

  // NOTE : this is a blocking loop, it will not return until the game is closed
  // TODO : use a thread to run this loop in the background ?

  while( !def.ray.windowShouldClose() )
  {
    def.tryHook( .OnLoopCycle, .{ ng });

    // NOTE : Debug logging for the frame time
    if( comptime def.logger.SHOW_LAPTIME ){ def.qlog( .DEBUG, 0, @src(), "! Looping" ); }
    else { def.logger.logLapTime(); }

    if( ng.isOpened() )
    {
      updateInputs(   ng ); // Inputs and Global Flags
      tickEntities(   ng ); // Logic and Physics
      renderGraphics( ng ); // Visuals and UI
    }
  }
  def.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );

  def.tryHook( .OnLoopEnd, .{ ng });

  def.qlog( .INFO, 0, @src(), "Game loop stopped" );
}


// ================ LOOP EVENTS ================

pub fn updateInputs( ng : *engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Getting inputs..." );
  // This function is used to get input from the user, such as keyboard or mouse input.

  def.tryHook( .OnUpdateInputs, .{ ng });
  {
    if( def.ray.isWindowResized() )
    {
      ng.screenManager.setMainCameraOffset( def.getHalfScreenSize() );
    }
  }
  //def.tryHook( .OffUpdateInputs, .{ ng });
}


pub fn tickEntities( ng : *engine ) void           // TODO : use tick rate instead of frame time
{
  if( !ng.isPlaying() ){ return; } // skip this function if the game is paused

  def.qlog( .TRACE, 0, @src(), "Updating game logic..." );

  ng.sdt = def.ray.getFrameTime() * ng.timeScale;

  def.tryHook( .OnTickEntities, .{ ng });
  {
  //ng.entityManager.collideActiveEntities( ng.sdt );
    ng.entityManager.tickActiveEntities( ng.sdt );
  }
  def.tryHook( .OffTickEntities, .{ ng });
}


pub fn renderGraphics( ng : *engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );

  def.ray.beginDrawing();
  defer def.ray.endDrawing();

  // Background Rendering mode
  def.tryHook( .OnRenderBackground, .{ ng });
  {
    // TODO : Render the backgrounds here
  }
  //def.tryHook( .OffRenderBackground, .{ ng });

  if( ng.screenManager.getMainCamera() )| camera |
  {
    // World Rendering mode
    def.ray.beginMode2D( camera );
    {
      def.tryHook( .OnRenderWorld, .{ ng });
      {
        ng.entityManager.renderActiveEntities();
      }
      def.tryHook( .OffRenderWorld, .{ ng });
    }
    def.ray.endMode2D();
  }
  else { def.qlog( .WARN, 0, @src(), "No main camera initialized, skipping world rendering" ); }

  // UI Rendering mode
  def.tryHook( .OnRenderOverlay, .{ ng });
  {
    // TODO : Render the UI elements here
  }
  //def.tryHook( .OffRenderOverlay, .{ ng });
}