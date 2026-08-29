const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ ENGINE CONFIGS ================================

// Debug Flags
  pub const DebugDraw_FPS     = true;

  pub const Startup_Window_Title  : [ :0 ] const u8 = "Ziguezon Engine - DebugEnv";


// Graphical Values

  pub const Graphic_Bckgrd_Colour : ?utl.Colour = utl.Colour.dGray;


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart;
  pub const OnGameOpen  = gameState.OnGameOpen;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnUpdateInputs  = gameStep.OnUpdateInputs;

  pub const OnTickWorld     = gameStep.OnTickWorld;

  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
