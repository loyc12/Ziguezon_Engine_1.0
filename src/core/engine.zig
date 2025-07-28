const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS  = def.vec2{ .x = 2048, .y = 1024 };
pub const DEF_TARGET_FPS   = 120; // Default target FPS for the game

//pub const DEF_TARGET_TPS = 30;  // Default tick rate for the game ( in seconds ) // TODO : USE ME

pub const e_state = enum
{
  OFF,     // The engine is uninitialized
  STARTED, // The engine is initialized, but no window is created yet
  OPENED,  // The window is openned but game is paused ( input and render only )
  PLAYING, // The game is ticking and can be played
};

pub const engine = struct
{
  // Engine Variables
  state     : e_state = .OFF,
  timeScale : f32 = 1.0, // Used to speed up or slow down the game
  sdt       : f32 = 0.0, // Latest scaled delta time ( from last frame ) : == deltaTime * timeScale

  // Raylib Components
  mainCamera : def.ray.Camera2D = undefined,

  // Engine Components
  rng             : def.rng.randomiser      = undefined,
  resourceManager : def.rsm.resourceManager = undefined,
  entityManager   : def.ntm.entityManager   = undefined,

  // ================================ HELPER FUNCTIONS ================================

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

  // ================================ GAME LOOP FUNCTIONS ================================

  pub fn loopLogic( self : *engine ) void
  {
    if( !self.isOpened() )
    {
      def.log( .WARN, 0, @src(), "Cannot start the game loop in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else { def.qlog( .TRACE, 0, @src(), "Starting the game loop..." ); }

    def.tryHook( .OnLoopStart, .{ self });

    // NOTE : this is a blocking loop, it will not return until the game is closed
    // TODO : use a thread to run this loop in the background ?

    while( !def.ray.windowShouldClose() )
    {
      def.tryHook( .OnLoopCycle, .{ self });

      if( comptime def.logger.SHOW_LAPTIME ){ def.qlog( .DEBUG, 0, @src(), "! Looping" ); }
      else { def.logger.logLapTime(); }

      if( self.isOpened() )
      {
        self.updateInputs();   // Inputs and Global Flags
        self.tickEntities();   // Logic and Physics
        self.renderGraphics(); // Visuals and UI
      }
    }
    def.qlog( .TRACE, 0, @src(), "Stopping the game loop..." );

    def.tryHook( .OnLoopEnd, .{ self });

    def.qlog( .INFO, 0, @src(), "Game loop stopped" );
  }

  // ================ LOOP EVENTS ================

  fn updateInputs( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Getting inputs..." );
    // This function is used to get input from the user, such as keyboard or mouse input.

    def.tryHook( .OnUpdateInputs, .{ self });
    {
      // TODO : update global inputs here
    }
    //def.tryHook( .OffUpdateInputs, .{ self });
  }

  fn tickEntities( self : *engine ) void           // TODO : use tick rate instead of frame time
  {
    if( !self.isPlaying() ){ return; } // skip this function if the game is paused

    def.qlog( .TRACE, 0, @src(), "Updating game logic..." );

    self.sdt = def.ray.getFrameTime() * self.timeScale;

    def.tryHook( .OnTickEntities, .{ self });
    {
    //self.entityManager.collideActiveEntities( self.sdt );
      self.entityManager.tickActiveEntities( self.sdt );
    }
    def.tryHook( .OffTickEntities, .{ self });
  }

  fn renderGraphics( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Rendering visuals..." );

    def.ray.beginDrawing();
    defer def.ray.endDrawing();

    // Background Rendering mode
    def.tryHook( .OnRenderBackground, .{ self });
    {
      // TODO : Render the backgrounds here
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

  // ================================ ENGINE STATE FUNCTIONS ================================

  pub fn changeState( self : *engine, targetState : e_state ) void
  {


    if( targetState == self.state )
    {
      def.log( .WARN, 0, @src(), "State is already {s}, no change needed", .{ @tagName( self.state ) });
      return;
    }
    else { def.qlog( .TRACE, 0, @src(), "Changing state" ); }

    // If the target state is higher than the current state,
    if( @intFromEnum( targetState ) > @intFromEnum( self.state ) )
    {
      def.log( .INFO, 0, @src(), "Increasing state from {s} to {s}", .{ @tagName( self.state ), @tagName( targetState )});

      switch( self.state )
      {
        .OFF     => { self.start(); },
        .STARTED => { self.open();  },
        .OPENED  => { self.play();  },

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
        .PLAYING => { self.pause(); },
        .OPENED  => { self.close(); },
        .STARTED => { self.stop();  },

        else =>
        {
          def.qlog( .ERROR, 0, @src(), "How did you get here ???");
          return;
        },
      }
    }
    // Recursively calling changeState to pass through all intermediate state changes ( if needed )
    // TODO : use "switch continue" instead of recursion ?
    if( self.state != targetState ){ self.changeState( targetState ); }
  }

    // ================ STATE CHECKERS ================

  pub fn isStarted( self : *const engine ) bool
  {
    return ( @intFromEnum( self.state ) >= @intFromEnum( e_state.STARTED ));
  }
  pub fn isOpened( self : *const engine ) bool
  {
    return ( @intFromEnum( self.state ) >= @intFromEnum( e_state.OPENED ));
  }
  pub fn isPlaying( self : *const engine ) bool
  {
    return ( @intFromEnum( self.state ) >= @intFromEnum( e_state.PLAYING ));
  }

  // ================ START & STOP ================

  fn start( self : *engine ) void
  {
    if( self.state != .OFF )
    {
      def.log( .WARN, 0, @src(), "Cannot start the engine in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else { def.qlog( .TRACE, 0, @src(), "Starting the engine..." ); }

    // Initialize relevant raylib components
    {
      def.ray.initAudioDevice();

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
    }
    // Initialize relevant engine components
    {
      self.rng.randInit();
      self.entityManager.init(   def.alloc );
      self.resourceManager.init( def.alloc );
    }
    def.tryHook( .OnStart, .{ self });

    def.qlog( .INFO, 0, @src(), "$ Hello, world !\n" );
    self.state = .STARTED;
  }

  fn stop( self : *engine ) void
  {
    if( self.state == .OFF )
    {
      def.log( .WARN, 0, @src(), "Cannot stop the engine in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else{ def.qlog( .TRACE, 0, @src(), "Stoping the engine..." ); }

    def.tryHook( .OnStop, .{ self });

    // Deinitialize relevant engine components
    {
      self.resourceManager.deinit();
      self.resourceManager = undefined;

      self.entityManager.deinit();
      self.entityManager = undefined;
    }
    // Deinitialize relevant raylib components
    {
      self.mainCamera = undefined;

      if( def.ray.isAudioDeviceReady() )
      {
        def.qlog( .INFO, 0, @src(), "# Closing the audio device..." );
        def.ray.closeAudioDevice();
      }
    }
    self.state = .OFF;
    def.qlog( .INFO, 0, @src(), "# Goodbye, cruel world...\n" );
  }

  // ================ OPEN & CLOSE ================

  fn open( self : *engine ) void
  {
    if( self.state != .STARTED )
    {
      def.log( .WARN, 0, @src(), "Cannot open the game in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else{ def.qlog( .TRACE, 0, @src(), "Launching the game..." ); }

    // Initialize relevant engine components
    {}
    // Initialize relevant raylib components
    {
      def.ray.setTargetFPS( DEF_TARGET_FPS );
      def.ray.initWindow( DEF_SCREEN_DIMS.x, DEF_SCREEN_DIMS.y, "Ziguezon Engine - Game Window" ); // Opens the window
    }
    def.tryHook( .OnOpen, .{ self });

    // TODO : Start the game loop in a second thread here ?

    self.state = .OPENED;
    def.log( .DEBUG, 0, @src(), "$ Window initialized with size {d}x{d}\n", .{ def.ray.getScreenWidth(), def.ray.getScreenHeight() });
  }

  fn close( self : *engine ) void
  {
    if( self.state != .OPENED )
    {
      def.log( .WARN, 0, @src(), "Cannot close the game in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else{ def.qlog( .TRACE, 0, @src(), "Stopping the game..." ); }

    def.tryHook( .OnClose, .{ self });

    // Deinitialize relevant raylib components
    {
      if( def.ray.isWindowReady() )
      {
        def.qlog( .INFO, 0, @src(), "# Closing the window..." );
        def.ray.closeWindow();
      }
    }
    // Deinitialize relevant engine components
    {}

    self.state = .STARTED;
    def.qlog( .INFO, 0, @src(), "# Cya !\n" );
  }

  // ================ PLAY & PAUSE ================

  fn play( self : *engine ) void
  {
    if( self.state != .OPENED )
    {
      def.log( .WARN, 0, @src(), "Cannot play the game in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else{ def.qlog( .TRACE, 0, @src(), "Resuming the game..." ); }

    def.tryHook( .OnPlay, .{ self });
    self.state = .PLAYING;
  }


  fn pause( self : *engine ) void
  {
    if( self.state != .PLAYING )
    {
      def.log( .WARN, 0, @src(), "Cannot pause the game in state {s}", .{ @tagName( self.state ) });
      return;
    }
    else{ def.qlog( .TRACE, 0, @src(), "Pausing the game..." ); }

    def.tryHook( .OnPause, .{ self });
    self.state = .OPENED;
  }

  pub fn togglePause( self : *engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Toggling pause..." );
    switch( self.state )
    {
      .OPENED  => { self.play();  },
      .PLAYING => { self.pause(); },
      else =>
      {
        def.log( .WARN, 0, @src(), "Cannot toggle pause in current state ({s})", .{ @tagName( self.state ) });
        return;
      },
    }
  }
};