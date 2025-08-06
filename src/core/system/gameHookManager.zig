const std = @import( "std" );
const def = @import( "defs" );

// ================================ GAME HOOKS ================================

// This enum defines the tags for each game hook
// These tags are used to identify which hook to call in the gameHooks struct
pub const hookTag = enum( u8 )
{
  // Engine State Hooks

  OnStart = 0, // Called when the engine starts
  OnStop  = 1, // Called when the engine is closed

  OnOpen  = 2, // Called when the engine is launched
  OnClose = 3, // Called when the engine stops

  OnPlay  = 4, // Called when the engine starts playing
  OnPause = 5, // Called when the engine is paused

  // Engine Step Hooks

  OnLoopStart  = 10, // Called at the start of the game loop
  OnLoopEnd    = 11, // Called at the end of the game loop
  OnLoopCycle  = 12, // Called for each iteration of the game loop ( at the start )

  // Update and Tick Hooks

  OnUpdateInputs  = 20, // Called every frame for updates ( at the start )
//OffUpdateInputs = 21, // Called every frame for updates ( at the end )

  OnTickEntities  = 22, // Called every tick for logic updates ( at the start )
  OffTickEntities = 23, // Called every tick for logic updates ( at the end  )

  // Rendering Hooks

  OnRenderBackground  = 30, // Called to render the background ( at the start )
//OffRenderBackground = 31, // Called to render the background ( at the end

  OnRenderWorld  = 32, // Called to render the world ( at the start )
  OffRenderWorld = 33, // Called to render the world ( at the end  )

  OnRenderOverlay  = 34, // Called to render overlays ( at the start )
//OffRenderOverlay = 35, // Called to render overlays ( at the end )

};

