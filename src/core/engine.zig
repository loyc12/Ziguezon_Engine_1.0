const std = @import( "std" );
const h   = @import( "../headers.zig" );
const ntm = @import( "entityManager.zig" );

// ================================ DEFINITIONS ================================

pub var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

pub const DEF_SCREEN_DIMS = h.vec2{ .x = 2048, .y = 1024 }; // Default screen dimensions for the game window
pub const DEF_TARGET_FPS  = 60; // Default target FPS for the game
//pub const DEF_TICK_RATE   = 30; // Default tick rate for the game ( in seconds ) // TODO : USE ME

pub const e_state = enum // These values represent the different states of the engine.
{
  CLOSED,   // The engine is uninitialized
  STARTED,  // The engine is initialized, but no window is created yet
  LAUNCHED, // The game is plaused ( only inputs and render are occuring )
  PLAYING,  // The game is ticking and can be played
};

//pub fn isAccessibleState( state : e_state ) bool { return state == .CLOSED or state == .STARTED or state == .LAUNCHED or state == .TICKING; }
pub const engine = struct
{
  state : e_state = .CLOSED, // The current state of the engine
  timeScale : f32 = 1.0, // The time scale of the engine ( used to speed up or slow down the game )

  entityManager : ntm.entityManager = undefined,
  mainCamera    : h.rl.Camera2D     = undefined,

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

    self.mainCamera = h.rl.Camera2D{
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

    h.OnStart( self ); // Allows for custom initialization
    self.state = .STARTED;
  }

  fn launch( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Launching the game..." );

    // Prepare the engine for gameplay ( e.g. load game data, initialize game state, etc. )
    h.rl.setTargetFPS( DEF_TARGET_FPS ); // Set the target FPS for the game
    h.rl.initWindow( DEF_SCREEN_DIMS.x, DEF_SCREEN_DIMS.y, "Ziguezon Engine - Game Window" ); // Initialize the game window

    h.log( .DEBUG, 0, @src(), "Window initialized with size {d}x{d}\n\n", .{ h.rl.getScreenWidth(), h.rl.getScreenHeight() });

    h.OnLaunch( self ); // Allows for custom initialization
    self.state = .LAUNCHED;
  }

  fn play( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Resuming the game..." );

    // Start the game loop or resume gameplay

    h.OnPlay( self ); // Allows for custom initialization
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

    h.OnPause( self ); // Allows for custom initialization
    self.state = .LAUNCHED;
  }

  fn stop( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Stopping the game..." );

    if( h.rl.isWindowReady() )
    {
      h.qlog( .INFO, 0, @src(), "Closing the game window..." );
      h.rl.closeWindow(); // Close the game window if it is ready
    }

    h.OnStop( self ); // Allows for custom initialization
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

    h.OnClose( self ); // Allows for custom deinitialization
    self.state = .CLOSED;
  }

  // ================================ GAME LOOP ================================

  pub fn loopLogic( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Starting the game loop..." );
    h.OnLoopStart( self ); // Allows for custom initialization

    while( !h.rl.windowShouldClose() )
    {
      h.OnLoopIter( self ); // Allows for custom initialization

      if( comptime h.logger.SHOW_LAPTIME ){ h.qlog( .DEBUG, 0, @src(), "! Looping" ); }
      else { h.logger.logLapTime(); }

      if( @intFromEnum( self.state ) >= @intFromEnum( e_state.LAUNCHED ))
      {
        // Capturing and reacting to input events directly ( works when paused )
        self.update();

        // Running the game logic ( forzen when paused )
        if( @intFromEnum( self.state ) >= @intFromEnum( e_state.PLAYING )){ self.tick(); }

        // Rendering the game visuals
        self.render();
      }
    }
    h.qlog( .INFO, 0, @src(), "Game loop done" );
    h.OnLoopEnd( self ); // Allows for custom deinitialization
  }

  fn update( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Getting inputs..." );
    // This function is used to get input from the user, such as keyboard or mouse input.

    h.OnUpdate( self ); // Allows for custom input handling
  }

  fn tick( self : *engine ) void // TODO : use tick rate instead of frame time
  {
    h.qlog( .TRACE, 0, @src(), "Updating game logic..." );
    // This function is used to update the game logic, such as processing input, updating the game state, etc.

    // Get the delta time and apply the time scale
    const sdt = h.rl.getFrameTime() * self.timeScale;
    h.log( .DEBUG, 0, @src(), "Delta time : {d} seconds", .{ sdt });

    // Check for collisions between all active entities and the following ones

    h.OnTick( self, sdt ); // Allows for custom game logic updates

    self.entityManager.tickActiveEntities( sdt ); // Tick all active entities with the delta time
  }

  fn render( self : *engine ) void
  {
    h.qlog( .TRACE, 0, @src(), "Rendering visuals..." );
    // This function is used to render the game visuals, such as drawing sprites, backgrounds, etc.
    // It uses raylib's drawing functions to draw the game visuals on the screen.

    h.rl.beginDrawing();     // Begin the drawing process
    defer h.rl.endDrawing(); // End the drawing process when the function returns

     // Clear the background with a black color
    h.rl.clearBackground( h.rl.Color.black );

    h.rl.beginMode2D( self.mainCamera ); // World Rendering mode
    {
      h.OnRenderWorld( self ); // Allows for custom rendering of the world

      self.entityManager.renderActiveEntities(); // Render all active entities
    }

    h.rl.endMode2D(); // UI Rendering mode
    {
      h.OnRenderOverlay( self ); // Allows for custom rendering of the overlay
    }
  }

};