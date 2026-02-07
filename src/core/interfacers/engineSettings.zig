const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================


pub const EngineSettings = struct
{
  // Debug Flags

  DebugDraw_Body    : bool = false,
  DebugDraw_Tilemap : bool = false,
  DebugDraw_Tile    : bool = false,
  DebugDraw_FPS     : bool = false,

  // Feature Flag

  AutoApply_Body_Movement  : bool = true,
  AutoApply_Body_Collision : bool = true,

  AutoApply_State_Playing  : bool = true,

  // Window Startup Values

  Startup_Target_TickRate  : u16 = 60,
  Startup_Target_FrameRate : u16 = 120,

  Startup_Window_Width     : u16 = 2048,
  Startup_Window_Height    : u16 = 1024,

  Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - DefaultTitle",

  // Graphical Values

  Graphic_Bckgrd_Colour    : ?def.Colour = def.Colour.black,
  Graphic_Metrics_Colour   : ?def.Colour = def.Colour.yellow,
  Graphic_Default_Font     : ?[ :0 ] const u8 = "src/assets/fonts/F77MinecraftRegular.ttf",

  Camera_Max_Zoom          : f32 = 5.0,
  Camera_Min_Zoom          : f32 = 0.2,


  // ================================ ENGINE SETTINGS FUNCTIONS ================================

  pub fn loadSettings( self : *EngineSettings, module : anytype ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing engine settings..." );

    var hasFoundSettings : bool = false;

    if( @typeInfo( module ) != .@"struct" )
    {
      def.log( .ERROR, 0, @src(), "EngineSettings.loadSettings() expects a struct ( module ) type, got a {} instead", .{ @typeName( module ) });
      return;
    }

    // Debug Flags
    if( @hasDecl( module, "DebugDraw_Body"           )){ self.DebugDraw_Body           = @field( module, "DebugDraw_Body"           ); hasFoundSettings = true; }
    if( @hasDecl( module, "DebugDraw_Tilemap"        )){ self.DebugDraw_Tilemap        = @field( module, "DebugDraw_Tilemap"        ); hasFoundSettings = true; }
    if( @hasDecl( module, "DebugDraw_Tile"           )){ self.DebugDraw_Tile           = @field( module, "DebugDraw_Tile"           ); hasFoundSettings = true; }
    if( @hasDecl( module, "DebugDraw_FPS"            )){ self.DebugDraw_FPS            = @field( module, "DebugDraw_FPS"            ); hasFoundSettings = true; }

    // Feature Flags
    if( @hasDecl( module, "AutoApply_Body_Movement"  )){ self.AutoApply_Body_Movement  = @field( module, "AutoApply_Body_Movement"  ); hasFoundSettings = true; }
    if( @hasDecl( module, "AutoApply_Body_Collision" )){ self.AutoApply_Body_Collision = @field( module, "AutoApply_Body_Collision" ); hasFoundSettings = true; }
    if( @hasDecl( module, "AutoApply_State_Playing"  )){ self.AutoApply_State_Playing  = @field( module, "AutoApply_State_Playing"  ); hasFoundSettings = true; }

    // Global Values
    if( @hasDecl( module, "Startup_Window_TargetFps" )){ self.Startup_Window_TargetFps = @field( module, "Startup_Window_TargetFps" ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Width"     )){ self.Startup_Window_Width     = @field( module, "Startup_Window_Width"     ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Height"    )){ self.Startup_Window_Height    = @field( module, "Startup_Window_Height"    ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Title"     )){ self.Startup_Window_Title     = @field( module, "Startup_Window_Title"     ); hasFoundSettings = true; }

    if( @hasDecl( module, "Graphic_Bckgrd_Colour"    )){ self.Graphic_Bckgrd_Colour    = @field( module, "Graphic_Bckgrd_Colour"    ); hasFoundSettings = true; }
    if( @hasDecl( module, "Graphic_Metrics_Colour"   )){ self.Graphic_Metrics_Colour   = @field( module, "Graphic_Metrics_Colour"   ); hasFoundSettings = true; }
    if( @hasDecl( module, "Graphic_Default_Font"     )){ self.Graphic_Default_Font     = @field( module, "Graphic_Default_Font"     ); hasFoundSettings = true; }

    if( @hasDecl( module, "Camera_Max_Zoom"          )){ self.Camera_Max_Zoom          = @field( module, "Camera_Max_Zoom"          ); hasFoundSettings = true; }
    if( @hasDecl( module, "Camera_Min_Zoom"          )){ self.Camera_Min_Zoom          = @field( module, "Camera_Min_Zoom"          ); hasFoundSettings = true; }



    // Logging the outcome
    if( hasFoundSettings ){ def.qlog( .INFO, 0, @src(), "$ Successfully initialized settings from given module\n" ); }
    else {                  def.qlog( .WARN, 0, @src(), "$ Failed to find any valid settings from given module\n" ); }
  }
};