const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Entity  = true;
//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;


// Engine Feature Flag

  pub const AutoApply_Entity_Movement  = true;
  pub const AutoApply_Entity_Collision = false;


// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Ping";
  pub const Startup_Bckgrd_Colour    : def.Colour = def.Colour.black;


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart;
  pub const OnOpen  = gameState.OnOpen;


const gameStep = @import( "stepInjects.zig" );

  pub const OnUpdateInputs  = gameStep.OnUpdateInputs;

  pub const OnTickWorld     = gameStep.OnTickWorld;
  pub const OffTickWorld    = gameStep.OffTickWorld;

  pub const OnRenderOverlay = gameStep.OnRenderOverlay;