// This struct contains a slot for each possible game hook
// Each are function pointers that can be set with `gameHooks.initHooks()`
// NOTE : Using *fn instead of simply module.fn to avoid storing the entire module, which has an unknown type
pub const gameHooks = struct
{
  // Engine State Hooks

  OnStart : ?*const fn ( *def.ngn.engine ) void = null,
  OnStop  : ?*const fn ( *def.ngn.engine ) void = null,

  OnOpen  : ?*const fn ( *def.ngn.engine ) void = null,
  OnClose : ?*const fn ( *def.ngn.engine ) void = null,

  OnPlay  : ?*const fn ( *def.ngn.engine ) void = null,
  OnPause : ?*const fn ( *def.ngn.engine ) void = null,

  // Engine Step Hooks

  OnLoopStart : ?*const fn ( *def.ngn.engine ) void = null,
  OnLoopEnd   : ?*const fn ( *def.ngn.engine ) void = null,
  OnLoopCycle : ?*const fn ( *def.ngn.engine ) void = null,

  // Update and Tick Hooks

  OnUpdateInputs  : ?*const fn ( *def.ngn.engine ) void = null,
//OffUpdateInputs : ?*const fn ( *def.ngn.engine ) void = null,

  OnTickEntities    : ?*const fn ( *def.ngn.engine ) void = null,
  OffTickEntities   : ?*const fn ( *def.ngn.engine ) void = null,

  // Rendering Hooks

  OnRenderBackground  : ?*const fn ( *def.ngn.engine ) void = null,
//OffRenderBackground : ?*const fn ( *def.ngn.engine ) void = null

  OnRenderWorld       : ?*const fn ( *def.ngn.engine ) void = null,
  OffRenderWorld      : ?*const fn ( *def.ngn.engine ) void = null,

  OnRenderOverlay     : ?*const fn ( *def.ngn.engine ) void = null,
//OffRenderOverlay    : ?*const fn ( *def.ngn.engine ) void = null,


  // ================================ GAME HOOKS FUNCTIONS ================================

  // Initializes the game hooks from a given module
  pub fn initHooks( self : *gameHooks, module : anytype ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing game hooks..." );

    if( @typeInfo( module ) != .@"struct" )
    {
      //@compileError( "gameHooks.initHooks() expects a struct ( module ) type" );
      def.log( .ERROR, 0, @src(), "gameHooks.initHooks() expects a struct ( module ) type, got a {} instead", .{ @typeName( module ) });
      return;
    }

    // Engine State hooks

    if( @hasDecl( module, "OnStart" )) self.OnStart = @field( module, "OnStart" );
    if( @hasDecl( module, "OnStop"  )) self.OnStop  = @field( module, "OnStop"  );

    if( @hasDecl( module, "OnOpen"  )) self.OnOpen  = @field( module, "OnOpen"  );
    if( @hasDecl( module, "OnClose" )) self.OnClose = @field( module, "OnClose" );

    if( @hasDecl( module, "OnPlay"  )) self.OnPlay  = @field( module, "OnPlay"  );
    if( @hasDecl( module, "OnPause" )) self.OnPause = @field( module, "OnPause" );

    // Engine Step Hooks

    if( @hasDecl( module, "OnLoopStart" )) self.OnLoopStart = @field( module, "OnLoopStart" );
    if( @hasDecl( module, "OnLoopEnd"   )) self.OnLoopEnd   = @field( module, "OnLoopEnd"   );
    if( @hasDecl( module, "OnLoopCycle" )) self.OnLoopCycle = @field( module, "OnLoopCycle" );

    // Update and Tick Hooks

    if( @hasDecl( module, "OnUpdateInputs"  )) self.OnUpdateInputs  = @field( module, "OnUpdateInputs"  );
  //if( @hasDecl( module, "OffUpdateInputs" )) self.OffUpdateInputs = @field( module, "OffUpdateInputs" );
    if( @hasDecl( module, "OnTickEntities"  )) self.OnTickEntities  = @field( module, "OnTickEntities"  );
    if( @hasDecl( module, "OffTickEntities" )) self.OffTickEntities = @field( module, "OffTickEntities" );

    // Rendering Hooks

    if( @hasDecl( module, "OnRenderBackground"  )) self.OnRenderBackground  = @field( module, "OnRenderBackground"  );
  //if( @hasDecl( module, "OffRenderBackground" )) self.OffRenderBackground = @field( module, "OffRenderBackground" );

    if( @hasDecl( module, "OnRenderWorld"    )) self.OnRenderWorld    = @field( module, "OnRenderWorld"  );
    if( @hasDecl( module, "OffRenderWorld"   )) self.OffRenderWorld   = @field( module, "OffRenderWorld" );

    if( @hasDecl( module, "OnRenderOverlay"  )) self.OnRenderOverlay  = @field( module, "OnRenderOverlay"  );
  //if( @hasDecl( module, "OffRenderOverlay" )) self.OffRenderOverlay = @field( module, "OffRenderOverlay" );

    self.checkHookValidities();

    def.qlog( .INFO, 0, @src(), "Available game hooks initialized" );
  }

  pub fn checkHookValidities( self : *const gameHooks ) void
  {
    def.qlog( .TRACE, 0, @src(), "Checking game hook validity..." );

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

  pub fn tryHook( self : *const gameHooks, tag : hookTag, args : anytype ) void
  {
    const hookFunct = switch( tag )
    {
      // Engine State Hooks

      .OnStart => self.OnStart,
      .OnStop  => self.OnStop,

      .OnOpen  => self.OnOpen,
      .OnClose => self.OnClose,

      .OnPlay  => self.OnPlay,
      .OnPause => self.OnPause,

      // Engine Step Hooks

      .OnLoopStart => self.OnLoopStart,
      .OnLoopEnd   => self.OnLoopEnd,
      .OnLoopCycle => self.OnLoopCycle,

      // Update and Tick Hooks

      .OnUpdateInputs  => self.OnUpdateInputs,
    //.OffUpdateInputs => self.OffUpdateInputs,

      .OnTickEntities  => self.OnTickEntities,
      .OffTickEntities => self.OffTickEntities,

      // Rendering Hooks

      .OnRenderBackground  => self.OnRenderBackground,
    //.OffRenderBackground => self.OffRenderBackground,

      .OnRenderWorld  => self.OnRenderWorld,
      .OffRenderWorld => self.OffRenderWorld,

      .OnRenderOverlay  => self.OnRenderOverlay,
    //.OffRenderOverlay => self.OffRenderOverlay,
    };

    if( hookFunct  )| func |
    {
      // def.log( .DEBUG, 0, @src(), "Calling game hook '{s}'", .{ @tagName( tag ) });
      switch( args.len )
      {
        1 => func( args[ 0 ] ),
        else => @compileError( "Unsupported number of arguments for game hook" ),
      }
      return;
    }
  }
};