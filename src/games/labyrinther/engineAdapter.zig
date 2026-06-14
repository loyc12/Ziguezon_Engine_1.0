const std = @import( "std" );
const eng = @import( "engine" );

// ================================ ENGINE CONFIGS ================================

// Engine Debug Flags
  pub const DebugDraw_FPS     = true;


// Engine Feature Flag



// Window Startup Values

  pub const Startup_Target_TickRate  : u16 = 1;
  pub const Startup_Target_FrameRate : u16 = 120;

//pub const Startup_Window_Width     : u16 = 2048;
//pub const Startup_Window_Height    : u16 = 1024;

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Orbiter";


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart;
  pub const OnGameOpen  = gameState.OnGameOpen;
  pub const OnGameClose = gameState.OnGameClose;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnInputUpdate   = gameStep.OnInputUpdate;
  pub const OffInputUpdate  = gameStep.OffInputUpdate;

  pub const OnTickUpdate    = gameStep.OnTickUpdate;

  pub const OnRenderWorld   = gameStep.OnRenderWorld;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
