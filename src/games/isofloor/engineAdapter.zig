const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ ENGINE CONFIGS ================================

// Engine Debug Flags
  pub const DebugDraw_FPS     = true;


// Engine Feature Flag

  pub const AutoApply_State_Playing    = true;



// Engine Global Startup Values

  pub const Graphic_Bckgrd_Colour    : ?utl.Colour = utl.Colour.dGray;
  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Isofloor";


  pub const Camera_Zoom_Max : f32 = 10;
  pub const Camera_Zoom_Min : f32 = 0.5;


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
