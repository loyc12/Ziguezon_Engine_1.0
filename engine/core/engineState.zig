const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Engine     = eng.Engine;
const e_ng_state = eng.ng.e_ng_state;


// ================================ ENGINE STATE FUNCTIONS ================================

pub fn changeState( ng : *Engine, targetState : e_ng_state ) void
{
  if( targetState == ng.state )
  {
    utl.log( .WARN, 0, @src(), "State is already {s}, no change needed", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Changing state" ); }

  if( @intFromEnum( targetState ) > @intFromEnum( ng.state ) )
  {
    utl.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .OFF     => start( ng ),
        .STARTED => open(  ng ),
        .OPENED  => play(  ng ),

        else =>
        {
          utl.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
  }
  else
  {
    utl.log( .INFO, 0, @src(), "Decreasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .PLAYING => pause( ng ),
        .OPENED  => close( ng ),
        .STARTED => stop(  ng ),

        else =>
        {
          utl.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
  }
}


// ================ START & STOP ================

pub fn start( ng : *Engine ) void
{
  if( ng.state != .OFF )
  {
    utl.log( .WARN, 0, @src(), "Cannot start the engine in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Starting the engine..." ); }

  // Initialize relevant raylib components
  {
    eng.G_CAM.zoom = eng.G_ST.Camera_Zoom_Init;

    if( !utl.ray.isAudioDeviceReady() )
    {
      utl.qlog( .INFO, 0, @src(), "# Initializing audio device..." );
      utl.ray.initAudioDevice();
      utl.qlog( .INFO, 0, @src(), "& Audio device initialized !" );
    }
  }

  // Initialize relevant engine managers
  {
    utl.qlog( .INFO, 0, @src(), "# Initializing engine substructs..." );

    ng.resourceManager.init(   eng.getAlloc() );
    ng.tilemapManager.init(    eng.getAlloc() );
    ng.bodyManager.init(       eng.getAlloc() );
    ng.eventManager.init(      eng.getAlloc() );
    ng.uiManager.init(         eng.getAlloc() );
    ng.componentRegistry.init( eng.getAlloc() );

    utl.qlog( .INFO, 0, @src(), "& Engine substructs initialized !" );
  }

  eng.tryHook( .OnStart, ng );

  utl.qlog( .INFO, 0, @src(), "& Hello, world !\n" );
  ng.state = .STARTED;
}

pub fn stop( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    utl.log( .WARN, 0, @src(), "Cannot stop the engine in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Stoping the engine..." ); }

  eng.tryHook( .OnStop, ng );

  // Deinitialize relevant engine managers
  {
    utl.qlog( .INFO, 0, @src(), "# Deinitializing engine substructs..." );

    ng.componentRegistry.deinit();
    ng.uiManager.deinit();
    ng.eventManager.deinit();
    ng.bodyManager.deinit();
    ng.tilemapManager.deinit();
    ng.resourceManager.deinit();

    utl.qlog( .INFO, 0, @src(), "& Engine substructs deinitialized !" );
  }

  // Deinitialize relevant raylib components
  {
    if( utl.ray.isAudioDeviceReady() )
    {
      utl.qlog( .INFO, 0, @src(), "# Closing the audio device..." );
      utl.ray.closeAudioDevice();
    }
  }
  ng.state = .OFF;
  utl.qlog( .INFO, 0, @src(), "& Goodbye, cruel world...\n" );
}


// ================ OPEN & CLOSE ================

pub fn open( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    utl.log( .WARN, 0, @src(), "Cannot open the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Launching the game..." ); }

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
      utl.qlog( .INFO, 0, @src(), "# Opening the window..." );

      utl.ray.initWindow(
        @intCast( eng.G_ST.Startup_Window_Width  ),
        @intCast( eng.G_ST.Startup_Window_Height ),
        eng.G_ST.Startup_Window_Title
      );

      // TODO : Check if this font leaks
      _ = utl.sDraw.setDefaultFont( eng.G_ST.Graphic_Default_Font );
    }
  }
  eng.tryHook( .OnOpen, ng );

  // TODO : Start the game loop in a second thread here ?

  ng.state = .OPENED;
  utl.log( .DEBUG, 0, @src(), "& Window initialized with size {d}x{d}\n", .{ utl.getScreenWidth(), utl.getScreenHeight() });
}

pub fn close( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    utl.log( .WARN, 0, @src(), "Cannot close the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Stopping the game..." ); }

  eng.tryHook( .OnClose, ng );

  // Deinitialize relevant raylib components
  {
    if( utl.ray.isWindowReady() )
    {
      utl.qlog( .INFO, 0, @src(), "# Closing the window..." );
      utl.ray.closeWindow();
    }
  }

  ng.state = .STARTED;
  utl.qlog( .INFO, 0, @src(), "& Cya !\n" );
}


// ================ PLAY & PAUSE ================

pub fn play( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    utl.log( .WARN, 0, @src(), "Cannot play the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Resuming the game..." ); }

  eng.tryHook( .OnPlay, ng );
  ng.state = .PLAYING;
}


pub fn pause( ng : *Engine ) void
{
  if( ng.state != .PLAYING )
  {
    utl.log( .WARN, 0, @src(), "Cannot pause the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { utl.qlog( .TRACE, 0, @src(), "Pausing the game..." ); }

  eng.tryHook( .OnPause, ng );
  ng.state = .OPENED;
}

pub fn togglePause( ng : *Engine ) void
{
  utl.qlog( .TRACE, 0, @src(), "Toggling pause..." );
  switch( ng.state )
  {
    .OPENED  => { play(  ng ); },
    .PLAYING => { pause( ng ); },
    else =>
    {
      utl.log( .WARN, 0, @src(), "Cannot toggle pause in state ({s})", .{ @tagName( ng.state ) });
      return;
    },
  }
}
