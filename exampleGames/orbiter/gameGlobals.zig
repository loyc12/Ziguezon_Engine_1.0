const std = @import( "std" );
const def = @import( "defs" );

pub const gdf = @import( "gameDefs.zig" );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;

pub const zoomSpeed   : f32 =  1.2;
pub const scrollSpeed : f64 = 12.0;

pub const renderScale : f64 = 0.000_001;

pub const bodyCount   : usize = gdf.BodyName.count - 1;


// ================ GAMEDATA STRUCTS ================

pub var GAME_DATA : GameData = .{};

pub const GameData = struct
{
  times  : GameTimes  = .{},
  stores : CompStores = .{},

  followTarget   : bool = false,
  targetHasMoved : bool = false,

  targetId    : def.EntityId = 0,
  starId      : def.EntityId = 1, // SUN
  homeworldId : def.EntityId = 4, // EARTH

  maxEntityId : usize = gdf.BodyName.count - 1,
  entityArray : [ bodyCount ]def.Entity = std.mem.zeroes([ bodyCount ]def.Entity ),
};


pub const GameTimes = struct
{
  speedSetting : SpeedFactor = .DAY,
  secsPerTick  : i128 = SpeedFactor.DAY.getStepLen(),

  bodyTickOffset : i128 = 0,
  econTickOffset : i128 = 0,


  pub inline fn changeSpeed( self : *GameData, delta : i8 )void
  {
    self.speedSetting = self.speedSetting.change( delta );
    self.secsPerTick  = self.speedSetting.getStepLen();
  }
  pub inline fn tickTime( self : *GameData ) void
  {
    if( def.G_NG.isPaused() ){ return; }

    self.bodyTickOffset += self.secsPerTick;
    self.econTickOffset += self.secsPerTick;
  }

  pub inline fn shouldBodyTick( self : *GameData ) bool
  {
    if( def.G_NG.isPaused() ){ return false; }

    return( self.bodyTickOffset >= gdf.GAME_CONSTS.bodyTickLen );
  }
  pub inline fn consumeBodyTick( self : *GameData ) bool
  {
    self.bodyTickOffset -= gdf.GAME_CONSTS.bodyTickLen;
  }

  pub inline fn shouldEconTick( self : *GameData ) bool
  {
    if( def.G_NG.isPaused() ){ return false; }

    return( self.econTickOffset >= gdf.GAME_CONSTS.econTickLen );
  }
  pub inline fn consumeEconTick( self : *GameData ) bool
  {
    self.econTickOffset -= gdf.GAME_CONSTS.econTickLen;
  }
};


pub const SpeedFactor = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  PAUSED,
  SECOND,
  MINUTE,
  HOUR,
  DAY,
  WEEK,
  MONTH,
  YEAR,

  pub inline fn getStepLen( self : SpeedFactor ) i128
  {
    return switch( self )
    {
      .PAUSED => 0,
      .SECOND => 1,
      .MINUTE => def.TimeVal.secPerMin(),
      .HOUR   => def.TimeVal.secPerHour(),
      .DAY    => def.TimeVal.secPerDay(),
      .WEEK   => def.TimeVal.secPerDay() * 7,
      .MONTH  => def.TimeVal.secPerDay() * 30,
      .YEAR   => def.TimeVal.secPerDay() * 365,
    };
  }

  pub inline fn change( self : SpeedFactor, delta : i8 ) SpeedFactor
  {
    const current : i8 = @intFromEnum( self );
    const next    : i8 = current + delta;

    if( next < 0      ){ next = 0;         }
    if( next >= count ){ next = count - 1; }

    return @enumFromInt( next );
  }
};


pub const CompStores = struct
{
  transStore  : gdf.TransStore  = .{},
  shapeStore  : gdf.ShapeStore  = .{},
  spriteStore : gdf.SpriteStore = .{},
  orbitStore  : gdf.OrbitStore  = .{},
  bodyStore   : gdf.BodyStore   = .{},

  /// Returns true if the registry process failed somewhere
  pub inline fn registerAllStores( self : *CompStores, ng : *def.Engine ) bool
  {
    const alloc = def.getAlloc();

    var hasError : bool = false;

    self.transStore.init(  alloc );
    self.shapeStore.init(  alloc );
    self.spriteStore.init( alloc );

    self.orbitStore.init(  alloc );
    self.bodyStore.init(   alloc );

    // Registering componentStores
    if( !ng.componentRegistry.register( "transStore", &self.transStore ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "shapeStore", &self.shapeStore ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "spriteStore", &self.spriteStore ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
      hasError = true;
    }

    if( !ng.componentRegistry.register( "orbitStore", &self.orbitStore ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "bodyStore", &self.bodyStore ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register bodyStore" );
      hasError = true;
    }

    return hasError;
  }

  pub inline fn deinitAllStores( self : *CompStores ) void
  {
    self.transStore.deinit();
    self.shapeStore.deinit();
    self.spriteStore.deinit();
    self.orbitStore.deinit();
    self.bodyStore.deinit();
  }
};



// ================ GAMEDATA MATRICES ================

pub const sshn_d = @import( "econ/starShine.zig"   );

pub const SUNSHINE = &sshn_d.solShine;

pub const stlr_d = @import( "data/stellarData.zig" );
pub const ecnm_d = @import( "data/economyData.zig" );
pub const trde_d = @import( "data/tradeData.zig"   );

pub const STLR_DATA         = &stlr_d.stellarData;
pub const ECON_ORBIT_DATA   = &trde_d.econOrbitalData;
pub const ECON_TRAVEL_TABLE = &trde_d.econTravelTable;

pub const powr_d = @import( "data/powerData.zig"          );
pub const vesl_d = @import( "data/vesselData.zig"         );
pub const rsrc_d = @import( "data/resourceData.zig"       );
pub const nfrs_d = @import( "data/infrastructureData.zig" );
pub const ndst_d = @import( "data/industryData.zig"       );

pub const POWR_DATA = &powr_d.powerData;
pub const VESL_DATA = &vesl_d.vesselData;
pub const RSRC_DATA = &rsrc_d.resourceData;
pub const NFRS_DATA = &nfrs_d.infrastructureData;
pub const NDST_DATA = &ndst_d.industryData;


pub fn loadStaticDataMatrices() void
{
  stlr_d.loadStellarData();

  powr_d.loadPowerSrcData();
  vesl_d.loadVesselData();
  rsrc_d.loadResourceData();
  nfrs_d.loadInfrastructureData();
  ndst_d.loadIndustryData();
}