const std = @import( "std" );
const def = @import( "defs" );

const Engine     = def.Engine;
const e_ng_state = def.ng.e_ng_state;


// ================================ ENGINE STATE FUNCTIONS ================================

pub fn changeState( ng : *Engine, targetState : e_ng_state ) void
{
  if( targetState == ng.state )
  {
    def.log( .WARN, 0, @src(), "State is already {s}, no change needed", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Changing state" ); }

  if( @intFromEnum( targetState ) > @intFromEnum( ng.state ) )
  {
    def.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .OFF     => start( ng ),
        .STARTED => open(  ng ),
        .OPENED  => play(  ng ),

        else =>
        {
          def.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
  }
  else
  {
    def.log( .INFO, 0, @src(), "Decreasing state from {s} to {s}", .{ @tagName( ng.state ), @tagName( targetState )});

    while( ng.state != targetState )
    {
      switch( ng.state )
      {
        .PLAYING => pause( ng ),
        .OPENED  => close( ng ),
        .STARTED => stop(  ng ),

        else =>
        {
          def.qlog( .ERROR, 0, @src(), "How did you get here ???");
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
    def.log( .WARN, 0, @src(), "Cannot start the engine in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Starting the engine..." ); }

  // Initialize relevant raylib components
  {
    if( !def.ray.isAudioDeviceReady() )
    {
      def.qlog( .INFO, 0, @src(), "# Initializing the audio device..." );
      def.ray.initAudioDevice();
    }
  }
  // Initialize relevant engine components
  {
    if( !ng.isResourceManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Initializing Resource manager" );
      ng.resourceManager = .{};
      ng.resourceManager.?.init( def.alloc );
    }
    if( !ng.isTilemapManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Initializing Tilemap manager" );
      ng.tilemapManager = .{};
      ng.tilemapManager.?.init( def.alloc );
    }
    if( !ng.isEntityManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Initializing Entity manager" );
      ng.entityManager = .{};
      ng.entityManager.?.init( def.alloc );
    }
  }
  def.tryHook( .OnStart, .{ ng });

  def.qlog( .INFO, 0, @src(), "& Hello, world !\n" );
  ng.state = .STARTED;
}

pub fn stop( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    def.log( .WARN, 0, @src(), "Cannot stop the engine in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Stoping the engine..." ); }

  def.tryHook( .OnStop, .{ ng });

  // Deinitialize relevant engine components
  {
    if( ng.isEntityManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Deinitializing Entity manager" );
      ng.entityManager.?.deinit();
    }
    if( ng.isTilemapManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Deinitializing Tilemap manager" );
      ng.tilemapManager.?.deinit();
    }
    if( ng.isResourceManagerInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Deinitializing Resource manager" );
      ng.resourceManager.?.deinit();
    }
    ng.entityManager   = null;
    ng.tilemapManager  = null;
    ng.resourceManager = null;
  }
  // Deinitialize relevant raylib components
  {
    if( def.ray.isAudioDeviceReady() )
    {
      def.qlog( .INFO, 0, @src(), "# Closing the audio device..." );
      def.ray.closeAudioDevice();
    }
  }
  ng.state = .OFF;
  def.qlog( .INFO, 0, @src(), "& Goodbye, cruel world...\n" );
}


// ================ OPEN & CLOSE ================

pub fn open( ng : *Engine ) void
{
  if( ng.state != .STARTED )
  {
    def.log( .WARN, 0, @src(), "Cannot open the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Launching the game..." ); }

  // Initialize relevant engine components
  {
    if( !ng.isCameraInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Initializing Main Camera" );
      ng.initCamera();
    }
  }
  // Initialize relevant raylib components
  {
    def.ray.setConfigFlags( // Set the window flags
      .{
        //.window_resizable   = true, // Allow the window to be resized
        //.window_undecorated = true, // Show the window decorations ( title bar, close button, etc. )
      }
    );

    if( !def.ray.isWindowReady() ) // TODO : move this to its own functions eventually ?
    {
      def.ray.initWindow(
        @intCast( def.G_ST.Startup_Window_Width  ),
        @intCast( def.G_ST.Startup_Window_Height ),
        def.G_ST.Startup_Window_Title
      );
    }
  }
  def.tryHook( .OnOpen, .{ ng });

  // TODO : Start the game loop in a second thread here ?

  ng.state = .OPENED;
  def.log( .DEBUG, 0, @src(), "& Window initialized with size {d}x{d}\n", .{ def.getScreenWidth(), def.getScreenHeight() });
}

pub fn close( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    def.log( .WARN, 0, @src(), "Cannot close the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Stopping the game..." ); }

  def.tryHook( .OnClose, .{ ng });

  // Deinitialize relevant raylib components
  {
    if( def.ray.isWindowReady() )
    {
      def.qlog( .INFO, 0, @src(), "# Closing the window..." );
      def.ray.closeWindow();
    }
  }
  // Deinitialize relevant engine components
  {
    if( ng.isCameraInit() )
    {
      def.qlog( .TRACE, 0, @src(), "Deinitializing Camera" );
      ng.deinitCamera();
    }
  }

  ng.state = .STARTED;
  def.qlog( .INFO, 0, @src(), "& Cya !\n" );
}


// ================ PLAY & PAUSE ================

pub fn play( ng : *Engine ) void
{
  if( ng.state != .OPENED )
  {
    def.log( .WARN, 0, @src(), "Cannot play the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Resuming the game..." ); }

  def.tryHook( .OnPlay, .{ ng });
  ng.state = .PLAYING;
}


pub fn pause( ng : *Engine ) void
{
  if( ng.state != .PLAYING )
  {
    def.log( .WARN, 0, @src(), "Cannot pause the game in state {s}", .{ @tagName( ng.state ) });
    return;
  }
  else { def.qlog( .TRACE, 0, @src(), "Pausing the game..." ); }

  def.tryHook( .OnPause, .{ ng });
  ng.state = .OPENED;
}

pub fn togglePause( ng : *Engine ) void
{
  def.qlog( .TRACE, 0, @src(), "Toggling pause..." );
  switch( ng.state )
  {
    .OPENED  => { play(  ng ); },
    .PLAYING => { pause( ng ); },
    else =>
    {
      def.log( .WARN, 0, @src(), "Cannot toggle pause in state ({s})", .{ @tagName( ng.state ) });
      return;
    },
  }
}