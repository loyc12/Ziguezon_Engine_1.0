const std = @import( "std" );
const eng = @import( "engine" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

  pub const DebugDraw_FPS     = true;


// Engine Feature Flag

  pub const AutoApply_State_Playing    = false;

// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Politator";


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart;
  pub const OnGameOpen  = gameState.OnGameOpen;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnInputUpdate   = gameStep.OnInputUpdate;
  pub const OffInputUpdate  = gameStep.OffInputUpdate;

  pub const OnTickUpdate      = gameStep.OnTickUpdate;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;
  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;
