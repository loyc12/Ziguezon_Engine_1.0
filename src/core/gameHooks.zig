const std = @import( "std" );
const def = @import( "defs" );

// ================================ GAME HOOKS ================================

// This enum defines the tags for each game hook
// These tags are used to identify which hook to call in the gameHooks struct
pub const hookTag = enum( u8 )
{
  // Engine state hooks
  OnStart  = 0, // Called when the engine starts
  OnLaunch = 1, // Called when the engine is launched
  OnPlay   = 2, // Called when the engine starts playing

  OnPause  = 3, // Called when the engine is paused
  OnStop   = 4, // Called when the engine stops
  OnClose  = 5, // Called when the engine is closed

  // Engine step hooks
  OnLoopStart  = 10, // Called at the start of the game loop
  OnLoopEnd    = 11, // Called at the end of the game loop
  OnLoopIter   = 12, // Called for each iteration of the game loop ( at the start )
  OffLoopIter  = 13, // Called for each iteration of the game loop ( at the end )

  OnUpdateStep   = 20, // Called every frame for updates ( at the start )
  OffUpdateStep  = 21, // Called every frame for updates ( at the end )
  OnTickStep     = 22, // Called every tick for logic updates ( at the start )
  OffTickStep    = 23, // Called every tick for logic updates ( at the end  )

  OnRenderWorld    = 24, // Called to render the world ( at the start )
  OffRenderWorld   = 25, // Called to render the world ( at the end  )
  OnRenderOverlay  = 26, // Called to render overlays ( at the start )
  OffRenderOverlay = 27, // Called to render overlays ( at the end )

};

