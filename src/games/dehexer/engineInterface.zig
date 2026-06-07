const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;


// Engine Feature Flag



// Engine Global Startup Values

  pub const Startup_Window_Title  : [ :0 ] const u8 = "Ziguezon Engine - Dehexer";


// Graphical Values

  pub const Graphic_Bckgrd_Colour : ?utl.Colour = utl.Colour.sGray;


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart;
  pub const OnGameOpen  = gameState.OnGameOpen;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart      = gameStep.OnLoopStart;

  pub const OnInputUpdate   = gameStep.OnInputUpdate;
  pub const OffInputUpdate  = gameStep.OffInputUpdate;

  pub const OnTickUpdate      = gameStep.OnTickUpdate;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;
  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;
