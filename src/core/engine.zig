const std = @import( "std" );
const h   = @import( "../headers.zig" );

// ================================ DEFINITIONS ================================

pub var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

const e_state = enum // These values represent the different states of the engine.
{
  CLOSED, // The engine is closed and cannot be used
  //CLOSING,

  //STARTING,
  STARTED, // The engine is started and ready to be used
  //STOPPING,

  //LAUNCHING,
  LAUNCHED, // The engine is launched but paused ( not ticking, only rendering and geting inputs )
  //PAUSING,

  //RESUMING,
  PLAYING, // The engine is playing and running the full game loop
};

// ================================ CORE FUNCTIONS ================================

//pub fn isAccessibleState( state : e_state ) bool { return state == .CLOSED or state == .STARTED or state == .LAUNCHED or state == .TICKING; }
pub const engine = struct
{
  state : e_state = .CLOSED, // The current state of the engine
  timeScale : f32 = 1.0, // The time scale of the engine ( used to speed up or slow down the game )

  // ================================ STATE MANAGEMENT ================================

  pub fn changeState( self : *engine, targetState : e_state ) void
  {
    //if( !isAccessibleState( targetState ) or !isAccessibleState( self.state ))
    //{
    //  h.log( .ERROR, 0, @src(), "Cannot change state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState ) });
    //  return;
    //}

    if( targetState == self.state )
    {
      h.log( .INFO, 0, @src(), "State is already {s}, no change needed", .{ @tagName( self.state ) });
      return;
    }

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
    else
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

    // Recursively calling changeState to run all intermediate state change operations
    if( self.state != targetState ){ self.changeState( targetState ); }
  }

  fn start( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Starting the engine..." );

    // Initialize the engine here (e.g. load resources, initialize subsystems, etc.)

    self.state = .STARTED;
  }

  fn launch( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Launching the game..." );

    // Prepare the engine for gameplay (e.g. load game data, initialize game state, etc.)

    h.rl.setTargetFPS( 60 ); // Set the target FPS for the game
    h.rl.initWindow( 2048, 1024, "Ziguezon Engine - Game Window" ); // Initialize the game window

    self.state = .LAUNCHED;
  }

  fn play( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Resuming the game..." );

    // Start the game loop or resume gameplay

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
        h.log( .WARN, 0, @src(), "Cannot toggle pause in current state ( {s} )", .{ @tagName( self.state ) });
        return;
      },
    }
  }

  fn pause( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Pausing the game..." );

    // Pause the game logic (e.g. stop updating game state, freeze animations, etc.)

    self.state = .LAUNCHED;
  }

  fn stop( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Stopping the game..." );

    self.state = .STARTED;
    h.qlog( .INFO, 0, @src(), "Hello, world !" );
  }

  fn close( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Closing the engine..." );

    self.state = .CLOSED;
    h.qlog( .INFO, 0, @src(), "Goodbye..." );
  }

  // ================================ GAME LOOP ================================

  pub fn loopLogic( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Starting the game loop..." );

    while( !h.rl.windowShouldClose() )
    {
      h.qlog( .DEBUG, 0, @src(), "! Looping" );

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
  }

  fn update( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Getting inputs..." );
    // This function is used to get input from the user, such as keyboard or mouse input.
    // For now, it does nothing.

    // Toggle pause if the P key is pressed
    if( h.rl.isKeyPressed( h.rl.KeyboardKey.p )){ self.togglePause(); }
  }

  fn tick( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Updating game logic..." );
    // This function is used to update the game logic, such as processing input, updating the game state, etc.
    // For now, it does nothing.

    _ = self; // DEBUG
  }

  fn render( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Rendering visuals..." );
    // This function is used to render the game visuals, such as drawing sprites, backgrounds, etc.
    // It uses raylib's drawing functions to draw the game visuals on the screen.

    h.rl.beginDrawing();     // Begin the drawing process
    defer h.rl.endDrawing(); // End the drawing process

    h.rl.clearBackground( h.rl.Color.black ); // Clear the background with a black color

    _ = self; // DEBUG
  }

};