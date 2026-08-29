const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ GAME ADAPTER HOOKS ================================

// This enum defines the tags for each game hook
// These tags are used to identify which hook to call in the GameHooks struct
pub const HookTag = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  // Engine State Hooks

  OnGameStart  = 0, // Called when the engine starts
  OnGameStop   = 1, // Called when the engine is closed

  OnGameOpen   = 2, // Called when the engine is launched
  OnGameClose  = 3, // Called when the engine stops

  OnGameResume = 4, // Called when the engine starts playing
  OnGamePause  = 5, // Called when the engine is paused

  // Engine Step Hooks

  OnLoopStart  = 10, // Called at the start of the game loop
  OnLoopEnd    = 11, // Called at the end of the game loop
  OnLoopUpdate = 12, // Called for each iteration of the game loop

  OnUpdateInputs  = 20, // Called every frame for updates ( at the start )
//OffUpdateInputs = 21, // Called every frame for updates ( at the end )

  OnTickWorld     = 22, // Called every tick for logic updates ( at the start )
  OffTickWorld    = 23, // Called every tick for logic updates ( at the end )

  OnRenderBckgrnd = 30, // Called to render the background
  OnRenderWorld   = 32, // Called to render the world
  OnRenderOverlay = 34, // Called to render overlays
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
  OnLoopUpdate : ?HookFunc = null,

  OnUpdateInputs  : ?HookFunc = null,
//OffUpdateInputs : ?HookFunc = null,

  OnTickWorld     : ?HookFunc = null,
  OffTickWorld    : ?HookFunc = null,

  OnRenderBckgrnd : ?HookFunc = null,
  OnRenderWorld   : ?HookFunc = null,
  OnRenderOverlay : ?HookFunc = null,



  // ================================ GAME ADAPTER HOOK LOADING ================================

  pub fn loadHooks( self : *GameHooks, module : anytype ) void
  {
    utl.qlog( .TRACE, @src(), "Initializing game hooks..." );

    if( @typeInfo( module ) != .@"struct" )
    {
      utl.log( .ERROR, @src(), "GameHooks.loadHooks() expects a struct ( module ) type, got a {} instead", .{ @typeName( module ) });
      return;
    }

    // Engine State hooks

    if( @hasDecl( module, "OnGameStart"  )) self.OnGameStart  = @field( module, "OnGameStart"  ); // Called in engineState.zig->start()
    if( @hasDecl( module, "OnGameStop"   )) self.OnGameStop   = @field( module, "OnGameStop"   ); // Called in engineState.zig->stop()

    if( @hasDecl( module, "OnGameOpen"   )) self.OnGameOpen   = @field( module, "OnGameOpen"   ); // Called in engineState.zig->open()
    if( @hasDecl( module, "OnGameClose"  )) self.OnGameClose  = @field( module, "OnGameClose"  ); // Called in engineState.zig->close()

    if( @hasDecl( module, "OnGameResume" )) self.OnGameResume = @field( module, "OnGameResume" ); // Called in engineState.zig->resume()
    if( @hasDecl( module, "OnGamePause"  )) self.OnGamePause  = @field( module, "OnGamePause"  ); // Called in engineState.zig->pause()

    // Engine Step Hooks

    if( @hasDecl( module, "OnLoopStart"  )) self.OnLoopStart  = @field( module, "OnLoopStart"  ); // Called in engineStep.zig->runGameLoop()
    if( @hasDecl( module, "OnLoopEnd"    )) self.OnLoopEnd    = @field( module, "OnLoopEnd"    ); // Called in engineStep.zig->runGameLoop()
    if( @hasDecl( module, "OnLoopUpdate" )) self.OnLoopUpdate = @field( module, "OnLoopUpdate" ); // Called in engineStep.zig->stepGameLoop()

    if( @hasDecl( module, "OnUpdateInputs"  )) self.OnUpdateInputs  = @field( module, "OnUpdateInputs"  ); // Called in engineStep.zig->updateInputs()
  //if( @hasDecl( module, "OffUpdateInputs" )) self.OffUpdateInputs = @field( module, "OffUpdateInputs" );

    if( @hasDecl( module, "OnTickWorld"     )) self.OnTickWorld     = @field( module, "OnTickWorld"     ); // Called in engineStep.zig->tickWorld()
    if( @hasDecl( module, "OffTickWorld"    )) self.OffTickWorld    = @field( module, "OffTickWorld"    ); // Called in engineStep.zig->tickWorld()

    if( @hasDecl( module, "OnRenderBckgrnd" )) self.OnRenderBckgrnd = @field( module, "OnRenderBckgrnd" ); // Called in engineStep.zig->renderFrame()
    if( @hasDecl( module, "OnRenderWorld"   )) self.OnRenderWorld   = @field( module, "OnRenderWorld"   ); // Called in engineStep.zig->renderFrame()
    if( @hasDecl( module, "OnRenderOverlay" )) self.OnRenderOverlay = @field( module, "OnRenderOverlay" ); // Called in engineStep.zig->renderFrame()


    self.checkHookValidities();
    utl.qlog( .CONT, @src(), "" );
    utl.qlog( .INFO, @src(), "$ Available game hooks initialized\n" );
  }


  pub fn checkHookValidities( self : *const GameHooks ) void
  {
    utl.qlog( .DEBUG, @src(), "# Checking game hook validity...\n" );

    inline for ( @typeInfo( GameHooks ).@"struct".fields )| field |
    {
      const fieldName = field.name;
      const fieldPtr = @field( self, fieldName );

      if( fieldPtr )| func |
      {
        _ = func;
        utl.log( .CONT, @src(), "$ '{s}'\tGame hook WAS set", .{ fieldName });
      }
      else
      {
        utl.log( .CONT, @src(), "@ '{s}'\tGame hook NOT set", .{ fieldName });
      }
    }
  }

  pub fn tryHook( self : *const GameHooks, tag : HookTag, cntx : HookCntx ) void
  {
    const hookFunct = switch( tag )
    {
    // Engine State Hooks

      .OnGameStart  => self.OnGameStart,
      .OnGameStop   => self.OnGameStop,

      .OnGameOpen   => self.OnGameOpen,
      .OnGameClose  => self.OnGameClose,

      .OnGameResume => self.OnGameResume,
      .OnGamePause  => self.OnGamePause,

    // Engine Step Hooks

      .OnLoopStart  => self.OnLoopStart,
      .OnLoopEnd    => self.OnLoopEnd,
      .OnLoopUpdate => self.OnLoopUpdate,

      .OnUpdateInputs  => self.OnUpdateInputs,
    //.OffUpdateInputs => self.OffUpdateInputs,

      .OnTickWorld     => self.OnTickWorld,
      .OffTickWorld    => self.OffTickWorld,

      .OnRenderBckgrnd => self.OnRenderBckgrnd,
      .OnRenderWorld   => self.OnRenderWorld,
      .OnRenderOverlay => self.OnRenderOverlay,
    };

    if( hookFunct  )| f |
    {
      utl.log( .TRACE, @src(), "Calling game hook '{s}'", .{ @tagName( tag ) });
      f( cntx );
      return;
    }
  }
};
