const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ GAME ADAPTER CONFIGS ================================


pub const EngineConfigs = struct
{
  // Debug Flags

  DebugDraw_Tilemap : bool = false,
  DebugDraw_Tile    : bool = false,
  DebugDraw_FPS     : bool = false,

  // Feature Flag

  AutoApply_State_Playing   : bool = true,

  // Window Startup Values

  Startup_Target_TickRate   : u16 = 60,
  Startup_Target_FrameRate  : u16 = 120,

  Startup_Window_Width      : u16 = 2048,
  Startup_Window_Height     : u16 = 1024,

  Startup_Window_Title      : [ :0 ] const u8 = "Ziguezon Engine - DefaultTitle",

  // Graphical Values

  Graphic_Bckgrd_Colour     : ?utl.Colour = utl.Colour.black,
  Graphic_Metrics_Colour    : ?utl.Colour = utl.Colour.yellow,
  Graphic_Default_Font      : ?[ :0 ] const u8 = "assets/fonts/F77MinecraftRegular.ttf",

  Graphic_Ellipse_Facets    : u16 = 64,

  Camera_Zoom_Max           : f32 = 10.0,
  Camera_Zoom_Min           : f32 = 0.1,
  Camera_Zoom_Init          : f32 = 1.0,

  // Engine Behaviour

  Engine_Limit_QueuedTicks  : u8 = 3,
  Engine_Limit_QueuedFrames : u8 = 1,




  // ================================ GAME ADAPTER CONFIG LOADING ================================

  pub fn loadConfigs( self : *EngineConfigs, module : anytype ) void
  {
    utl.qlog( .TRACE, @src(), "Initializing engine configs..." );

    var foundConfigs : bool = false;

    if( @typeInfo( module ) != .@"struct" )
    {
      utl.log( .ERROR, @src(), "EngineConfigs.loadConfigs() expects a struct ( module ) type, got a {} instead", .{ @typeName( module ) });
      return;
    }

    // Debug Flags
    if( @hasDecl( module, "DebugDraw_Tilemap"         )){ self.DebugDraw_Tilemap         = @field( module, "DebugDraw_Tilemap"         ); foundConfigs = true; }
    if( @hasDecl( module, "DebugDraw_Tile"            )){ self.DebugDraw_Tile            = @field( module, "DebugDraw_Tile"            ); foundConfigs = true; }
    if( @hasDecl( module, "DebugDraw_FPS"             )){ self.DebugDraw_FPS             = @field( module, "DebugDraw_FPS"             ); foundConfigs = true; }

    // Feature Flags
    if( @hasDecl( module, "AutoApply_State_Playing"   )){ self.AutoApply_State_Playing   = @field( module, "AutoApply_State_Playing"   ); foundConfigs = true; }

    // Window Startup Values
    if( @hasDecl( module, "Startup_Target_TickRate"   )){ self.Startup_Target_TickRate   = @field( module, "Startup_Target_TickRate"   ); foundConfigs = true; }
    if( @hasDecl( module, "Startup_Target_FrameRate"  )){ self.Startup_Target_FrameRate  = @field( module, "Startup_Target_FrameRate"  ); foundConfigs = true; }
    if( @hasDecl( module, "Startup_Window_Width"      )){ self.Startup_Window_Width      = @field( module, "Startup_Window_Width"      ); foundConfigs = true; }
    if( @hasDecl( module, "Startup_Window_Height"     )){ self.Startup_Window_Height     = @field( module, "Startup_Window_Height"     ); foundConfigs = true; }
    if( @hasDecl( module, "Startup_Window_Title"      )){ self.Startup_Window_Title      = @field( module, "Startup_Window_Title"      ); foundConfigs = true; }

    // Graphical Values
    if( @hasDecl( module, "Graphic_Bckgrd_Colour"     )){ self.Graphic_Bckgrd_Colour     = @field( module, "Graphic_Bckgrd_Colour"     ); foundConfigs = true; }
    if( @hasDecl( module, "Graphic_Metrics_Colour"    )){ self.Graphic_Metrics_Colour    = @field( module, "Graphic_Metrics_Colour"    ); foundConfigs = true; }
    if( @hasDecl( module, "Graphic_Default_Font"      )){ self.Graphic_Default_Font      = @field( module, "Graphic_Default_Font"      ); foundConfigs = true; }
    if( @hasDecl( module, "Graphic_Ellipse_Facets"    )){ self.Graphic_Ellipse_Facets    = @field( module, "Graphic_Ellipse_Facets"    ); foundConfigs = true; }

    if( @hasDecl( module, "Camera_Zoom_Max"           )){ self.Camera_Zoom_Max           = @field( module, "Camera_Zoom_Max"           ); foundConfigs = true; }
    if( @hasDecl( module, "Camera_Zoom_Min"           )){ self.Camera_Zoom_Min           = @field( module, "Camera_Zoom_Min"           ); foundConfigs = true; }
    if( @hasDecl( module, "Camera_Zoom_Init"          )){ self.Camera_Zoom_Init          = @field( module, "Camera_Zoom_Init"          ); foundConfigs = true; }

    // Engine Behaviour
    if( @hasDecl( module, "Engine_Limit_QueuedTicks"  )){ self.Engine_Limit_QueuedTicks  = @field( module, "Engine_Limit_QueuedTicks"  ); foundConfigs = true; }
    if( @hasDecl( module, "Engine_Limit_QueuedFrames" )){ self.Engine_Limit_QueuedFrames = @field( module, "Engine_Limit_QueuedFrames" ); foundConfigs = true; }




    // Logging the outcome
    if( foundConfigs ){ utl.qlog( .INFO, @src(), "$ Successfully initialized configs from given module\n" ); }
    else {              utl.qlog( .WARN, @src(), "$ Failed to find any valid configs from given module\n" ); }
  }
};
