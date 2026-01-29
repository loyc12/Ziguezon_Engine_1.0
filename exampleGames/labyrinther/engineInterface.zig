const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Body  = true;
//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;
  pub const DebugDraw_FPS     = true;


// Engine Feature Flag

  pub const AutoApply_Body_Movement  = true;
  pub const AutoApply_Body_Collision = false;


// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Labyrinther";


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart;
  pub const OnOpen  = gameState.OnOpen;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnUpdateInputs   = gameStep.OnUpdateInputs;
  pub const OffUpdateInputs  = gameStep.OffUpdateInputs;

  pub const OnTickWorld      = gameStep.OnTickWorld;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;
  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;