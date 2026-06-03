const std = @import( "std"  );
const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDef.zig"    );
const gUtl = @import( "gameUtils.zig"   );

// ================================ ENGINE SETTINGS ================================
// NOTE : All engine settings have a default value - see engineSettingHandler.zig for more info on those


// Debug Flags

  pub const DebugDraw_Body    = true;
  pub const DebugDraw_Tilemap = true;
  pub const DebugDraw_Tile    = true;
  pub const DebugDraw_FPS     = true;


// Feature Flag

//pub const AutoApply_Body_Movement  : bool = true;
//pub const AutoApply_Body_Collision : bool = true;

  pub const AutoApply_State_Playing  : bool = false;


// Window Startup Values

//pub const Startup_Target_TickRate  : u16 = 60;
//pub const Startup_Target_FrameRate : u16 = 120;

//pub const Startup_Window_Width  : u16 = 2048;
//pub const Startup_Window_Height : u16 = 1024;

  pub const Startup_Window_Title  : [ :0 ] const u8 = "Ziguezon Engine - Orbiter";


// Graphical Values

  pub const Graphic_Bckgrd_Colour  : ?utl.Colour = gdf.G_CONSTS.backColour;
  pub const Graphic_Metrics_Colour : ?utl.Colour = gdf.G_CONSTS.textColour;
//pub const Graphic_Default_Font   : ?[ :0 ] const u8 = "assets/fonts/F77MinecraftRegular.ttf";

  pub const Graphic_Ellipse_Facets : u16 = 255;

  pub const Camera_Zoom_Max  : f32 = 1.0000000;
  pub const Camera_Zoom_Min  : f32 = 0.0000001;
  pub const Camera_Zoom_Init : f32 = 0.0000100;


// ================================ GAME HOOKS ================================
// NOTE : You can leave any number of these undefined and the game will still compile
//      : The engine will simply not call the corresponding hook function
//      : The most common hooks to use are OnGameStart, OnGameOpen, and the Update/Tick/Render hooks


const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart = gameState.OnGameStart; // NOTE : Initialize resources in the OnGameStart Hook
  pub const OnGameStop  = gameState.OnGameStop;

  pub const OnGameOpen  = gameState.OnGameOpen;  // NOTE : Instanciate bodies in the OnGameOpen Hook
  pub const OnGameClose = gameState.OnGameClose;

  pub const OnGameResume  = gameState.OnGameResume;
  pub const OnGamePause = gameState.OnGamePause;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart      = gameStep.OnLoopStart;
  pub const OnLoopEnd        = gameStep.OnLoopEnd;
  pub const OnLoopCycle      = gameStep.OnLoopCycle;


  pub const OnFrameUpdate   = gameStep.OnFrameUpdate;
  pub const OffFrameUpdate  = gameStep.OffFrameUpdate;

  pub const OnTickUpdate      = gameStep.OnTickUpdate;


  pub const OnRenderBckgrnd  = gameStep.OnRenderBckgrnd;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;

  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;
