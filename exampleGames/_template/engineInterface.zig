const std = @import( "std" );
const def = @import( "defs" );

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

//pub const AutoApply_State_Playing  : bool = true;


// Window Startup Values

//pub const Startup_Target_TickRate  : u16 = 60;
//pub const Startup_Target_FrameRate : u16 = 120;

//pub const Startup_Window_Width     : u16 = 1080;
//pub const Startup_Window_Height    : u16 = 720;

  pub const Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - Empty Template";


// Graphical Values

  pub const Graphic_Bckgrd_Colour    : ?def.Colour = def.Colour.blue;
  pub const Graphic_Metrics_Colour   : ?def.Colour = def.Colour.green;
//pub const Graphic_Default_Font     : ?[ :0 ] const u8 = "src/assets/fonts/F77MinecraftRegular.ttf";
//pub const Graphic_Ellipse_Facets   : u16 = 64,

//pub const Camera_Max_Zoom          : f32 = 5.0;
//pub const Camera_Min_Zoom          : f32 = 0.2;


// ================================ GAME HOOKS ================================
// NOTE : You can leave any number of these undefined and the game will still compile
//      : The engine will simply not call the corresponding hook function
//      : The most common hooks to use are OnStart, OnOpen, and the Update/Tick/Render hooks


const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart; // NOTE : Initialize resources in the OnStart Hook
  pub const OnStop  = gameState.OnStop;

  pub const OnOpen  = gameState.OnOpen;  // NOTE : Instanciate bodies in the OnOpen Hook
  pub const OnClose = gameState.OnClose;

  pub const OnPlay  = gameState.OnPlay;
  pub const OnPause = gameState.OnPause;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart      = gameStep.OnLoopStart;
  pub const OnLoopEnd        = gameStep.OnLoopEnd;
  pub const OnLoopCycle      = gameStep.OnLoopCycle;


  pub const OnUpdateInputs   = gameStep.OnUpdateInputs;
  pub const OffUpdateInputs  = gameStep.OffUpdateInputs;

  pub const OnTickWorld      = gameStep.OnTickWorld;


  pub const OnRenderBckgrnd  = gameStep.OnRenderBckgrnd;

  pub const OnRenderWorld    = gameStep.OnRenderWorld;
  pub const OffRenderWorld   = gameStep.OffRenderWorld;

  pub const OnRenderOverlay  = gameStep.OnRenderOverlay;