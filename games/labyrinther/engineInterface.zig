const std = @import( "std" );
const eng = @import( "engine" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Body    = true;
//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;
  pub const DebugDraw_FPS     = true;


// Engine Feature Flag

  pub const AutoApply_Body_Movement  = true;
  pub const AutoApply_Body_Collision = false;


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


const gameStep  = @import( "stepInjects.zig" );

  pub const OnFrameUpdate   = gameStep.OnFrameUpdate;
  pub const OffFrameUpdate  = gameStep.OffFrameUpdate;

  pub const OnTickUpdate      = gameStep.OnTickUpdate;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;
  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;