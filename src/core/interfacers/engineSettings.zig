const std = @import( "std" );
const def = @import( "defs" );

// ================================ ENGINE SETTINGS ================================


pub const EngineSettings = struct
{
  // Debug Flags

  DebugDraw_Entity  : bool = false,
  DebugDraw_Tilemap : bool = false,
  DebugDraw_Tile    : bool = false,

  // Feature Flag

  AutoApply_Entity_Movement  : bool = true,
  AutoApply_Entity_Collision : bool = true,

  // Window Startup Values

  Startup_Target_TickRate  : u16 = 60,
  Startup_Target_FrameRate : u16 = 120,

  Startup_Window_Width     : u16 = 2048,
  Startup_Window_Height    : u16 = 1024,

  Startup_Window_Title     : [ :0 ] const u8 = "Ziguezon Engine - DefaultTitle",

  // Graphical Values

  Graphic_Bckgrd_Colour    : ?def.Colour = def.Colour.black,


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
    if( @hasDecl( module, "DebugDraw_Entity"  )){ self.DebugDraw_Entity  = @field( module, "DebugDraw_Entity"  ); hasFoundSettings = true; }
    if( @hasDecl( module, "DebugDraw_Tilemap" )){ self.DebugDraw_Tilemap = @field( module, "DebugDraw_Tilemap" ); hasFoundSettings = true; }
    if( @hasDecl( module, "DebugDraw_Tile"    )){ self.DebugDraw_Tile    = @field( module, "DebugDraw_Tile"    ); hasFoundSettings = true; }

    // Debug Flags
    if( @hasDecl( module, "AutoApply_Entity_Movement"  )){ self.AutoApply_Entity_Movement  = @field( module, "AutoApply_Entity_Movement"  ); hasFoundSettings = true; }
    if( @hasDecl( module, "AutoApply_Entity_Collision" )){ self.AutoApply_Entity_Collision = @field( module, "AutoApply_Entity_Collision" ); hasFoundSettings = true; }

    // Global Values
    if( @hasDecl( module, "Startup_Window_TargetFps" )){ self.Startup_Window_TargetFps = @field( module, "Startup_Window_TargetFps" ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Width"     )){ self.Startup_Window_Width     = @field( module, "Startup_Window_Width"     ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Height"    )){ self.Startup_Window_Height    = @field( module, "Startup_Window_Height"    ); hasFoundSettings = true; }
    if( @hasDecl( module, "Startup_Window_Title"     )){ self.Startup_Window_Title     = @field( module, "Startup_Window_Title"     ); hasFoundSettings = true; }


    if( @hasDecl( module, "Graphic_Bckgrd_Colour"    )){ self.Graphic_Bckgrd_Colour    = @field( module, "Graphic_Bckgrd_Colour"    ); hasFoundSettings = true; }


    // Logging the outcome
    if( hasFoundSettings ){ def.qlog( .INFO, 0, @src(), "$ Successfully initialized settings from given module\n" ); }
    else {                  def.qlog( .WARN, 0, @src(), "$ Failed to find any valid settings from given module\n" ); }
  }
};