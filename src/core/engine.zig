const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS = def.vec2{ .x = 2048, .y = 1024 }; // Default screen dimensions for the game window
pub const DEF_TARGET_FPS  = 120; // Default target FPS for the game
//pub const DEF_TARGET_TPS   = 30; // Default tick rate for the game ( in seconds ) // TODO : USE ME

pub const e_state = enum // These values represent the different states of the engine.
{
  CLOSED,   // The engine is uninitialized
  STARTED,  // The engine is initialized, but no window is created yet
  LAUNCHED, // The game is paused ( only inputs and render are occuring )
  PLAYING,  // The game is ticking and can be played
};

//pub fn isAccessibleState( state : e_state ) bool { return state == .CLOSED or state == .STARTED or state == .LAUNCHED or state == .TICKING; }
pub const engine = struct
{
  state : e_state = .CLOSED,
  timeScale : f32 = 1.0, // Used to speed up or slow down the game
  sdt : f32 = 0.0, // Latest scaled delta time ( from last frame )

  rng : def.rng.randomiser = undefined, // Random number generator for the game

  // The game timer is initialized with the current time
  //gameTimer : def.timer.timer = def.timer.getNewTimer(),
  // TODO : Use this to control when to tick or not ( see DEF_TARGET_TPS )

  resourceManager : def.rsm.resourceManager = undefined,
  entityManager   : def.ntm.entityManager   = undefined,
  mainCamera      : def.ray.Camera2D        = undefined,

  pub fn setTimeScale( self : *engine, newTimeScale : f32 ) void
  {
    def.qlog( .TRACE, 0, @src(), "Setting time scale to {d}", .{ newTimeScale });
    if( newTimeScale < 0 )
    {
      def.log( .WARN, 0, @src(), "Cannot set time scale to {d}: clamping to 0", .{ newTimeScale });
      self.timeScale = 0.0; // Clamping the time scale to 0
      return;
    }

    self.timeScale = newTimeScale;
    def.log( .DEBUG, 0, @src(), "Time scale set to {d}", .{ self.timeScale });
  }

  // ================================ ENGINE STATE ================================

  pub fn changeState( self : *engine, targetState : e_state ) void
  {
    def.qlog( .TRACE, 0, @src(), "Changing state" );

    if( targetState == self.state )
    {
      def.log( .WARN, 0, @src(), "State is already {s}, no change needed", .{ @tagName( self.state ) });
      return;
    }

    // If the target state is higher than the current state, we are increasing the state
    if( @intFromEnum( targetState ) > @intFromEnum( self.state ) )
    {
      def.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .CLOSED   => self.start(),
        .STARTED  => self.launch(),
        .LAUNCHED => self.play(),

        else =>
        {
          def.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
    else // If the target state is lower than the current state, we are decreasing the state
    {
      def.log( .INFO, 0, @src(), "Decreasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .PLAYING  => self.pause(),
        .LAUNCHED => self.stop(),
        .STARTED  => self.close(),

        else =>
        {
          def.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
    // Recursively calling changeState to pass through all intermediate state changes ( if needed )
    // TODO : use switch continue instead of recursion
    if( self.state != targetState ){ self.changeState( targetState ); }
  }

  fn start( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Starting the engine..." );
    // Initialize the engine (e.g. allocate resources, set up the game state, etc.)

    self.rng.randInit();
    self.entityManager.init(   def.alloc );
    self.resourceManager.init( def.alloc );

    self.mainCamera = def.ray.Camera2D
    {
      .offset = // TODO : make sure the offset stay accurate when the window is resized
      .{
        .x = DEF_SCREEN_DIMS.x / 2,
        .y = DEF_SCREEN_DIMS.y / 2
      },
      .target = .{ .x = 0, .y = 0 },
      .rotation = 0.0,
      .zoom = 1.0,
    };

    def.qlog( .INFO, 0, @src(), "$ Hello, world !\n" );
    def.tryHook( .OnStart, .{ self });
    self.state = .STARTED;
  }

  fn launch( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Launching the game..." );

    // Prepare the engine for gameplay ( e.g. load game data, initialize game state, etc. )
    def.ray.setTargetFPS( DEF_TARGET_FPS ); // Set the target FPS for the game
    def.ray.initWindow( DEF_SCREEN_DIMS.x, DEF_SCREEN_DIMS.y, "Ziguezon Engine - Game Window" ); // Initialize the game window
    def.ray.initAudioDevice();

    def.log( .DEBUG, 0, @src(), "$ Window initialized with size {d}x{d}\n", .{ def.ray.getScreenWidth(), def.ray.getScreenHeight() });

    def.tryHook( .OnLaunch, .{ self });
    self.state = .LAUNCHED;
  }

  fn play( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Resuming the game..." );

    // Start the game loop or resume gameplay

    def.tryHook( .OnPlay, .{ self });
    self.state = .PLAYING;
  }

  pub fn togglePause( self : *engine ) void
  {
    switch( self.state )
    {
      .LAUNCHED => self.play(),
      .PLAYING  => self.pause(),
      else =>
      {
        def.log( .WARN, 0, @src(), "Cannot toggle pause in current state ({s})", .{ @tagName( self.state ) });
        return;
      },
    }
  }

  fn pause( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Pausing the game..." );

    // Pause the game logic (e.g. stop updating game state, freeze animations, etc.)

    def.tryHook( .OnPause, .{ self });
    self.state = .LAUNCHED;
  }

  fn stop( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Stopping the game..." );

    if( def.ray.isWindowReady() )
    {
      def.qlog( .INFO, 0, @src(), "# Closing the window..." );
      def.ray.closeWindow();
    }
    if( def.ray.isAudioDeviceReady() )
    {
      def.qlog( .INFO, 0, @src(), "# Closing the audio device..." );
      def.ray.closeAudioDevice();
    }

    def.tryHook( .OnStop, .{ self });
    self.state = .STARTED;
  }

  fn close( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Closing the engine..." );

    self.entityManager.deinit();
    self.resourceManager.deinit();

    self.entityManager = undefined;
    self.mainCamera    = undefined;

    def.qlog( .INFO, 0, @src(), "# Goodbye, cruel world...\n" );

    def.tryHook( .OnClose, .{ self });
    self.state = .CLOSED;
  }

  pub fn isLaunched( self : *const engine ) bool
  {
    return ( @intFromEnum( self.state ) >= @intFromEnum( e_state.LAUNCHED ));
  }
  pub fn isUnpaused( self : *const engine ) bool
  {
    return ( @intFromEnum( self.state ) >= @intFromEnum( e_state.PLAYING ));
  }

  // ================================ GAME LOOP ================================

  pub fn loopLogic( self : *engine ) void
  {
    def.qlog( .INFO, 0, @src(), "Starting the game loop..." );
    def.tryHook( .OnLoopStart, .{ self });

    while( !def.ray.windowShouldClose() )
    {
      def.tryHook( .OnLoopIter, .{ self });

      if( comptime def.logger.SHOW_LAPTIME ){ def.qlog( .DEBUG, 0, @src(), "! Looping" ); }
      else { def.logger.logLapTime(); }

      if( self.isLaunched() )
      {
        self.update();                          // Inputs and Flags
        if( self.isUnpaused() ){ self.tick(); } // Logic and movement
        self.render();                          // Visuals
      }
      //def.tryHook( .OffLoopIter, .{ self });
    }

    def.qlog( .INFO, 0, @src(), "Game loop done" );
    def.tryHook( .OnLoopEnd, .{ self });
  }

  // ================================ GAME LOGIC ================================

  fn update( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Getting inputs..." );
    // This function is used to get input from the user, such as keyboard or mouse input.

    def.tryHook( .OnUpdateStep, .{ self });
    {
      // TODO : update global inputs here
    }
    //def.tryHook( .OffUpdateStep, .{ self });
  }


  fn tick( self : *engine ) void // TODO : use tick rate instead of frame time
  {
    def.qlog( .TRACE, 0, @src(), "Updating game logic..." );
    // This function is used to update the game logic, such as processing input, updating the game state, etc.

    // Get the delta time and apply the time scale
    self.sdt = def.ray.getFrameTime() * self.timeScale;
    //def.log( .DEBUG, 0, @src(), "Scaled Delta time : {d} seconds", .{ self.sdt });

    def.tryHook( .OnTickStep, .{ self });
    {
    //self.entityManager.collideActiveEntities( self.sdt );
      self.entityManager.tickActiveEntities( self.sdt );
    }
    def.tryHook( .OffTickStep, .{ self });
  }


  fn render( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );
    // This function is used to render the game visuals, such as drawing sprites, backgrounds, etc.
    // It uses raylib's drawing functions to draw the game visuals on the screen.

    def.ray.beginDrawing();
    defer def.ray.endDrawing();

    // Background Rendering mode
    def.tryHook( .OnRenderBackground, .{ self });
    {
      // TODO : Render the background here
    }
    //def.tryHook( .OffRenderBackground, .{ self });

    // World Rendering mode
    def.ray.beginMode2D( self.mainCamera );
    {
      def.tryHook( .OnRenderWorld, .{ self });
      {
        self.entityManager.renderActiveEntities();
      }
      def.tryHook( .OffRenderWorld, .{ self });
    }
    def.ray.endMode2D();

    // UI Rendering mode
    def.tryHook( .OnRenderOverlay, .{ self });
    {
      // TODO : Render the UI elements here
    }
    //def.tryHook( .OffRenderOverlay, .{ self });
  }

};