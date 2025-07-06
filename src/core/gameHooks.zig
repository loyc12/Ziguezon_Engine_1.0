const std = @import( "std" );
const h   = @import( "defs" );

pub const hookTag = enum( u8 )
{
  OnLoopStart     = 0,  // Called at the start of the game loop
  OnLoopIter      = 1,  // Called for each iteration of the game loop
  OnLoopEnd       = 2,  // Called at the end of the game loop

  OnUpdate        = 3,  // Called every frame for updates
  OnTick          = 4,  // Called every tick for logic updates
  OnRenderWorld   = 5,  // Called to render the world
  OnRenderOverlay = 6,  // Called to render overlays

  OnStart         = 7,  // Called when the engine starts
  OnLaunch        = 8,  // Called when the engine is launched
  OnPlay          = 9,  // Called when the engine starts playing
  OnPause         = 10, // Called when the engine is paused
  OnStop          = 11, // Called when the engine stops
  OnClose         = 12, // Called when the engine is closed
};

pub const gameHooks = struct
{
  // This struct contains a slot for each possible game hook
  // Each are function pointers that can be set with `engine.setHook()`

  // Engine step hooks
  OnLoopStart : ?*const fn ( *h.eng.engine ) void = null,
  OnLoopIter  : ?*const fn ( *h.eng.engine ) void = null,
  OnLoopEnd   : ?*const fn ( *h.eng.engine ) void = null,

  OnUpdate : ?*const fn ( *h.eng.engine ) void = null,
  OnTick   : ?*const fn ( *h.eng.engine ) void = null,

  OnRenderWorld   : ?*const fn ( *h.eng.engine ) void = null,
  OnRenderOverlay : ?*const fn ( *h.eng.engine ) void = null,

  // Engine state hooks
  OnStart  : ?*const fn ( *h.eng.engine ) void = null,
  OnLaunch : ?*const fn ( *h.eng.engine ) void = null,
  OnPlay   : ?*const fn ( *h.eng.engine ) void = null,
  OnPause  : ?*const fn ( *h.eng.engine ) void = null,
  OnStop   : ?*const fn ( *h.eng.engine ) void = null,
  OnClose  : ?*const fn ( *h.eng.engine ) void = null,

  pub fn initHooks( self : *gameHooks, module : anytype ) void
  {
    if( @typeInfo( module ) != .@"struct" )
    {
      //@compileError( "gameHooks.initHooks() expects a struct ( module ) type" );
      h.log( .ERROR, 0, @src(), "gameHooks.initHooks() expects a struct ( module ) type, got {s}", .{ @typeName( module ) });
      return;
    }

    // Attempt to set each hook individually
    if( @hasDecl( module, "OnLoopStart"     )) self.OnLoopStart     = @field( module, "OnLoopStart"     );
    if( @hasDecl( module, "OnLoopIter"      )) self.OnLoopIter      = @field( module, "OnLoopIter"      );
    if( @hasDecl( module, "OnLoopEnd"       )) self.OnLoopEnd       = @field( module, "OnLoopEnd"       );

    if( @hasDecl( module, "OnUpdate"        )) self.OnUpdate        = @field( module, "OnUpdate"        );
    if( @hasDecl( module, "OnTick"          )) self.OnTick          = @field( module, "OnTick"          );
    if( @hasDecl( module, "OnRenderWorld"   )) self.OnRenderWorld   = @field( module, "OnRenderWorld"   );
    if( @hasDecl( module, "OnRenderOverlay" )) self.OnRenderOverlay = @field( module, "OnRenderOverlay" );

    if( @hasDecl( module, "OnStart"         )) self.OnStart         = @field( module, "OnStart"         );
    if( @hasDecl( module, "OnLaunch"        )) self.OnLaunch        = @field( module, "OnLaunch"        );
    if( @hasDecl( module, "OnPlay"          )) self.OnPlay          = @field( module, "OnPlay"          );
    if( @hasDecl( module, "OnPause"         )) self.OnPause         = @field( module, "OnPause"         );
    if( @hasDecl( module, "OnStop"          )) self.OnStop          = @field( module, "OnStop"          );
    if( @hasDecl( module, "OnClose"         )) self.OnClose         = @field( module, "OnClose"         );

    self.logHookValidities();
  }

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
        h.log( .DEBUG, 0, @src(), "Game hook for '{s}' is set", .{ fieldName });
      }
      else
      {
        h.log( .DEBUG, 0, @src(), "! Game hook for '{s}' is NOT set", .{ fieldName });
      }
    }
  }

  pub fn tryHook( self : *const gameHooks, tag : hookTag, args : anytype ) void
  {
    // Check if the hook exists
    const optFunc = switch( tag )
    {
      .OnLoopStart     => self.OnLoopStart,
      .OnLoopIter      => self.OnLoopIter,
      .OnLoopEnd       => self.OnLoopEnd,

      .OnUpdate        => self.OnUpdate,
      .OnTick          => self.OnTick,
      .OnRenderWorld   => self.OnRenderWorld,
      .OnRenderOverlay => self.OnRenderOverlay,

      .OnStart         => self.OnStart,
      .OnLaunch        => self.OnLaunch,
      .OnPlay          => self.OnPlay,
      .OnPause         => self.OnPause,
      .OnStop          => self.OnStop,
      .OnClose         => self.OnClose,
    };

    // Call the function if it exists
    if( optFunc )| func |
    {
      h.log( .DEBUG, 0, @src(), "Calling game hook '{s}'", .{ @tagName( tag ) });

      switch( args.len )
      {
        1 => func( args[ 0 ] ),
        else => @compileError( "Unsupported number of arguments for game hook" ),
      }
      return;
    }
    else { h.log( .WARN, 0, @src(), "Game hook '{s}' is not set", .{ @tagName( tag ) }); }
  }
};