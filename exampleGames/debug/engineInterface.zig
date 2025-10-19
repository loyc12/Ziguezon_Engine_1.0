const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================

// Debug Flags

  pub const DebugDraw_Entity  = true;
  pub const DebugDraw_Tilemap = true;
  pub const DebugDraw_Tile    = true;

  pub const Startup_Window_Title  : [ :0 ] const u8 = "Ziguezon Engine - DebugEnv";


// Graphical Values

  pub const Graphic_Bckgrd_Colour : ?def.Colour = def.Colour.dark_gray;


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart;
  pub const OnOpen  = gameState.OnOpen;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart     = gameStep.OnLoopStart;

  pub const OnUpdateInputs  = gameStep.OnUpdateInputs;

  pub const OnTickWorld     = gameStep.OnTickWorld;

  pub const OnRenderOverlay = gameStep.OnRenderOverlay;