const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ GAME HOOKS ================================

// This enum defines the tags for each game hook
// These tags are used to identify which hook to call in the GameHooks struct
pub const HookTag = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;


  // Engine State Hooks

  OnGameStart = 0, // Called when the engine starts
  OnGameStop  = 1, // Called when the engine is closed

  OnGameOpen  = 2, // Called when the engine is launched
  OnGameClose = 3, // Called when the engine stops

  OnGameResume  = 4, // Called when the engine starts playing
  OnGamePause = 5, // Called when the engine is paused


  // Engine Step Hooks

  OnLoopStart  = 10, // Called at the start of the game loop
  OnLoopEnd    = 11, // Called at the end of the game loop
  OnLoopCycle  = 12, // Called for each iteration of the game loop ( at the start )


  // Update and Tick Hooks

  OnFrameUpdate   = 20, // Called every frame for updates ( at the start )
//OffFrameUpdate  = 21, // Called every frame for updates ( at the end )

  OnTickUpdate      = 22, // Called every tick for logic updates ( at the start )
  OffTickUpdate     = 23, // Called every tick for logic updates ( at the end )


  // Rendering Hooks

  OnRenderBckgrnd  = 30, // Called to render the background ( at the start )

  OnRenderWorld    = 32, // Called to render the world ( at the start )
  OffRenderWorld   = 33, // Called to render the world ( at the end )

  OnRenderOverlay  = 34, // Called to render overlays ( at the start )
//OffRenderOverlay = 35, // Called to render overlays ( at the end )

};


pub const HookCntx = *eng.Engine; // Hook Context ( Engine ptr )

// Hook functions mandatory format
pub const HookFunc = *const fn( cntx : HookCntx ) void;


