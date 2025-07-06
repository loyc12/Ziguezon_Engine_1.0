const std = @import( "std" );
const h   = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS = h.vec2{ .x = 2048, .y = 1024 }; // Default screen dimensions for the game window
pub const DEF_TARGET_FPS  = 60; // Default target FPS for the game
//pub const DEF_TICK_RATE   = 30; // Default tick rate for the game ( in seconds ) // TODO : USE ME

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
  sdt : f32       = 0.0, // Latest scaled delta time ( from last frame )

  entityManager : h.ntm.entityManager = undefined,
  mainCamera    : h.ray.Camera2D      = undefined,

  pub fn setTimeScale( self : *engine, newTimeScale : f32 ) void
  {
    h.qlog( .TRACE, 0, @src(), "Setting time scale to {d}", .{ newTimeScale });
    if( newTimeScale < 0 )
    {
      h.log( .WARN, 0, @src(), "Cannot set time scale to {d}: clamping to 0", .{ newTimeScale });
      self.timeScale = 0.0; // Clamping the time scale to 0
      return;
    }

    self.timeScale = newTimeScale;
    h.log( .DEBUG, 0, @src(), "Time scale set to {d}", .{ self.timeScale });
  }

  // ================================ ENGINE STATE ================================

  pub fn changeState( self : *engine, targetState : e_state ) void
  {
    h.qlog( .TRACE, 0, @src(), "Changing state" );

    if( targetState == self.state )
    {
      h.log( .WARN, 0, @src(), "State is already {s}, no change needed", .{ @tagName( self.state ) });
      return;
    }

    // If the target state is higher than the current state, we are increasing the state
    if( @intFromEnum( targetState ) > @intFromEnum( self.state ) )
    {
      h.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .CLOSED   => self.start(),
        .STARTED  => self.launch(),
        .LAUNCHED => self.play(),

        else =>
        {
          h.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
    else // If the target state is lower than the current state, we are decreasing the state
    {
      h.log( .INFO, 0, @src(), "Decreasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .PLAYING  => self.pause(),
        .LAUNCHED => self.stop(),
        .STARTED  => self.close(),

        else =>
        {
          h.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }

    // Recursively calling changeState to pass through all intermediate state changes ( if needed )
    if( self.state != targetState ){ self.changeState( targetState ); }
  }

  fn start( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Starting the engine..." );

    // Initialize the engine here ( e.g. load resources, initialize subsystems, etc. )
    self.entityManager.init( h.alloc ); // Initialize the entity manager with the default allocator

    self.mainCamera = h.ray.Camera2D{
      .offset = // TODO : make sure the offset stay accurate when the window is resized
      .{
        .x = DEF_SCREEN_DIMS.x / 2,
        .y = DEF_SCREEN_DIMS.y / 2
      },
      .target = .{ .x = 0, .y = 0 },
      .rotation = 0.0,
      .zoom = 1.0,
    };
    h.qlog( .INFO, 0, @src(), "Hello, world !\n\n" );

    h.tryHook( .OnStart, .{ self }); // Allows for custom initialization
    self.state = .STARTED;
  }

  fn launch( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Launching the game..." );

    // Prepare the engine for gameplay ( e.g. load game data, initialize game state, etc. )
    h.ray.setTargetFPS( DEF_TARGET_FPS ); // Set the target FPS for the game
    h.ray.initWindow( DEF_SCREEN_DIMS.x, DEF_SCREEN_DIMS.y, "Ziguezon Engine - Game Window" ); // Initialize the game window

    h.log( .DEBUG, 0, @src(), "Window initialized with size {d}x{d}\n\n", .{ h.ray.getScreenWidth(), h.ray.getScreenHeight() });

    h.tryHook( .OnLaunch, .{ self }); // Allows for custom initialization
    self.state = .LAUNCHED;
  }

  fn play( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Resuming the game..." );

    // Start the game loop or resume gameplay

    h.tryHook( .OnPlay, .{ self }); // Allows for custom initialization
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
        h.log( .WARN, 0, @src(), "Cannot toggle pause in current state ({s})", .{ @tagName( self.state ) });
        return;
      },
    }
  }

  fn pause( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Pausing the game..." );

    // Pause the game logic (e.g. stop updating game state, freeze animations, etc.)

    h.tryHook( .OnPause, .{ self }); // Allows for custom initialization
    self.state = .LAUNCHED;
  }

  fn stop( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Stopping the game..." );

    if( h.ray.isWindowReady() )
    {
      h.qlog( .INFO, 0, @src(), "Closing the game window..." );
      h.ray.closeWindow(); // Close the game window if it is ready
    }

    h.tryHook( .OnStop, .{ self }); // Allows for custom initialization
    self.state = .STARTED;
  }

  fn close( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Closing the engine..." );

    // Deinitialize the engine (e.g. free resources, close windows, etc.)
    self.entityManager.deinit(); // Deinitialize the entity manager

    self.entityManager = undefined; // Reset the entity manager
    self.mainCamera    = undefined; // Reset the main camera

    h.qlog( .INFO, 0, @src(), "Goodbye, cruel world...\n\n" );

    h.tryHook( .OnClose, .{ self }); // Allows for custom deinitialization
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
    h.qlog( .INFO, 0, @src(), "Starting the game loop..." );
    h.tryHook( .OnLoopStart, .{ self }); // Allows for custom initialization

    while( !h.ray.windowShouldClose() )
    {
      h.tryHook( .OnLoopIter, .{ self }); // Allows for custom initialization

      if( comptime h.logger.SHOW_LAPTIME ){ h.qlog( .DEBUG, 0, @src(), "! Looping" ); }
      else { h.logger.logLapTime(); }

      if( self.isLaunched() )
      {
        // Capturing and reacting to input events directly ( works when paused )
        self.update();

        // Running the game logic ( is unpaused )
        if( self.isUnpaused() ){ self.tick(); }

        // Rendering the game visuals
        self.render();
      }
    }

    h.qlog( .INFO, 0, @src(), "Game loop done" );
    h.tryHook( .OnLoopEnd, .{ self }); // Allows for custom deinitialization
  }

  fn update( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Getting inputs..." );
    // This function is used to get input from the user, such as keyboard or mouse input.

    h.tryHook( .OnUpdate, .{ self }); // Allows for custom input handling
  }

  fn tick( self : *engine ) void // TODO : use tick rate instead of frame time
  {
    h.qlog( .TRACE, 0, @src(), "Updating game logic..." );
    // This function is used to update the game logic, such as processing input, updating the game state, etc.

    // Get the delta time and apply the time scale
    const sdt = h.ray.getFrameTime() * self.timeScale;
    h.log( .DEBUG, 0, @src(), "Scaled Delta time : {d} seconds", .{ sdt });

    // Check for collisions between all active entities and the following ones

    h.tryHook( .OnTick, .{ self }); // Allows for custom game logic updates

    self.entityManager.tickActiveEntities( sdt ); // Tick all active entities with the delta time
  }

  fn render( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Rendering visuals..." );
    // This function is used to render the game visuals, such as drawing sprites, backgrounds, etc.
    // It uses raylib's drawing functions to draw the game visuals on the screen.

    h.ray.beginDrawing();     // Begin the drawing process
    defer h.ray.endDrawing(); // End the drawing process when the function returns

     // Clear the background with a black color
    h.ray.clearBackground( h.ray.Color.black );

    h.ray.beginMode2D( self.mainCamera ); // World Rendering mode
    {
      h.tryHook( .OnRenderWorld, .{ self }); // Allows for custom rendering of the world

      self.entityManager.renderActiveEntities(); // Render all active entities
    }

    h.ray.endMode2D(); // UI Rendering mode
    {
      h.tryHook( .OnRenderOverlay, .{ self }); // Allows for custom rendering of the overlay
    }
  }

};