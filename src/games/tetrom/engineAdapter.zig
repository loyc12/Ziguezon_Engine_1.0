const utl = @import( "utils" );

// ================================ ENGINE CONFIGS ================================

pub const DebugDraw_FPS             : bool = true;

pub const Startup_Window_Width      : u16 = 1200;
pub const Startup_Window_Height     : u16 = 1200;

pub const Startup_Window_Title      : [ :0 ] const u8 = "Ziguezon Engine - Tetrom";

pub const Graphic_Bckgrd_Colour     : ?utl.Colour = utl.Colour.black;
pub const Graphic_Metrics_Colour    : ?utl.Colour = utl.Colour.green;


// ================================ GAME HOOKS ================================

const gameState = @import( "stateInjects.zig" );

pub const OnGameOpen  = gameState.OnGameOpen;
pub const OnGameClose = gameState.OnGameClose;


const gameStep = @import( "stepInjects.zig" );

pub const OnUpdateInputs  = gameStep.OnUpdateInputs;
pub const OnRenderWorld   = gameStep.OnRenderWorld;
pub const OnRenderOverlay = gameStep.OnRenderOverlay;
