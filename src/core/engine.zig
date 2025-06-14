const std = @import( "std" );
const h   = @import( "../headers.zig" );

// ================================ DEFINITIONS ================================

pub var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

const e_state = enum
{
  CLOSED, // The engine is closed and cannot be used
  CLOSING,

  STARTING,
  STARTED, // The engine is started and ready to be used
  STOPPING,

  LAUNCHING,
  LAUNCHED, // The engine is launched and running
  PAUSING,

  RESUMING,
  PAUSED, // The engine is paused and can be resumed

  SAVING, // The engine is saving the game state
};

// ================================ CORE FUNCTIONS ================================

pub fn isAccessibleState( state : e_state ) bool { return state == .CLOSED or state == .STARTED or state == .LAUNCHED or state == .PAUSED; }

pub const engine = struct
{
  state : e_state = .CLOSED, // The current state of the engine

  // ================================ STATE MANAGEMENT ================================

  pub fn changeState( self : *engine, targetState : e_state ) void
  {
    if( !isAccessibleState( targetState ) or !isAccessibleState( self.state ))
    {
      h.log( .ERROR, 0, @src(), "Cannot change state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState ) });
      return;
    }

    if( targetState == self.state )
    {
      h.log( .INFO, 0, @src(), "State is already {s}, no change needed", .{ @tagName( self.state ) });
      return;
    }

    if( @intFromEnum( targetState ) < @intFromEnum( self.state ) )
    {
      h.log( .INFO, 0, @src(), "Decreasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .STARTED =>
        {
          h.qlog( .INFO, 0, @src(), "Closing the engine..." );
          self.state = .STOPPING;

          // Deinitialize all subsystems
          self.deinit();
        },

        .LAUNCHED =>
        {
          h.qlog( .INFO, 0, @src(), "Stopping the game loop..." );
          self.state = .STOPPING;

          // Stop the game loop
          self.state = .STARTED;
          // TODO : Save the game state to a file
        },

        .PAUSED =>
        {
          h.qlog( .INFO, 0, @src(), "Resuming the game loop..." );
          self.state = .RESUMING;

          // Resume the game loop and restore the game state
          self.state = .STARTED;
        },

        else =>
        {
          h.log( .ERROR, 0, @src(), "How did you get here ???", .{});
          return;
        },
      }
    }
    else
    {
      h.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .CLOSED =>
        {
          h.qlog( .INFO, 0, @src(), "Starting the engine..." );
          self.state = .STARTING;

          // Initialize all subsystems
          self.init();
        },

        .STARTED =>
        {
          h.qlog( .INFO, 0, @src(), "Launching the game loop..." );
          self.state = .LAUNCHING;

          // Start the game loop and load the game state
          self.state = .LAUNCHED;
          // TODO : Load the game state from a file or database
        },

        .LAUNCHED =>
        {
          h.qlog( .INFO, 0, @src(), "Pausing the game loop..." );
          self.state = .PAUSING;

          // Pause the game loop temporarily
          self.state = .PAUSED;
        },

        else =>
        {
          h.log( .ERROR, 0, @src(), "How did you get here ???", .{});
          return;
        },
      }
    }

    // Recursively calling changeState to run all intermediate state change operations
    if( self.state != targetState ){ self.changeState( targetState ); }
  }

  fn init( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Initializing the engine..." );

    h.initAll();
    self.state = .STARTED;

    h.qlog( .INFO, 0, @src(), "Hello, world !" );
  }

  fn deinit( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Deinitializing the engine..." );

    h.deinitAll();
    self.state = .CLOSED;

    h.qlog( .INFO, 0, @src(), "Goodbye..." );
  }

  //pub fn saveAll( self: *engine ) void
  //{
  //  const tmpState = self.state; // Store the current state temporarily
  //  self.state = .SAVING;
  //
  //  // Save the game state to a file or database
  //  h.qlog( .INFO, 0, @src(), "Saving game state..." );
  //  // TODO : Implement the actual saving logic here
  //
  //  self.state = tmpState;
  //}

  // ================================ GAME LOOP ================================

  pub fn runGameLoop( self : *engine ) void
  {
    h.qlog( .INFO, 0, @src(), "Starting the game loop..." );

    var i: i32 = 0;
    while( i < 100 )
    {
      h.log( .DEBUG, 0, @src(), "Starting iteration {d} of the loop", .{ i } );
      i += 1;

      if( @intFromEnum( self.state ) >= @intFromEnum( e_state.LAUNCHED ) )
      {
        // ================ INPUT LOGIC ================
        self.getInputs();

        // ================ GAME LOGIC ================
        if( self.state == .LAUNCHED )
        {
          self.updateLogic();
        }

        // ================ GRAPHICS LOGIC ================
        self.renderGraphics();
      }
    }
  }

  fn getInputs( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Getting inputs..." );

    // This function is used to get input from the user, such as keyboard or mouse input.
    // For now, it does nothing.

    _ = self; // DEBUG
  }

  fn updateLogic( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Updating game logic..." );
    // This function is used to update the game logic, such as processing input, updating the game state, etc.
    // For now, it does nothing.

    _ = self; // DEBUG
  }

  fn renderGraphics( self : *engine ) void
  {
    h.qlog( .DEBUG, 0, @src(), "Rendering graphics..." );
    // This function is used to render the graphics, such as drawing the game, updating the screen, etc.
    // For now, it does nothing.

    _ = self; // DEBUG
  }

};