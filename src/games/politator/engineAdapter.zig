const std = @import( "std" );
const eng = @import( "engine" );

// ================================ ENGINE CONFIGS ================================



  pub const DebugDraw_FPS     = true;

  pub const AutoApply_State_Playing    = false;


  pub const Startup_Target_TickRate  : u16 = 30;
  pub const Startup_Target_FrameRate : u16 = 60;

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