// This struct contains a slot for each possible game hook
// Each are function pointers that can be set with `gameHooks.initHooks()`
// NOTE : Using *fn instead of simply module.fn to avoid storing the entire module, which has an unknown type
pub const gameHooks = struct
{
  // Engine state hooks
  OnStart  : ?*const fn ( *def.eng.engine ) void = null,
  OnLaunch : ?*const fn ( *def.eng.engine ) void = null,
  OnPlay   : ?*const fn ( *def.eng.engine ) void = null,

  OnPause  : ?*const fn ( *def.eng.engine ) void = null,
  OnStop   : ?*const fn ( *def.eng.engine ) void = null,
  OnClose  : ?*const fn ( *def.eng.engine ) void = null,

  // Engine step hooks
  OnLoopStart : ?*const fn ( *def.eng.engine ) void = null,
  OnLoopEnd   : ?*const fn ( *def.eng.engine ) void = null,
  OnLoopIter  : ?*const fn ( *def.eng.engine ) void = null,
  OffLoopIter : ?*const fn ( *def.eng.engine ) void = null,

  OnUpdateStep  : ?*const fn ( *def.eng.engine ) void = null,
  OffUpdateStep : ?*const fn ( *def.eng.engine ) void = null,
  OnTickStep    : ?*const fn ( *def.eng.engine ) void = null,
  OffTickStep   : ?*const fn ( *def.eng.engine ) void = null,

  OnRenderWorld    : ?*const fn ( *def.eng.engine ) void = null,
  OffRenderWorld   : ?*const fn ( *def.eng.engine ) void = null,
  OnRenderOverlay  : ?*const fn ( *def.eng.engine ) void = null,
  OffRenderOverlay : ?*const fn ( *def.eng.engine ) void = null,

  // Initializes the game hooks from a given module
  pub fn initHooks( self : *gameHooks, module : anytype ) void
  {
    if( @typeInfo( module ) != .@"struct" )
    {
      //@compileError( "gameHooks.initHooks() expects a struct ( module ) type" );
      def.log( .ERROR, 0, @src(), "gameHooks.initHooks() expects a struct ( module ) type, got {s}", .{ @typeName( module ) });
      return;
    }

    // Attempt to set each hook individually
    // Engine state hooks
    if( @hasDecl( module, "OnStart"  )) self.OnStart  = @field( module, "OnStart"  );
    if( @hasDecl( module, "OnLaunch" )) self.OnLaunch = @field( module, "OnLaunch" );
    if( @hasDecl( module, "OnPlay"   )) self.OnPlay   = @field( module, "OnPlay"   );
    if( @hasDecl( module, "OnPause"  )) self.OnPause  = @field( module, "OnPause"  );
    if( @hasDecl( module, "OnStop"   )) self.OnStop   = @field( module, "OnStop"   );
    if( @hasDecl( module, "OnClose"  )) self.OnClose  = @field( module, "OnClose"  );

    // Engine step hooks
    if( @hasDecl( module, "OnLoopStart" )) self.OnLoopStart = @field( module, "OnLoopStart" );
    if( @hasDecl( module, "OnLoopEnd"   )) self.OnLoopEnd   = @field( module, "OnLoopEnd"   );
    if( @hasDecl( module, "OnLoopIter"  )) self.OnLoopIter  = @field( module, "OnLoopIter"  );
    if( @hasDecl( module, "OffLoopIter" )) self.OffLoopIter = @field( module, "OffLoopIter" );

    if( @hasDecl( module, "OnUpdateStep"  )) self.OnUpdateStep  = @field( module, "OnUpdateStep"  );
    if( @hasDecl( module, "OffUpdateStep" )) self.OffUpdateStep = @field( module, "OffUpdateStep" );
    if( @hasDecl( module, "OnTickStep"    )) self.OnTickStep    = @field( module, "OnTickStep"    );
    if( @hasDecl( module, "OffTickStep"   )) self.OffTickStep   = @field( module, "OffTickStep"   );

    if( @hasDecl( module, "OnRenderWorld"    )) self.OnRenderWorld    = @field( module, "OnRenderWorld"    );
    if( @hasDecl( module, "OffRenderWorld"   )) self.OffRenderWorld   = @field( module, "OffRenderWorld"   );
    if( @hasDecl( module, "OnRenderOverlay"  )) self.OnRenderOverlay  = @field( module, "OnRenderOverlay"  );
    if( @hasDecl( module, "OffRenderOverlay" )) self.OffRenderOverlay = @field( module, "OffRenderOverlay" );

    self.logHookValidities();
  }

  // Logs the validity of each game hook
  pub fn logHookValidities( self : *const gameHooks ) void
  {
    // Loop through each field in the gameHooks struct
    // and log whether it is assigned or not
    inline for ( @typeInfo( gameHooks ).@"struct".fields )| field |
    {
      const fieldName = field.name;
      const fieldPtr = @field( self, fieldName );

      if( fieldPtr )| func |
      {
        _ = func;
        def.log( .DEBUG, 0, @src(), "Game hook for '{s}' is set", .{ fieldName });
      }
      else
      {
        def.log( .DEBUG, 0, @src(), "! Game hook for '{s}' is NOT set", .{ fieldName });
      }
    }
  }

  // Attempts to call a game hook with the given tag and arguments
  pub fn tryHook( self : *const gameHooks, tag : hookTag, args : anytype ) void
  {
    // Check if the hook exists
    const optFunc = switch( tag )
    {
      // Engine state hooks
      .OnStart  => self.OnStart,
      .OnLaunch => self.OnLaunch,
      .OnPlay   => self.OnPlay,
      .OnPause  => self.OnPause,
      .OnStop   => self.OnStop,
      .OnClose  => self.OnClose,

      // Engine step hooks
      .OnLoopStart => self.OnLoopStart,
      .OnLoopEnd   => self.OnLoopEnd,
      .OnLoopIter  => self.OnLoopIter,
      .OffLoopIter => self.OffLoopIter,

      .OnUpdateStep  => self.OnUpdateStep,
      .OffUpdateStep => self.OffUpdateStep,
      .OnTickStep    => self.OnTickStep,
      .OffTickStep   => self.OffTickStep,

      .OnRenderWorld    => self.OnRenderWorld,
      .OffRenderWorld   => self.OffRenderWorld,
      .OnRenderOverlay  => self.OnRenderOverlay,
      .OffRenderOverlay => self.OffRenderOverlay,
    };

    // Call the function if it exists
    if( optFunc )| func |
    {
      // def.log( .DEBUG, 0, @src(), "Calling game hook '{s}'", .{ @tagName( tag ) });
      switch( args.len )
      {
        1 => func( args[ 0 ] ),
        else => @compileError( "Unsupported number of arguments for game hook" ),
      }
      return;
    }
    //else { def.log( .WARN, 0, @src(), "Game hook '{s}' is not set", .{ @tagName( tag ) }); }
  }
};