// This struct contains a slot for each possible game hook
// Each are function pointers that can be set with `GameHooks.loadHooks( function definition module )`
pub const GameHooks = struct
{
  // Engine State Hooks

  OnGameStart  : ?HookFunc = null,
  OnGameStop   : ?HookFunc = null,

  OnGameOpen   : ?HookFunc = null,
  OnGameClose  : ?HookFunc = null,

  OnGameResume : ?HookFunc = null,
  OnGamePause  : ?HookFunc = null,

  // Engine Step Hooks

  OnLoopStart  : ?HookFunc = null,
  OnLoopEnd    : ?HookFunc = null,
  OnLoopCycle  : ?HookFunc = null,

  OnFrameUpdate   : ?HookFunc = null,
//OffFrameUpdate  : ?HookFunc = null,

  OnTickUpdate    : ?HookFunc = null,
  OffTickUpdate   : ?HookFunc = null,

  OnRenderBckgrnd : ?HookFunc = null,
  OnRenderOverlay : ?HookFunc = null,

  OnRenderWorld   : ?HookFunc = null,
  OffRenderWorld  : ?HookFunc = null,


  // ================================ GAME HOOKS FUNCTIONS ================================

  pub fn loadHooks( self : *GameHooks, module : anytype ) void
  {
    utl.qlog( .TRACE, 0, @src(), "Initializing game hooks..." );

    if( @typeInfo( module ) != .@"struct" )
    {
      utl.log( .ERROR, 0, @src(), "GameHooks.loadHooks() expects a struct ( module ) type, got a {} instead", .{ @typeName( module ) });
      return;
    }

    // Engine State hooks
    if( @hasDecl( module, "OnGameStart"  )) self.OnGameStart  = @field( module, "OnGameStart"  );
    if( @hasDecl( module, "OnGameStop"   )) self.OnGameStop   = @field( module, "OnGameStop"   );

    if( @hasDecl( module, "OnGameOpen"   )) self.OnGameOpen   = @field( module, "OnGameOpen"   );
    if( @hasDecl( module, "OnGameClose"  )) self.OnGameClose  = @field( module, "OnGameClose"  );

    if( @hasDecl( module, "OnGameResume" )) self.OnGameResume = @field( module, "OnGameResume" );
    if( @hasDecl( module, "OnGamePause"  )) self.OnGamePause  = @field( module, "OnGamePause"  );

    // Engine Step Hooks
    if( @hasDecl( module, "OnLoopStart"  )) self.OnLoopStart  = @field( module, "OnLoopStart"  );
    if( @hasDecl( module, "OnLoopEnd"    )) self.OnLoopEnd    = @field( module, "OnLoopEnd"    );
    if( @hasDecl( module, "OnLoopCycle"  )) self.OnLoopCycle  = @field( module, "OnLoopCycle"  );

    // Update and Tick Hooks
    if( @hasDecl( module, "OnFrameUpdate"  )) self.OnFrameUpdate  = @field( module, "OnFrameUpdate"  );
  //if( @hasDecl( module, "OffFrameUpdate" )) self.OffFrameUpdate = @field( module, "OffFrameUpdate" );
    if( @hasDecl( module, "OnTickUpdate"   )) self.OnTickUpdate   = @field( module, "OnTickUpdate"   );
    if( @hasDecl( module, "OffTickUpdate"  )) self.OffTickUpdate  = @field( module, "OffTickUpdate"  );

    // Rendering Hooks
    if( @hasDecl( module, "OnRenderBckgrnd" )) self.OnRenderBckgrnd = @field( module, "OnRenderBckgrnd" );
    if( @hasDecl( module, "OnRenderOverlay" )) self.OnRenderOverlay = @field( module, "OnRenderOverlay" );

    if( @hasDecl( module, "OnRenderWorld"   )) self.OnRenderWorld   = @field( module, "OnRenderWorld"   );
    if( @hasDecl( module, "OffRenderWorld"  )) self.OffRenderWorld  = @field( module, "OffRenderWorld"  );


    self.checkHookValidities();
    utl.qlog( .CONT, 0, @src(), "" );
    utl.qlog( .INFO, 0, @src(), "$ Available game hooks initialized\n" );
  }


  pub fn checkHookValidities( self : *const GameHooks ) void
  {
    utl.qlog( .DEBUG, 0, @src(), "# Checking game hook validity...\n" );

    inline for ( @typeInfo( GameHooks ).@"struct".fields )| field |
    {
      const fieldName = field.name;
      const fieldPtr = @field( self, fieldName );

      if( fieldPtr )| func |
      {
        _ = func;
        utl.log( .CONT, 0, @src(), "$ '{s}'\tGame hook WAS set", .{ fieldName });
      }
      else
      {
        utl.log( .CONT, 0, @src(), "@ '{s}'\tGame hook NOT set", .{ fieldName });
      }
    }
  }

  pub fn tryHook( self : *const GameHooks, tag : HookTag, cntx : HookCntx ) void
  {
    const hookFunct = switch( tag )
    {
    // Engine State Hooks
      .OnGameStart => self.OnGameStart,
      .OnGameStop  => self.OnGameStop,

      .OnGameOpen  => self.OnGameOpen,
      .OnGameClose => self.OnGameClose,

      .OnGameResume  => self.OnGameResume,
      .OnGamePause => self.OnGamePause,

    // Engine Step Hooks
      .OnLoopStart => self.OnLoopStart,
      .OnLoopEnd   => self.OnLoopEnd,
      .OnLoopCycle => self.OnLoopCycle,

    // Update and Tick Hooks
      .OnFrameUpdate  => self.OnFrameUpdate,
    //.OffFrameUpdate => self.OffFrameUpdate,

      .OnTickUpdate    => self.OnTickUpdate,
      .OffTickUpdate   => self.OffTickUpdate,

    // Rendering Hooks
      .OnRenderBckgrnd  => self.OnRenderBckgrnd,

      .OnRenderWorld    => self.OnRenderWorld,
      .OffRenderWorld   => self.OffRenderWorld,

      .OnRenderOverlay  => self.OnRenderOverlay,
    //.OffRenderOverlay => self.OffRenderOverlay,
    };

    if( hookFunct  )| f |
    {
      utl.log( .TRACE, 0, @src(), "Calling game hook '{s}'", .{ @tagName( tag ) });
      f( cntx );
      return;
    }
  }
};