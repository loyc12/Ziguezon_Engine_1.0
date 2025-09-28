
// ================================ ENGINE SETTINGS ================================

// Engine Debug Flags

//pub const DebugDraw_Entity  = true;
//pub const DebugDraw_Tilemap = true;
//pub const DebugDraw_Tile    = true;

// Engine Feature Flag

  pub const AutoApply_Entity_Movement  = true;
  pub const AutoApply_Entity_Collision = false;

// Engine Global Startup Values

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Labyrinther";


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart; // NOTE : Initialize resources in the OnStart Hook
  pub const OnStop  = gameState.OnStop;

  pub const OnOpen  = gameState.OnOpen;  // NOTE : Instanciate entities in the OnOpen Hook
  pub const OnClose = gameState.OnClose;

  pub const OnPlay  = gameState.OnPlay;
  pub const OnPause = gameState.OnPause;

const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart = gameStep.OnLoopStart;
  pub const OnLoopEnd   = gameStep.OnLoopEnd;
  pub const OnLoopCycle = gameStep.OnLoopCycle;

  pub const OnUpdateInputs  = gameStep.OnUpdateInputs;
  pub const OffUpdateInputs = gameStep.OffUpdateInputs;

  pub const OnTickEntities  = gameStep.OnTickEntities;
//pub const OffTickEntities = gameStep.OffTickEntities;         // NOTE : Useless for now ( equivalent to OnTickEntities )

  pub const OnRenderBackground  = gameStep.OnRenderBackground;
//pub const OffRenderBackground = gameStep.OffRenderBackground; // NOTE : Useless for now ( equivalent to OnRenderBackground )

  pub const OnRenderWorld  = gameStep.OnRenderWorld;
  pub const OffRenderWorld = gameStep.OffRenderWorld;

  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;
//pub const OffRenderOverlay = gameStep.OffRenderOverlay;       // NOTE : Useless for now ( equivalent to OnRenderOverlay )