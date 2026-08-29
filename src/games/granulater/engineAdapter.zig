const std = @import( "std" );
const eng = @import( "engine" );

// ================================ ENGINE CONFIGS ================================

// Engine Debug Flags

  pub const DebugDraw_FPS     = true;


// Engine Feature Flag



// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Granulater";


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart;
  pub const OnGameOpen  = gameState.OnGameOpen;
  pub const OnGameClose = gameState.OnGameClose;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnUpdateInputs   = gameStep.OnUpdateInputs;
  pub const OffUpdateInputs  = gameStep.OffUpdateInputs;

  pub const OnTickWorld    = gameStep.OnTickWorld;

  pub const OnRenderWorld   = gameStep.OnRenderWorld;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
