const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Engine     = eng.Engine;
const EngineState = eng.engineCore.EngineState;


// ================================ ENGINE STATE FUNCTIONS ================================

pub fn changeState( ng : *Engine, targetState : EngineState ) void
{
  if( targetState == ng.state )
  {
    utl.log( .WARN, @src(), "@ State is already {s}, no change needed", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "Changing state" ); }

  if( @intFromEnum( targetState ) > @intFromEnum( ng.state ) )
  {
    utl.log( .DEBUG, @src(), "# Increasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .OFF     => start( ng ),
        .STARTED => open(  ng ),
        .OPENED  => play(  ng ),
        else     => unreachable,
      }
    }
  }
  else
  {
    utl.log( .DEBUG, @src(), "# Decreasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .PLAYING => pause( ng ),
        .OPENED  => close( ng ),
        .STARTED => stop(  ng ),
        else     => unreachable,
      }
    }
  }
}


// ================ START & STOP ================

pub fn start( ng : *Engine ) void
{
  if( ng.state != .OFF )
  {
    utl.log( .WARN, @src(), "@ Cannot start the engine from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Starting the engine..." ); }

  // Initialize relevant raylib components
  {
    eng.G_ENG.camera.configZoom(
      @floatCast( eng.G_CNFGS.Camera_Zoom_Min  ),
      @floatCast( eng.G_CNFGS.Camera_Zoom_Max  ),
      @floatCast( eng.G_CNFGS.Camera_Zoom_Init ),
    );

    if( !utl.ray.isAudioDeviceReady() )
    {
      utl.qlog( .INFO, @src(), "& Initializing audio device..." );
      utl.ray.initAudioDevice();
      utl.qlog( .INFO, @src(), "$ Audio device initialized !" );
    }
  }

  // Initialize relevant engine managers
  {
    utl.qlog( .INFO, @src(), "# Initializing engine substructs..." );

    ng.resourceManager.init(   utl.getDefaultAlloc() );
    ng.tilemapManager.init(    utl.getDefaultAlloc() );
    ng.world.init(             utl.getDefaultAlloc() );
    ng.uiManager.init(         utl.getDefaultAlloc() );

    utl.qlog( .INFO, @src(), "$ Engine substructs initialized !" );
  }

  eng.tryHook( .OnGameStart, ng );

  utl.qlog( .INFO, @src(), "& Hello, world !\n" );
  ng.state = .STARTED;
}

pub fn stop( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    utl.log( .WARN, @src(), "@ Cannot stop the engine from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Stoping the engine..." ); }

  eng.tryHook( .OnGameStop, ng );

  // Deinitialize relevant engine managers
  {
    utl.qlog( .INFO, @src(), "# Deinitializing engine substructs..." );

    ng.uiManager.deinit();
    ng.world.deinit();
    ng.tilemapManager.deinit();
    ng.resourceManager.deinit();

    utl.qlog( .INFO, @src(), "$ Engine substructs deinitialized !" );
  }

  // Deinitialize relevant raylib components
  {
    if( utl.ray.isAudioDeviceReady() )
    {
      utl.qlog( .INFO, @src(), "& Closing audio device..." );
      utl.ray.closeAudioDevice();
    }
  }
  ng.state = .OFF;
  utl.qlog( .INFO, @src(), "& Goodbye, cruel world...\n" );
}


// ================ OPEN & CLOSE ================

pub fn open( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    utl.log( .WARN, @src(), "@ Cannot open the game from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Launching the game..." ); }

  // Initialize relevant raylib components
  {
    utl.ray.setConfigFlags( // Set the window flags
      .{
        .window_resizable   = true, // Allow the window to be resized
      //.window_undecorated = true, // Hides the window decorations ( title bar, close button, etc. )
      }
    );

    if( !utl.ray.isWindowReady() ) // TODO : move this to its own functions eventually ?
    {
      utl.qlog( .INFO, @src(), "& Opening the window..." );

      utl.ray.initWindow(
        @intCast( eng.G_CNFGS.Startup_Window_Width  ),
        @intCast( eng.G_CNFGS.Startup_Window_Height ),
        eng.G_CNFGS.Startup_Window_Title
      );

      // TODO : Check if this font leaks
      _ = utl.sDraw.setDefaultFont( eng.G_CNFGS.Graphic_Default_Font );
    }
  }
  eng.tryHook( .OnGameOpen, ng );

  // TODO : Start the game loop in a second thread here ?

  ng.state = .OPENED;
  utl.log( .DEBUG, @src(), "& Window initialized with size {d}x{d}\n", .{ utl.getScreenWidth(), utl.getScreenHeight() });
}

pub fn close( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    utl.log( .WARN, @src(), "@ Cannot close the game from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Stopping the game..." ); }

  eng.tryHook( .OnGameClose, ng );

  // Deinitialize relevant raylib components
  {
    if( utl.ray.isWindowReady() )
    {
      utl.qlog( .INFO, @src(), "& Closing the window..." );
      utl.ray.closeWindow();
    }
  }

  ng.state = .STARTED;
  utl.qlog( .INFO, @src(), "& Cya !\n" );
}


// ================ PLAY & PAUSE ================

pub fn play( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    utl.log( .WARN, @src(), "@ Cannot resume the game from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Resuming the game..." ); }

  eng.tryHook( .OnGameResume, ng );
  ng.state = .PLAYING;

  // Prevent calculating pause time as tick delay
  ng.time.resetTickTiming();
}


pub fn pause( ng : *Engine ) void
{
  if( ng.state != .PLAYING )
  {
    utl.log( .WARN, @src(), "@ Cannot pause the game from state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, @src(), "# Pausing the game..." ); }

  eng.tryHook( .OnGamePause, ng );
  ng.state = .OPENED;
}

pub fn togglePause( ng : *Engine ) void
{
  utl.qlog( .TRACE, @src(), "# Toggling pause..." );
  switch( ng.state )
  {
    .OPENED  => { play(  ng ); },
    .PLAYING => { pause( ng ); },
    else =>
    {
      utl.log( .WARN, @src(), "@ Cannot toggle pause from state {s}", .{ @tagName( ng.state ) });
      return;
    },
  }
}
