const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// This file will automatically be scanned by the game engine and have its values and references imported, assuming they match predefined names

// ================================ ENGINE CONFIGS ================================
// NOTE : All engine configs have a default value ( see src/engine/gameAdapter/configs.zig )

  // Debug Flags

  pub const DebugDraw_FPS             : bool = true;

  // Feature Flag

  pub const AutoApply_State_Playing   : bool = true;

  // Window Startup Values

//pub const Startup_Target_TickRate   : u16 = 60;
//pub const Startup_Target_FrameRate  : u16 = 120;

//pub const Startup_Window_Width      : u16 = 2048;
//pub const Startup_Window_Height     : u16 = 1024;

  pub const Startup_Window_Title      : [ :0 ] const u8 = "Ziguezon Engine - Template folder";

// Graphical Values

  pub const Graphic_Bckgrd_Colour     : ?utl.Colour = utl.Colour.blue;
  pub const Graphic_Metrics_Colour    : ?utl.Colour = utl.Colour.green;
//pub const Graphic_Default_Font      : ?[ :0 ] const u8 = "assets/fonts/F77MinecraftRegular.ttf";

//pub const Graphic_Ellipse_Facets    : u16 = 64;

//pub const Camera_Zoom_Max           : f32 = 10.0;
//pub const Camera_Zoom_Min           : f32 = 0.1;
//pub const Camera_Zoom_Init          : f32 = 1.0;

//// Engine Behaviour

//pub const Engine_Limit_QueuedTicks  : u8 = 3;
//pub const Engine_Limit_QueuedFrames : u8 = 1;




// ================================ GAME HOOKS ================================
// You can leave any number of these undefined and the game will still compile
// The engine will simply not call the corresponding hook function
// The most common hooks to use are OnGameStart, OnGameOpen, and the Update/Tick/Render hooks


const gameState = @import( "stateInjects.zig" );

  pub const OnGameStart  = gameState.OnGameStart;
  pub const OnGameStop   = gameState.OnGameStop;

  pub const OnGameOpen   = gameState.OnGameOpen;
  pub const OnGameClose  = gameState.OnGameClose;

  pub const OnGameResume = gameState.OnGameResume;
  pub const OnGamePause  = gameState.OnGamePause;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart  = gameStep.OnLoopStart;
  pub const OnLoopEnd    = gameStep.OnLoopEnd;
  pub const OnLoopUpdate = gameStep.OnLoopUpdate;

  pub const OnUpdateInputs = gameStep.OnUpdateInputs;

  pub const OnTickWorld    = gameStep.OnTickWorld;
  pub const OffTickWorld   = gameStep.OffTickWorld;

  pub const OnRenderBckgrnd  = gameStep.OnRenderBckgrnd;
  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;
