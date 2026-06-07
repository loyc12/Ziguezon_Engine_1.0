const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;
  pub const DebugDraw_FPS     = true;

// Engine Feature Flag

  pub const AutoApply_State_Playing  = false;

// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Floppy Disk";

// General Graphic Values

  pub const Graphic_Bckgrd_Colour    : ?utl.Colour = utl.Colour.dGray;

// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameOpen  = gameState.OnGameOpen;
  pub const OnGameClose = gameState.OnGameClose;


const gameStep = @import( "stepInjects.zig" );

  pub const OnInputUpdate  = gameStep.OnInputUpdate;

  pub const OnTickUpdate     = gameStep.OnTickUpdate;
  pub const OffTickUpdate    = gameStep.OffTickUpdate;

  pub const OnRenderWorld   = gameStep.OnRenderWorld;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
