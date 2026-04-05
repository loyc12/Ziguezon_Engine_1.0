const std = @import( "std" );
const def = @import( "defs" );

pub const gdf = @import( "gameDefs.zig" );

const bodyCount = gdf.G_CONSTS.bodyCount;

// ================ GAMEDATA STRUCTS ================

pub var G_DATA : GameData = .{};

pub const GameData = struct
{
  times  : GameTimes  = .{},
  stores : CompStores = .{},
  target : TargetInfo = .{},

  entityArray : [ bodyCount ]def.Entity = std.mem.zeroes([ bodyCount ]def.Entity ),
};


pub const GameTimes = struct
{
  speedSetting : SpeedFactor = .DAY,
  secsPerStep  : i128 = SpeedFactor.DAY.getStepLen(),

  bodyStepOffset : i128 = 0,
  econStepOffset : i128 = 0,


  pub inline fn changeSpeed( self : *GameTimes, delta : i8 )void
  {
    self.speedSetting = self.speedSetting.change( delta );
    self.secsPerStep  = self.speedSetting.getStepLen();
  }
  pub inline fn stepTime( self : *GameTimes ) void // Run every tick
  {
    if( def.G_NG.isPaused() ){ return; }

    const tickPerSec : i128 = @intCast( def.G_ST.Startup_Target_TickRate );

    self.bodyStepOffset += @divFloor( self.secsPerStep, tickPerSec );
    self.econStepOffset += @divFloor( self.secsPerStep, tickPerSec );
  }

  pub inline fn shouldBodyTick( self : *GameTimes ) bool
  {
    if( def.G_NG.isPaused() ){ return false; }

    return( self.bodyStepOffset >= gdf.G_CONSTS.bodyStepLen );
  }
  pub inline fn consumeBodyTick( self : *GameTimes ) void
  {
    self.bodyStepOffset -= gdf.G_CONSTS.bodyStepLen;
  }

  pub inline fn shouldEconTick( self : *GameTimes ) bool
  {
    if( def.G_NG.isPaused() ){ return false; }

    return( self.econStepOffset >= gdf.G_CONSTS.econStepLen );
  }
  pub inline fn consumeEconTick( self : *GameTimes ) void
  {
    self.econStepOffset -= gdf.G_CONSTS.econStepLen;
  }
};


pub const CompStores = struct
{
  trans  : gdf.TransStore  = .{},
  shape  : gdf.ShapeStore  = .{},
  sprite : gdf.SpriteStore = .{},
  orbit  : gdf.OrbitStore  = .{},
  body   : gdf.BodyStore   = .{},


  /// Returns true if the registry process failed somewhere
  pub inline fn registerAllStores( self : *CompStores, ng : *def.Engine ) bool
  {
    const alloc = def.getAlloc();

    var hasError : bool = false;

    self.trans.init(  alloc );
    self.shape.init(  alloc );
    self.sprite.init( alloc );

    self.orbit.init(  alloc );
    self.body.init(   alloc );


    // Registering componentStores
    if( !ng.componentRegistry.register( "transStore", &self.trans ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "shapeStore", &self.shape ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "spriteStore", &self.sprite ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
      hasError = true;
    }

    if( !ng.componentRegistry.register( "orbitStore", &self.orbit ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "bodyStore", &self.body ))
    {
      def.qlog( .ERROR, 0, @src(), "Failed to register bodyStore" );
      hasError = true;
    }
    return hasError;
  }

  pub inline fn deinitAllStores( self : *CompStores ) void
  {
    self.trans.deinit();
    self.shape.deinit();
    self.sprite.deinit();
    self.orbit.deinit();
    self.body.deinit();
  }
};


pub const TargetInfo = struct
{
  camFollow : bool = false,
  hasMoved  : bool = false,

  targetId : def.EntityId = 0,


  pub fn changeTargetTo( self : *TargetInfo, targetId : def.EntityId ) void
  {
    if( targetId >= 0 and targetId < bodyCount )
    {
      self.targetId = targetId;
      self.hasMoved = true;
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "Target does not exist : defaulting to Id 0 ( none )" );
      self.targetId = 0;
    }
  }

  pub fn changeTargetBy( self : *TargetInfo, delta : i64 ) void
  {
    const current : i64 = @intCast( self.targetId );
    var next = current + delta;

    if( next < 0 ){ next = 0; }
    if( next > bodyCount ){ next = bodyCount; }

    self.targetId = @intCast( next );
    self.hasMoved = true;
  }

  pub fn moveCamOver( self : *TargetInfo ) void
  {
    if( self.targetId == 0 )
    {
      def.qlog( .TRACE, 0, @src(), "targetId is 0 : returning" );
      return;
    }

    // Centers the camera on current valid target
    if( self.camFollow and self.hasMoved )
    {
      self.hasMoved = false;

      const targetTrans = G_DATA.stores.trans.get( self.targetId );

      if( targetTrans )| trans |
      {
        def.G_CAM.pos = trans.pos;
        def.qlog( .TRACE, 0, @src(), "View centered on target" );
      }
      else
      {
        def.qlog( .WARN, 0, @src(), "Target does not exist : cannot center view" );
        self.camFollow = false;
      }
    }
  }
};


// ================ GAMEDATA SUB-STRUCTS ================

pub const SpeedFactor = enum( i8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  PAUSED = 0,
  SECOND,
  MINUTE,
  HOUR,
  DAY,
  WEEK,
  MONTH,
  YEAR,
  DECADE,


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
      .DECADE => def.TimeVal.secPerDay() * 3650,
    };
  }

  pub inline fn change( self : SpeedFactor, delta : i8 ) SpeedFactor
  {
    const current : i8 = @intFromEnum( self );
    var   next    : i8 = current + delta;

    if( next < 0      ){ next = 0;         }
    if( next >= count ){ next = count - 1; }

    return @enumFromInt( next );
  }
};


// ================ GAMEDATA MATRICES ================

    const sshn_d = @import( "econ/starShine.zig"   );

pub const SUNSHINE = &sshn_d.solShine;

    const stlr_d = @import( "data/stellarData.zig" );
    const ecnm_d = @import( "data/economyData.zig" );
    const trde_d = @import( "data/tradeData.zig"   );

pub const STLR_DATA         = &stlr_d.stellarData;
pub const ECON_ORBIT_DATA   = &trde_d.econOrbitalData;
pub const ECON_TRAVEL_TABLE = &trde_d.econTravelTable;

    const powr_d = @import( "data/powerData.zig"          );
    const vesl_d = @import( "data/vesselData.zig"         );
    const rsrc_d = @import( "data/resourceData.zig"       );
    const nfrs_d = @import( "data/infrastructureData.zig" );
    const ndst_d = @import( "data/industryData.zig"       );

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