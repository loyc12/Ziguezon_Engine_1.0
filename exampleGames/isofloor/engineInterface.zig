const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Body  = true;
//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;
  pub const DebugDraw_FPS     = true;


// Engine Feature Flag

  pub const AutoApply_Body_Movement  = false;
  pub const AutoApply_Body_Collision = false;
  pub const AutoApply_State_Playing    = true;



// Engine Global Startup Values

  pub const Graphic_Bckgrd_Colour    : ?def.Colour = def.Colour.dGray;
  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Isofloor";


  pub const Camera_Max_Zoom : f32 = 10;
  pub const Camera_Min_Zoom : f32 = 0.5;


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